import Vapor
import Fluent
import Queues
import Crypto
import CMSObjects
import CMSSchema
import CMSEvents

/// Delivers webhook payloads with exponential backoff retry and DLQ support.
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
                // Re-enqueue with exponential backoff: 1s, 2s, 4s, 8s, 16s
                let backoffDelays = [1.0, 2.0, 4.0, 8.0, 16.0]
                let delayIndex = min(delivery.attempts - 1, backoffDelays.count - 1)
                let delay = backoffDelays[delayIndex]
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
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(signature).map { String(format: "%02x", $0) }.joined()
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