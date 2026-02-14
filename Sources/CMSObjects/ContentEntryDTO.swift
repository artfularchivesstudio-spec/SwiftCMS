import Vapor

/// Content entry status following the content lifecycle state machine.
public enum ContentStatus: String, Codable, Sendable {
    case draft
    case review
    case published
    case archived
    case deleted
}

/// DTO for creating a new content entry.
public struct CreateContentEntryDTO: Content, Sendable, Validatable {
    /// The content data as a JSON object.
    public let data: AnyCodableValue
    /// Initial status (defaults to draft).
    public let status: ContentStatus?
    /// Locale identifier (e.g., "en-US").
    public let locale: String?
    /// Scheduled publish date.
    public let publishAt: Date?
    /// Scheduled unpublish date.
    public let unpublishAt: Date?

    public static func validations(_ validations: inout Validations) {
        // data must be present (validated at service layer against JSON schema)
    }

    public init(
        data: AnyCodableValue,
        status: ContentStatus? = nil,
        locale: String? = nil,
        publishAt: Date? = nil,
        unpublishAt: Date? = nil
    ) {
        self.data = data
        self.status = status
        self.locale = locale
        self.publishAt = publishAt
        self.unpublishAt = unpublishAt
    }
}

/// DTO for updating a content entry.
public struct UpdateContentEntryDTO: Content, Sendable {
    public let data: AnyCodableValue?
    public let status: ContentStatus?
    public let locale: String?
    public let publishAt: Date?
    public let unpublishAt: Date?

    public init(
        data: AnyCodableValue? = nil,
        status: ContentStatus? = nil,
        locale: String? = nil,
        publishAt: Date? = nil,
        unpublishAt: Date? = nil
    ) {
        self.data = data
        self.status = status
        self.locale = locale
        self.publishAt = publishAt
        self.unpublishAt = unpublishAt
    }
}

/// DTO for content entry responses.
public struct ContentEntryResponseDTO: Content, Codable, Sendable {
    public let id: UUID
    public let contentType: String
    public let data: AnyCodableValue
    public let status: ContentStatus
    public let locale: String?
    public let publishAt: Date?
    public let unpublishAt: Date?
    public let createdBy: String?
    public let updatedBy: String?
    public let tenantId: String?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let publishedAt: Date?

    public init(
        id: UUID,
        contentType: String,
        data: AnyCodableValue,
        status: ContentStatus,
        locale: String?,
        publishAt: Date?,
        unpublishAt: Date?,
        createdBy: String?,
        updatedBy: String?,
        tenantId: String?,
        createdAt: Date?,
        updatedAt: Date?,
        publishedAt: Date?
    ) {
        self.id = id
        self.contentType = contentType
        self.data = data
        self.status = status
        self.locale = locale
        self.publishAt = publishAt
        self.unpublishAt = unpublishAt
        self.createdBy = createdBy
        self.updatedBy = updatedBy
        self.tenantId = tenantId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.publishedAt = publishedAt
    }
}

/// DTO for content version responses.
public struct ContentVersionResponseDTO: Content, Sendable {
    public let id: UUID
    public let entryId: UUID
    public let version: Int
    public let data: AnyCodableValue
    public let changedBy: String?
    public let createdAt: Date?

    public init(
        id: UUID,
        entryId: UUID,
        version: Int,
        data: AnyCodableValue,
        changedBy: String?,
        createdAt: Date?
    ) {
        self.id = id
        self.entryId = entryId
        self.version = version
        self.data = data
        self.changedBy = changedBy
        self.createdAt = createdAt
    }
}
