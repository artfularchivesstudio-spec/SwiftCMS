import Vapor
import Fluent
import Queues
import CMSMedia
import CMSObjects
import CMSSchema
import CMSEvents

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
                contentType: entry.contentType,
                entry: nil
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
