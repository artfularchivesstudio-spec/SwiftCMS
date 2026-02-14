import Fluent
import Vapor
import CMSObjects

// MARK: - ApiKey

/// API key for machine-to-machine access.
public final class ApiKey: Model, Content, @unchecked Sendable {
    public static let schema = "api_keys"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @Field(key: "key_hash")
    public var keyHash: String

    @Field(key: "permissions")
    public var permissions: AnyCodableValue

    @OptionalField(key: "last_used_at")
    public var lastUsedAt: Date?

    @OptionalField(key: "expires_at")
    public var expiresAt: Date?

    @OptionalField(key: "tenant_id")
    public var tenantId: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil, name: String, keyHash: String,
        permissions: AnyCodableValue = .array([]),
        expiresAt: Date? = nil, tenantId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.keyHash = keyHash
        self.permissions = permissions
        self.expiresAt = expiresAt
        self.tenantId = tenantId
    }
}

// MARK: - MediaFile

/// Metadata for an uploaded media file.
public final class MediaFile: Model, Content, @unchecked Sendable {
    public static let schema = "media_files"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "filename")
    public var filename: String

    @Field(key: "mime_type")
    public var mimeType: String

    @Field(key: "size_bytes")
    public var sizeBytes: Int

    @Field(key: "storage_path")
    public var storagePath: String

    @Field(key: "provider")
    public var provider: String

    @OptionalField(key: "alt_text")
    public var altText: String?

    @OptionalField(key: "metadata")
    public var metadata: AnyCodableValue?

    @OptionalField(key: "tenant_id")
    public var tenantId: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil, filename: String, mimeType: String,
        sizeBytes: Int, storagePath: String, provider: String = "local",
        altText: String? = nil, metadata: AnyCodableValue? = nil,
        tenantId: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.storagePath = storagePath
        self.provider = provider
        self.altText = altText
        self.metadata = metadata
        self.tenantId = tenantId
    }

    /// Convert to response DTO.
    public func toResponseDTO(baseURL: String = "") -> MediaResponseDTO {
        MediaResponseDTO(
            id: id ?? UUID(),
            filename: filename,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            url: "\(baseURL)/\(storagePath)",
            altText: altText,
            metadata: metadata,
            createdAt: createdAt
        )
    }
}

// MARK: - Webhook

/// Configuration for an outbound webhook.
public final class Webhook: Model, Content, @unchecked Sendable {
    public static let schema = "webhooks"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @Field(key: "url")
    public var url: String

    @Field(key: "events")
    public var events: AnyCodableValue

    @OptionalField(key: "headers")
    public var headers: AnyCodableValue?

    @Field(key: "secret")
    public var secret: String

    @Field(key: "enabled")
    public var enabled: Bool

    @Field(key: "retry_count")
    public var retryCount: Int

    @OptionalField(key: "tenant_id")
    public var tenantId: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil, name: String, url: String,
        events: AnyCodableValue = .array([]), headers: AnyCodableValue? = nil,
        secret: String, enabled: Bool = true, retryCount: Int = 5,
        tenantId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.events = events
        self.headers = headers
        self.secret = secret
        self.enabled = enabled
        self.retryCount = retryCount
        self.tenantId = tenantId
    }
}

// MARK: - WebhookDelivery

/// Record of a webhook delivery attempt.
public final class WebhookDelivery: Model, Content, @unchecked Sendable {
    public static let schema = "webhook_deliveries"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "webhook_id")
    public var webhook: Webhook

    @Field(key: "event")
    public var event: String

    @Field(key: "payload")
    public var payload: AnyCodableValue

    @Field(key: "idempotency_key")
    public var idempotencyKey: String

    @OptionalField(key: "response_status")
    public var responseStatus: Int?

    @Field(key: "attempts")
    public var attempts: Int

    @OptionalField(key: "delivered_at")
    public var deliveredAt: Date?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil, webhookID: UUID, event: String,
        payload: AnyCodableValue, idempotencyKey: String,
        responseStatus: Int? = nil, attempts: Int = 0
    ) {
        self.id = id
        self.$webhook.id = webhookID
        self.event = event
        self.payload = payload
        self.idempotencyKey = idempotencyKey
        self.responseStatus = responseStatus
        self.attempts = attempts
    }
}

// MARK: - DeadLetterEntry

/// Failed jobs that have exhausted retry budgets.
public final class DeadLetterEntry: Model, Content, @unchecked Sendable {
    public static let schema = "dead_letter_entries"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "job_type")
    public var jobType: String

    @Field(key: "payload")
    public var payload: AnyCodableValue

    @Field(key: "failure_reason")
    public var failureReason: String

    @Field(key: "retry_count")
    public var retryCount: Int

    @OptionalField(key: "first_failed_at")
    public var firstFailedAt: Date?

    @OptionalField(key: "last_failed_at")
    public var lastFailedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil, jobType: String, payload: AnyCodableValue,
        failureReason: String, retryCount: Int,
        firstFailedAt: Date? = nil, lastFailedAt: Date? = nil
    ) {
        self.id = id
        self.jobType = jobType
        self.payload = payload
        self.failureReason = failureReason
        self.retryCount = retryCount
        self.firstFailedAt = firstFailedAt
        self.lastFailedAt = lastFailedAt
    }
}

// MARK: - AuditLog

/// Immutable record of content mutations for compliance.
public final class AuditLog: Model, Content, @unchecked Sendable {
    public static let schema = "audit_log"

    @ID(key: .id)
    public var id: UUID?

    @OptionalField(key: "entry_id")
    public var entryId: UUID?

    @OptionalField(key: "content_type")
    public var contentType: String?

    @Field(key: "action")
    public var action: String

    @OptionalField(key: "user_id")
    public var userId: String?

    @OptionalField(key: "before_data")
    public var beforeData: AnyCodableValue?

    @OptionalField(key: "after_data")
    public var afterData: AnyCodableValue?

    @OptionalField(key: "tenant_id")
    public var tenantId: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil, entryId: UUID? = nil, contentType: String? = nil,
        action: String, userId: String? = nil,
        beforeData: AnyCodableValue? = nil, afterData: AnyCodableValue? = nil,
        tenantId: String? = nil
    ) {
        self.id = id
        self.entryId = entryId
        self.contentType = contentType
        self.action = action
        self.userId = userId
        self.beforeData = beforeData
        self.afterData = afterData
        self.tenantId = tenantId
    }
}
