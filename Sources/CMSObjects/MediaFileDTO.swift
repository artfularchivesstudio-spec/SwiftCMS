import Vapor

// MARK: - Media DTOs

/// DTO for media file responses.
public struct MediaResponseDTO: Content, Sendable {
    public let id: UUID
    public let filename: String
    public let mimeType: String
    public let sizeBytes: Int
    public let url: String
    public let altText: String?
    public let metadata: AnyCodableValue?
    public let createdAt: Date?

    public init(
        id: UUID, filename: String, mimeType: String, sizeBytes: Int,
        url: String, altText: String?, metadata: AnyCodableValue?, createdAt: Date?
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.url = url
        self.altText = altText
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

// MARK: - Webhook DTOs

/// DTO for webhook responses.
public struct WebhookResponseDTO: Content, Sendable {
    public let id: UUID
    public let name: String
    public let url: String
    public let events: [String]
    public let enabled: Bool
    public let retryCount: Int
    public let createdAt: Date?

    public init(
        id: UUID, name: String, url: String, events: [String],
        enabled: Bool, retryCount: Int, createdAt: Date?
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.events = events
        self.enabled = enabled
        self.retryCount = retryCount
        self.createdAt = createdAt
    }
}

/// DTO for creating a webhook.
public struct CreateWebhookDTO: Content, Sendable, Validatable {
    public let name: String
    public let url: String
    public let events: [String]
    public let headers: AnyCodableValue?
    public let secret: String?
    public let enabled: Bool?
    public let retryCount: Int?

    public static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("url", as: String.self, is: .url)
    }

    public init(
        name: String, url: String, events: [String],
        headers: AnyCodableValue? = nil, secret: String? = nil,
        enabled: Bool? = nil, retryCount: Int? = nil
    ) {
        self.name = name
        self.url = url
        self.events = events
        self.headers = headers
        self.secret = secret
        self.enabled = enabled
        self.retryCount = retryCount
    }
}

/// DTO for webhook delivery log entries.
public struct WebhookDeliveryDTO: Content, Sendable {
    public let id: UUID
    public let webhookId: UUID
    public let event: String
    public let responseStatus: Int?
    public let attempts: Int
    public let deliveredAt: Date?
    public let createdAt: Date?

    public init(
        id: UUID, webhookId: UUID, event: String,
        responseStatus: Int?, attempts: Int,
        deliveredAt: Date?, createdAt: Date?
    ) {
        self.id = id
        self.webhookId = webhookId
        self.event = event
        self.responseStatus = responseStatus
        self.attempts = attempts
        self.deliveredAt = deliveredAt
        self.createdAt = createdAt
    }
}

// MARK: - Auth DTOs

/// DTO for login requests.
public struct LoginDTO: Content, Sendable, Validatable {
    public let email: String
    public let password: String

    public static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: !.empty)
    }

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

/// DTO for token responses.
public struct TokenResponseDTO: Content, Sendable {
    public let token: String
    public let expiresIn: Int
    public let tokenType: String

    public init(token: String, expiresIn: Int = 86400, tokenType: String = "Bearer") {
        self.token = token
        self.expiresIn = expiresIn
        self.tokenType = tokenType
    }
}
