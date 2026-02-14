import Vapor
import CMSObjects

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
    public let entry: ContentEntryResponseDTO?
    public let timestamp: Date

    public init(entryId: UUID, contentType: String, data: [String: String] = [:], userId: String? = nil, entry: ContentEntryResponseDTO? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.data = data
        self.userId = userId
        self.entry = entry
        self.timestamp = Date()
    }
}

/// Fired when a content entry is updated.
public struct ContentUpdatedEvent: CmsEvent {
    public static let eventName = "content.updated"
    public let entryId: UUID
    public let contentType: String
    public let userId: String?
    public let entry: ContentEntryResponseDTO?
    public let diff: [String: AnyDiff]?
    public let timestamp: Date

    public init(entryId: UUID, contentType: String, userId: String? = nil, entry: ContentEntryResponseDTO? = nil, diff: [String: AnyDiff]? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.userId = userId
        self.entry = entry
        self.diff = diff
        self.timestamp = Date()
    }
}

/// Represents a diff between two values
public enum AnyDiff: Codable, Sendable {
    case added(AnyCodableValue)
    case removed(AnyCodableValue)
    case changed(from: AnyCodableValue, to: AnyCodableValue)

    private enum CodingKeys: String, CodingKey {
        case added, removed, from, to
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let added = try container.decodeIfPresent(AnyCodableValue.self, forKey: .added) {
            self = .added(added)
        } else if let removed = try container.decodeIfPresent(AnyCodableValue.self, forKey: .removed) {
            self = .removed(removed)
        } else if let from = try container.decodeIfPresent(AnyCodableValue.self, forKey: .from),
                  let to = try container.decodeIfPresent(AnyCodableValue.self, forKey: .to) {
            self = .changed(from: from, to: to)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid diff format"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .added(let value):
            try container.encode(value, forKey: .added)
        case .removed(let value):
            try container.encode(value, forKey: .removed)
        case .changed(let from, let to):
            try container.encode(from, forKey: .from)
            try container.encode(to, forKey: .to)
        }
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
    public let entry: ContentEntryResponseDTO?
    public let timestamp: Date

    public init(entryId: UUID, contentType: String, userId: String? = nil, entry: ContentEntryResponseDTO? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.userId = userId
        self.entry = entry
        self.timestamp = Date()
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

/// Fired when a user starts editing a content entry
public struct UserEditingEvent: CmsEvent {
    public static let eventName = "user.editing"
    public let entryId: UUID
    public let contentType: String
    public let userId: String
    public let userEmail: String?
    public let timestamp: Date

    public init(entryId: UUID, contentType: String, userId: String, userEmail: String? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.userId = userId
        self.userEmail = userEmail
        self.timestamp = Date()
    }
}

/// Fired when a user stops editing a content entry
public struct UserStoppedEditingEvent: CmsEvent {
    public static let eventName = "user.stoppedEditing"
    public let entryId: UUID
    public let contentType: String
    public let userId: String
    public let timestamp: Date

    public init(entryId: UUID, contentType: String, userId: String) {
        self.entryId = entryId
        self.contentType = contentType
        self.userId = userId
        self.timestamp = Date()
    }
}
