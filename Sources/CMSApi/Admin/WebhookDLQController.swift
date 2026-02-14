import Vapor
import Fluent
import Leaf
import CMSCore
import CMSSchema
import CMSObjects
import CMSJobs
import CMSEvents
import CMSAuth

/// Handles webhook DLQ operations in the admin panel.
public struct WebhookDLQController: RouteCollection, Sendable {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let admin = routes.grouped("admin")
        let protected = admin.grouped(SessionAuthRedirectMiddleware())

        // DLQ management
        protected.get("webhooks", "dlq", use: dlqIndex)
        protected.post("webhooks", "dlq", use: filterDLQ)
        protected.post("webhooks", "dlq", ":entryId", "retry", use: retryDLQEntry)
        protected.post("webhooks", "dlq", "retry-all", use: retryAllDLQEntries)
        protected.delete("webhooks", "dlq", ":entryId", use: deleteDLQEntry)

        // API endpoints for AJAX operations
        let api = routes.grouped("api", "v1")
        let apiProtected = api.grouped(SessionAuthRedirectMiddleware())
        apiProtected.post("webhooks", "dlq", ":entryId", "retry", use: retryDLQEntry)
        apiProtected.delete("webhooks", "dlq", ":entryId", use: deleteDLQEntry)
    }

    // MARK: - DLQ Index

    /// GET /admin/webhooks/dlq
    @Sendable
    func dlqIndex(req: Request) async throws -> View {
        let entries = try await DeadLetterEntry.query(on: req.db)
            .filter(\.$jobType == "webhook_delivery")
            .sort(\.$lastFailedAt, .descending)
            .limit(100)
            .all()

        struct Context: Encodable {
            let title: String
            let entries: [DeadLetterEntry]
            let activePage: String
        }

        return try await req.view.render("admin/webhooks/dlq", Context(
            title: "Webhook Dead Letter Queue",
            entries: entries,
            activePage: "webhooks"
        ))
    }

    // MARK: - Filter DLQ

    /// POST /admin/webhooks/dlq (with filter parameters)
    @Sendable
    func filterDLQ(req: Request) async throws -> View {
        struct FilterDTO: Content {
            let search: String?
            let eventType: String?
            let retryCountMin: Int?
            let retryCountMax: Int?
        }

        let filter = try req.content.decode(FilterDTO.self)
        var query = DeadLetterEntry.query(on: req.db)
            .filter(\.$jobType == "webhook_delivery")

        // Apply filters
        if let search = filter.search, !search.isEmpty {
            query = query.group(.or) { group in
                group.filter(\.$failureReason ~~ search)
            }
        }

        if let minCount = filter.retryCountMin {
            query = query.filter(\.$retryCount >= minCount)
        }

        if let maxCount = filter.retryCountMax {
            query = query.filter(\.$retryCount <= maxCount)
        }

        let entries = try await query
            .sort(\.$lastFailedAt, .descending)
            .limit(100)
            .all()

        struct Context: Encodable {
            let title: String
            let entries: [DeadLetterEntry]
            let activePage: String
            let filter: FilterDTO
        }

        return try await req.view.render("admin/webhooks/dlq", Context(
            title: "Webhook Dead Letter Queue",
            entries: entries,
            activePage: "webhooks",
            filter: filter
        ))
    }

    // MARK: - Retry Operations

    /// POST /admin/webhooks/dlq/:entryId/retry
    @Sendable
    func retryDLQEntry(req: Request) async throws -> Response {
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid entry ID")
        }

        guard let dlqEntry = try await DeadLetterEntry.find(entryId, on: req.db) else {
            throw Abort(.notFound, reason: "DLQ entry not found")
        }

        guard dlqEntry.jobType == "webhook_delivery" else {
            throw Abort(.badRequest, reason: "Entry is not a webhook delivery")
        }

        // Extract webhook ID from payload
        guard let payload = dlqEntry.payload.dictionaryValue,
              let webhookIdString = payload["webhookId"]?.stringValue,
              let webhookId = UUID(uuidString: webhookIdString) else {
            throw Abort(.badRequest, reason: "Unable to extract webhook from payload")
        }

        // Verify webhook still exists and is enabled
        guard let webhook = try await Webhook.find(webhookId, on: req.db), webhook.enabled else {
            throw Abort(.badRequest, reason: "Webhook not found or disabled")
        }

        // Create a new delivery record
        let delivery = WebhookDelivery(
            webhookID: webhookId,
            event: payload["event"]?.stringValue ?? "unknown",
            payload: dlqEntry.payload,
            idempotencyKey: "retry_\(UUID().uuidString)"
        )
        try await delivery.save(on: req.db)

        // Dispatch retry job
        let jobPayload = WebhookDeliveryPayload(
            deliveryId: delivery.id?.uuidString ?? "",
            webhookId: webhookId.uuidString
        )
        try await req.queue.dispatch(WebhookDeliveryJob.self, jobPayload)

        // Delete from DLQ
        try await dlqEntry.delete(on: req.db)

        req.logger.info("Retried webhook delivery from DLQ: \(entryId)")

        // Return appropriate response based on request type
        if req.headers[.contentType]?.contains("application/json") == true {
            return Response(status: .ok, body: .init(string: #"{"success": true}"#))
        } else {
            return req.redirect(to: "/admin/webhooks/dlq")
        }
    }

    /// POST /admin/webhooks/dlq/retry-all
    @Sendable
    func retryAllDLQEntries(req: Request) async throws -> Response {
        let entries = try await DeadLetterEntry.query(on: req.db)
            .filter(\.$jobType == "webhook_delivery")
            .all()

        var successCount = 0
        var failureCount = 0

        for entry in entries {
            do {
                // Extract webhook ID from payload
                guard let payload = entry.payload.dictionaryValue,
                      let webhookIdString = payload["webhookId"]?.stringValue,
                      let webhookId = UUID(uuidString: webhookIdString),
                      let webhook = try await Webhook.find(webhookId, on: req.db),
                      webhook.enabled else {
                    failureCount += 1
                    continue
                }

                // Create new delivery and dispatch
                let delivery = WebhookDelivery(
                    webhookID: webhookId,
                    event: payload["event"]?.stringValue ?? "unknown",
                    payload: entry.payload,
                    idempotencyKey: "retry_all_\(UUID().uuidString)"
                )
                try await delivery.save(on: req.db)

                let jobPayload = WebhookDeliveryPayload(
                    deliveryId: delivery.id?.uuidString ?? "",
                    webhookId: webhookId.uuidString
                )
                try await req.queue.dispatch(WebhookDeliveryJob.self, jobPayload)

                // Delete from DLQ
                try await entry.delete(on: req.db)
                successCount += 1

            } catch {
                req.logger.error("Failed to retry DLQ entry \(entry.id ?? UUID()): \(error)")
                failureCount += 1
            }
        }

        req.logger.info("Retried \(successCount) webhook deliveries from DLQ, \(failureCount) failed")

        return req.redirect(to: "/admin/webhooks/dlq")
    }

    // MARK: - Delete Operations

    /// DELETE /admin/webhooks/dlq/:entryId
    @Sendable
    func deleteDLQEntry(req: Request) async throws -> Response {
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid entry ID")
        }

        guard let dlqEntry = try await DeadLetterEntry.find(entryId, on: req.db) else {
            throw Abort(.notFound, reason: "DLQ entry not found")
        }

        guard dlqEntry.jobType == "webhook_delivery" else {
            throw Abort(.badRequest, reason: "Entry is not a webhook delivery")
        }

        try await dlqEntry.delete(on: req.db)

        req.logger.info("Deleted DLQ entry: \(entryId)")

        if req.headers[.contentType]?.contains("application/json") == true {
            return Response(status: .noContent)
        } else {
            return req.redirect(to: "/admin/webhooks/dlq")
        }
    }
}
