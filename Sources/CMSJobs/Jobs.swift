import Vapor
import Fluent
import Queues
import CMSObjects
import CMSSchema
import CMSEvents

// MARK: - Webhook Delivery Job

/// Delivers webhook payloads with retry and DLQ support.
public struct WebhookDeliveryJob: AsyncJob, Sendable {
    public typealias Payload = WebhookDeliveryPayload

    public init() {}

    public func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        let db = context.application.db
        let client = context.application.client

        guard let delivery = try await WebhookDelivery.find(
            UUID(uuidString: payload.deliveryId), on: db
        ) else {
            context.logger.error("Webhook delivery \(payload.deliveryId) not found")
            return
        }

        guard let webhook = try await Webhook.find(
            UUID(uuidString: payload.webhookId), on: db
        ) else {
            context.logger.error("Webhook \(payload.webhookId) not found")
            return
        }

        // Build request
        let uri = URI(string: webhook.url)
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")

        // HMAC-SHA256 signature
        let payloadJSON = try JSONEncoder().encode(delivery.payload)
        let signature = computeHMAC(data: payloadJSON, secret: webhook.secret)
        headers.add(name: "X-SwiftCMS-Signature", value: "sha256=\(signature)")

        // Add custom headers
        if let customHeaders = webhook.headers?.dictionaryValue {
            for (key, value) in customHeaders {
                if let headerValue = value.stringValue {
                    headers.add(name: key, value: headerValue)
                }
            }
        }

        do {
            let response = try await client.post(uri, headers: headers) { req in
                req.body = .init(data: payloadJSON)
            }

            // Success
            delivery.responseStatus = Int(response.status.code)
            delivery.deliveredAt = Date()
            delivery.attempts += 1
            try await delivery.save(on: db)

            context.logger.info("Webhook delivered: \(webhook.url) -> \(response.status.code)")
        } catch {
            delivery.attempts += 1
            try await delivery.save(on: db)

            if delivery.attempts >= webhook.retryCount {
                // Move to Dead Letter Queue
                let dlq = DeadLetterEntry(
                    jobType: "webhook_delivery",
                    payload: delivery.payload,
                    failureReason: error.localizedDescription,
                    retryCount: delivery.attempts,
                    firstFailedAt: delivery.createdAt,
                    lastFailedAt: Date()
                )
                try await dlq.save(on: db)
                context.logger.error("Webhook exhausted retries, moved to DLQ: \(webhook.url)")
            } else {
                // Re-enqueue with exponential backoff
                let delay = 30.0 * pow(2.0, Double(delivery.attempts - 1))
                let nextAttempt = Date().addingTimeInterval(delay)
                try await context.queue.dispatch(
                    WebhookDeliveryJob.self, payload,
                    delayUntil: nextAttempt
                )
                context.logger.warning(
                    "Webhook delivery failed, retry \(delivery.attempts)/\(webhook.retryCount) in \(Int(delay))s"
                )
            }
        }
    }

    private func computeHMAC(data: Data, secret: String) -> String {
        // Simplified HMAC computation
        let key = Data(secret.utf8)
        let combined = key + data
        // In production, use Crypto.HMAC<SHA256>
        return combined.base64EncodedString().prefix(64).lowercased()
    }
}

/// Payload for webhook delivery jobs.
public struct WebhookDeliveryPayload: Codable, Sendable {
    public let deliveryId: String
    public let webhookId: String

    public init(deliveryId: String, webhookId: String) {
        self.deliveryId = deliveryId
        self.webhookId = webhookId
    }
}

// MARK: - Scheduled Publish Job

/// Checks for entries scheduled to publish or unpublish.
public struct ScheduledPublishJob: AsyncScheduledJob, Sendable {

    public init() {}

