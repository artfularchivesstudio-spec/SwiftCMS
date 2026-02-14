import Vapor

/// Protocol for all CMS events. Events are strongly typed and Codable.
public protocol CmsEvent: Codable, Sendable {
    /// Unique event name (e.g., "content.created").
    static var eventName: String { get }
}

/// Context passed to event handlers.
public struct CmsContext: Sendable {
    public let logger: Logger
    public let userId: String?
    public let tenantId: String?

    public init(logger: Logger, userId: String? = nil, tenantId: String? = nil) {
        self.logger = logger
        self.userId = userId
        self.tenantId = tenantId
    }
}

// MARK: - Core Event Types

/// Fired when a content entry is created.
public struct ContentCreatedEvent: CmsEvent {
    public static let eventName = "content.created"
    public let entryId: UUID
    public let contentType: String
    public let data: [String: String]
    public let userId: String?

    public init(entryId: UUID, contentType: String, data: [String: String] = [:], userId: String? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.data = data
        self.userId = userId
    }
}

/// Fired when a content entry is updated.
public struct ContentUpdatedEvent: CmsEvent {
    public static let eventName = "content.updated"
    public let entryId: UUID
    public let contentType: String
    public let userId: String?

    public init(entryId: UUID, contentType: String, userId: String? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.userId = userId
    }
}

/// Fired when a content entry is deleted.
public struct ContentDeletedEvent: CmsEvent {
    public static let eventName = "content.deleted"
    public let entryId: UUID
    public let contentType: String
    public let userId: String?

    public init(entryId: UUID, contentType: String, userId: String? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.userId = userId
    }
}

/// Fired when a content entry is published.
public struct ContentPublishedEvent: CmsEvent {
    public static let eventName = "content.published"
    public let entryId: UUID
    public let contentType: String
    public let userId: String?

    public init(entryId: UUID, contentType: String, userId: String? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.userId = userId
    }
}

/// Fired when a content entry changes state.
public struct ContentStateChangedEvent: CmsEvent {
    public static let eventName = "content.stateChanged"
    public let entryId: UUID
    public let contentType: String
    public let fromState: String
    public let toState: String
    public let userId: String?

    public init(entryId: UUID, contentType: String, fromState: String, toState: String, userId: String? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.fromState = fromState
        self.toState = toState
        self.userId = userId
    }
}

/// Fired when a content type schema is created or changed.
public struct SchemaChangedEvent: CmsEvent {
    public static let eventName = "schema.changed"
    public let contentTypeSlug: String
    public let action: String  // "created", "updated", "deleted"

    public init(contentTypeSlug: String, action: String) {
        self.contentTypeSlug = contentTypeSlug
        self.action = action
    }
}

/// Fired when a user logs in.
public struct UserLoginEvent: CmsEvent {
    public static let eventName = "user.login"
    public let userId: String
    public let email: String?
    public let provider: String

    public init(userId: String, email: String? = nil, provider: String) {
        self.userId = userId
        self.email = email
        self.provider = provider
    }
}

/// Fired when media is uploaded.
public struct MediaUploadedEvent: CmsEvent {
    public static let eventName = "media.uploaded"
    public let mediaId: UUID
    public let filename: String
    public let mimeType: String

    public init(mediaId: UUID, filename: String, mimeType: String) {
        self.mediaId = mediaId
        self.filename = filename
        self.mimeType = mimeType
    }
}

/// Fired when media is deleted.
public struct MediaDeletedEvent: CmsEvent {
    public static let eventName = "media.deleted"
    public let mediaId: UUID

    public init(mediaId: UUID) {
        self.mediaId = mediaId
    }
}