    public func run(context: QueueContext) async throws {
        let db = context.application.db
        let now = Date()

        // Publish scheduled entries
        let toPublish = try await ContentEntry.query(on: db)
            .group(.or) { group in
                group.filter(\.$status == "draft")
                group.filter(\.$status == "review")
            }
            .filter(\.$publishAt <= now)
            .filter(\.$deletedAt == nil)
            .all()

        for entry in toPublish {
            let oldStatus = entry.status
            entry.status = ContentStatus.published.rawValue
            entry.publishedAt = now
            try await entry.save(on: db)

            let event = ContentPublishedEvent(
                entryId: entry.id ?? UUID(),
                contentType: entry.contentType
            )
            try await context.application.eventBus.publish(
                event: event,
                context: CmsContext(logger: context.logger)
            )

            context.logger.info("Scheduled publish: \(entry.id?.uuidString ?? "") (\(oldStatus) -> published)")
        }

        // Unpublish scheduled entries
        let toUnpublish = try await ContentEntry.query(on: db)
            .filter(\.$status == "published")
            .filter(\.$unpublishAt <= now)
            .filter(\.$deletedAt == nil)
            .all()

        for entry in toUnpublish {
            entry.status = ContentStatus.archived.rawValue
            try await entry.save(on: db)
            context.logger.info("Scheduled unpublish: \(entry.id?.uuidString ?? "")")
        }
    }
}

// MARK: - Webhook Dispatcher

/// Listens to events and dispatches matching webhooks.
public struct WebhookDispatcher: Sendable {

    /// Set up event subscriptions for webhook dispatching.
    public static func configure(app: Application) {
        app.eventBus.subscribe(ContentCreatedEvent.self) { event, context in
            try await dispatch(eventName: "content.created", entryId: event.entryId.uuidString, app: app, context: context)
        }
        app.eventBus.subscribe(ContentUpdatedEvent.self) { event, context in
            try await dispatch(eventName: "content.updated", entryId: event.entryId.uuidString, app: app, context: context)
        }
        app.eventBus.subscribe(ContentDeletedEvent.self) { event, context in
            try await dispatch(eventName: "content.deleted", entryId: event.entryId.uuidString, app: app, context: context)
        }
        app.eventBus.subscribe(ContentPublishedEvent.self) { event, context in
            try await dispatch(eventName: "content.published", entryId: event.entryId.uuidString, app: app, context: context)
        }
    }

    private static func dispatch(
        eventName: String,
        entryId: String,
        app: Application,
        context: CmsContext
    ) async throws {
        let webhooks = try await Webhook.query(on: app.db)
            .filter(\.$enabled == true)
            .all()

        for webhook in webhooks {
            // Check if webhook subscribes to this event
            guard let events = webhook.events.arrayValue,
                  events.contains(where: { $0.stringValue == eventName }) else {
                continue
            }

            // Generate idempotency key
            let idempotencyKey = "\(webhook.id?.uuidString ?? ""):\(eventName):\(entryId)"

            // Check dedup (60s window)
            let existing = try await WebhookDelivery.query(on: app.db)
                .filter(\.$idempotencyKey == idempotencyKey)
                .filter(\.$createdAt > Date().addingTimeInterval(-60))
                .first()

            guard existing == nil else {
                context.logger.debug("Webhook dedup: skipping duplicate for \(idempotencyKey)")
                continue
            }

            // Create delivery record
            let delivery = WebhookDelivery(
                webhookID: webhook.id ?? UUID(),
                event: eventName,
                payload: .dictionary([
                    "event": .string(eventName),
                    "timestamp": .string(ISO8601DateFormatter().string(from: Date())),
                    "data": .dictionary(["entryId": .string(entryId)])
                ]),
                idempotencyKey: idempotencyKey
            )
            try await delivery.save(on: app.db)

            // Enqueue delivery job
            let payload = WebhookDeliveryPayload(
                deliveryId: delivery.id?.uuidString ?? "",
                webhookId: webhook.id?.uuidString ?? ""
            )
            try await app.queues.queue.dispatch(WebhookDeliveryJob.self, payload)
        }
    }
}
