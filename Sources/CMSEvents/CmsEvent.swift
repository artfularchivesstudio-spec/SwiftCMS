import Vapor
import CMSObjects

// MARK: - 🔄 CmsEvent Protocol

/// 🎯 Protocol for all CMS events. Events are strongly typed and Codable.
///
/// The CmsEvent protocol ensures type safety and consistency across all events in SwiftCMS.
/// Each event must provide a unique `eventName` and conform to `Codable` for serialization
/// and `Sendable` for thread safety.
///
/// ✨ **Features:**
/// - Type-safe event handling
/// - Automatic JSON encoding/decoding
/// - Thread-safe with Sendable conformance
/// - Structured event payloads
///
/// 📊 **Usage:**
///```swift
/// // Creating a custom event
/// struct UserRegisteredEvent: CmsEvent {
///     static let eventName = "user.registered"
///     let userId: UUID
///     let email: String
/// }
///
/// // Publishing an event
/// let event = UserRegisteredEvent(userId: UUID(), email: "user@example.com")
/// try await req.eventBus.publish(event: event, context: context)
///```
public protocol CmsEvent: Codable, Sendable {
    /// 🏷️ Unique event name (e.g., "content.created", "user.login").
    ///
    /// This static property is used for:
    /// - Logging and debugging
    /// - Event bus routing/Storage keys
    /// - Redis Streams channel names (e.g., "cms:content.created")
    static var eventName: String { get }
}

// MARK: - 🎯 CmsContext

/// 🔮 Context passed to event handlers containing request-scoped information.
///
/// CmsContext provides a controlled way to pass request-related data to event handlers
/// without exposing the full Request object. This ensures event handlers don't accidentally
/// access request-specific resources like databases or services directly.
///
/// ✨ **Features:**
/// - Logger for structured logging
/// - User ID for audit trails
/// - Tenant ID for multi-tenancy support
/// - Sendable for concurrency safety
///
/// 📊 **Usage:**
///```swift
/// // Creating context in a route handler
/// let context = CmsContext(
///     logger: req.logger,
///     userId: user?.userId,
///     tenantId: user?.tenantId
/// )
///
/// // In event handler
/// func handle(event: ContentCreatedEvent, context: CmsContext) async throws {
///     context.logger.info(
///         "Content created",
///         metadata: [
///             "entryId": "\(event.entryId)",
///             "userId": "\(context.userId ?? "system")"
///         ]
///     )
/// }
///```
public struct CmsContext: Sendable {
    /// 📃 Logger for structured logging during event handling.
    ///
    /// Use this logger to maintain consistent logging patterns and include
    /// event-specific metadata in log entries.
    public let logger: Logger

    /// 👤 Optional user ID for identifying who triggered the event.
    ///
    /// Used for audit trails and user-specific event handling.
    public let userId: String?

    /// 🏢 Optional tenant ID for multi-tenant deployments.
    ///
    /// Enables tenant-specific event routing and filtering.
    public let tenantId: String?

    /// 🏗️ Creates a new CmsContext.
    ///
    /// - Parameters:
    ///   - logger: Logger instance for event logging
    ///   - userId: Optional user ID for audit tracking
    ///   - tenantId: Optional tenant ID for multi-tenancy
    ///
    /// 📊 **Example:**
    /// ```swift
    /// let context = CmsContext(
    ///     logger: req.logger,
    ///     userId: "user-123",
    ///     tenantId: "acme-corp"
    /// )
    ///```
    public init(logger: Logger, userId: String? = nil, tenantId: String? = nil) {
        self.logger = logger
        self.userId = userId
        self.tenantId = tenantId
    }
}

// MARK: - 🎭 Core Event Types

// MARK: - ✅ ContentCreatedEvent

/// 📄 Fired when a new content entry is created.
///
/// This event captures the creation of content entries across all content types,
/// providing rich data for audit trails, webhooks, and downstream processing.
///
/// 📊 **Event Payload:**
/// - `entryId`: UUID of the created entry
/// - `contentType`: Content type slug (e.g., "blog-post", "product")
/// - `data`: Additional metadata as key-value pairs
/// - `userId`: Optional ID of the user who created the entry
/// - `entry`: Full entry response DTO (for detailed processing)
/// - `timestamp`: When the event occurred
///
/// 🎯 **Use Cases:**
/// - 🔗 Triggering webhooks to external systems
/// - 📊 Updating search indexes (Elasticsearch/Meilisearch)
/// - 📧 Sending notifications for content creation
/// - 💾 Creating audit logs
///
/// 📈 **Event Flow:**
///```
/// Content Creation → Database Write → Event Published → Handlers Execute
///     ↓              ↓                    ↓              ↓
///  API Request   Transaction Commit   Redis Stream   Webhooks
///                                                   Search Update
///                                                   Notifications
///```
///
/// 📊 **Example:**
///```swift
/// // Subscribe to content creation
/// let subscriptionId = await eventBus.subscribe(ContentCreatedEvent.self) { event, context in
///     context.logger.info("New \(event.contentType) created by \(event.userId ?? "system")")
///
///     // Trigger webhook
///     try await webhookService.notify(event)
///
///     // Update search index
///     try await searchService.index(event.entry)
/// }
///```
public struct ContentCreatedEvent: CmsEvent {
    /// 🏷️ Event identifier: "content.created"
    public static let eventName = "content.created"

    /// 🆔 Unique identifier of the created content entry.
    public let entryId: UUID

    /// 📑 Content type slug (e.g., "blog-post", "product", "page")
    public let contentType: String

    /// 📋 Additional event metadata as key-value pairs.
    public let data: [String: String]

    /// 👤 ID of the user who created the entry (for audit trails).
    public let userId: String?

    /// 📦 Full entry data for downstream processing.
    public let entry: ContentEntryResponseDTO?

    /// ⏰ Timestamp when the event was created (defaults to now).
    public let timestamp: Date

    /// 🏗️ Creates a new content created event.
    ///
    /// - Parameters:
    ///   - entryId: UUID of the created entry
    ///   - contentType: Content type slug
    ///   - data: Optional metadata dictionary
    ///   - userId: Optional user ID
    ///   - entry: Optional full entry DTO
    ///
    /// 📊 **Example:**
    ///```swift
    /// let event = ContentCreatedEvent(
    ///     entryId: UUID(),
    ///     contentType: "blog-post",
    ///     data: ["source": "api"],
    ///     userId: "user-123",
    ///     entry: responseDTO
    /// )
    ///```
    public init(entryId: UUID, contentType: String, data: [String: String] = [:], userId: String? = nil, entry: ContentEntryResponseDTO? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.data = data
        self.userId = userId
        self.entry = entry
        self.timestamp = Date()
    }
}

// MARK: - 🔄 ContentUpdatedEvent

/// 🔄 Fired when a content entry is updated.
///
/// Captures update operations including the before/after diff for precise change tracking.
/// This event is essential for version control, audit trails, and selective notifications.
///
/// 📊 **Event Payload:**
/// - `entryId`: UUID of the updated entry
/// - `contentType`: Content type slug
/// - `userId`: Optional ID of the user making the update
/// - `entry`: Current state of the entry after update
/// - `diff`: Optional diff object showing exact changes made
/// - `timestamp`: When the update occurred
///
/// 🎯 **Use Cases:**
/// - 📝 Version control and history tracking
/// - 📊 Analytics on content changes
/// - 🎯 Selective webhook notifications (only on relevant changes)
/// - 👥 Real-time collaborative editing updates
///
/// 📈 **Diff Structure:**
/// Each changed field is represented as one of three types:
/// - `.added(newValue)`: Field was added
/// - `.removed(oldValue)`: Field was removed
/// - `.changed(from: old, to: new)`: Field value changed
///
/// 📊 **Example:**
///```swift
/// eventBus.subscribe(ContentUpdatedEvent.self) { event, context in
///     if let diff = event.diff {
///         for (field, change) in diff {
///             switch change {
///             case .added(let value):
///                 logger.info("Field \(field) added: \(value)")
///             case .removed(let value):
///                 logger.info("Field \(field) removed: \(value)")
///             case .changed(let from, let to):
///                 logger.info("Field \(field) changed from \(from) to \(to)")
///             }
///         }
///     }
/// }
///```
public struct ContentUpdatedEvent: CmsEvent {
    /// 🏷️ Event identifier: "content.updated"
    public static let eventName = "content.updated"

    /// 🆔 Unique identifier of the updated content entry.
    public let entryId: UUID

    /// 📑 Content type slug.
    public let contentType: String

    /// 👤 ID of the user who updated the entry.
    public let userId: String?

    /// 📦 Current state of the entry after update.
    public let entry: ContentEntryResponseDTO?

    /// 📝 Optional diff showing exactly what changed.
    public let diff: [String: AnyDiff]?

    /// ⏰ Timestamp when the event occurred.
    public let timestamp: Date

    /// 🏗️ Creates a new content updated event.
    ///
    /// - Parameters:
    ///   - entryId: UUID of the updated entry
    ///   - contentType: Content type slug
    ///   - userId: Optional user ID
    ///   - entry: Optional full entry DTO
    ///   - diff: Optional diff data
    ///
    /// 📊 **Example:**
    ///```swift
    /// let event = ContentUpdatedEvent(
    ///     entryId: entry.id,
    ///     contentType: "blog-post",
    ///     userId: "user-123",
    ///     entry: updatedDTO,
    ///     diff: ["title": .changed(from: "Old Title", to: "New Title")]
    /// )
    ///```
    public init(entryId: UUID, contentType: String, userId: String? = nil, entry: ContentEntryResponseDTO? = nil, diff: [String: AnyDiff]? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.userId = userId
        self.entry = entry
        self.diff = diff
        self.timestamp = Date()
    }
}

// MARK: - 📊 AnyDiff

/// 📊 Represents a diff between two values for change tracking.
///
/// The AnyDiff enum captures three types of changes:
/// - Added: A field that didn't exist before
/// - Removed: A field that existed but was removed
/// - Changed: A field whose value was modified
///
/// ✨ **Features:**
/// - Codable for JSON serialization
/// - Sendable for concurrency safety
/// - Supports nested AnyCodableValue types
///
/// 📊 **Encoding:**
/// The enum is encoded as a keyed container with:
/// - `added`: ━━ for added values
/// - `removed`: ━━ for removed values
/// - `from`/`to`: ━━ for changed values
///
/// 📊 **Example:**
///```swift
/// // Recording changes
/// var diff: [String: AnyDiff] = [:]
///
/// // Field was added
/// diff["newField"] = .added(AnyCodableValue("new value"))
///
/// // Field was removed
/// diff["oldField"] = .removed(AnyCodableValue("old value"))
///
/// // Field was changed
/// diff["title"] = .changed(from: "Old Title", to: "New Title")
///
/// // Decoding
/// if let titleDiff = diff["title"],
///    case .changed(let from, let to) = titleDiff {
///     print("Title changed from \(from) to \(to)")
/// }
///```
public enum AnyDiff: Codable, Sendable {
    /// ➕ Field was added (value didn't exist before)
    case added(AnyCodableValue)

    /// ➖ Field was removed (value existed but was deleted)
    case removed(AnyCodableValue)

    /// 🔄 Field was changed (value was modified)
    case changed(from: AnyCodableValue, to: AnyCodableValue)

    /// 📷 Private coding keys for Codable conformance
    private enum CodingKeys: String, CodingKey {
        case added, removed, from, to
    }

    /// 📖 Decodes an AnyDiff from a keyed container.
    ///
    /// Looks for one of three keys (added, removed, or from/to) to determine
    /// the appropriate case to initialize.
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
                    debugDescription: "Invalid diff format - expected 'added', 'removed', or 'from/to' keys"
                )
            )
        }
    }

    /// 📝 Encodes the AnyDiff to a keyed container.
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

// MARK: - 🗑️ ContentDeletedEvent

/// 🗑️ Fired when a content entry is deleted.
///
/// Captures deletion operations for audit trails and cleanup operations.
/// Note that this event is fired for both soft deletes (status=deleted) and
/// hard deletes (permanent removal).
///
/// 📊 **Event Payload:**
/// - `entryId`: UUID of the deleted entry
/// - `contentType`: Content type slug
/// - `userId`: Optional ID of the user performing deletion
///
/// 🎯 **Use Cases:**
/// - 🧹 Cleanup operations (search indexes, caching)
/// - 📜 Audit trail logging
/// - 🔗 Cascade deletion to related records
/// - 📤 Notification of content removal
///
/// 📊 **Example:**
///```swift
/// eventBus.subscribe(ContentDeletedEvent.self) { event, context in
///     // Remove from search index
///     try await searchService.delete(event.entryId)
///
///     // Clear cache
///     await cacheService.invalidate(event.contentType, event.entryId)
///
///     // Log deletion
///     context.logger.warning(
///         "Content deleted",
///         metadata: [
///             "entryId": "\(event.entryId)",
///             "by": "\(event.userId ?? "system")"
///         ]
///     )
/// }
///```
public struct ContentDeletedEvent: CmsEvent {
    /// 🏷️ Event identifier: "content.deleted"
    public static let eventName = "content.deleted"

    /// 🆔 Unique identifier of the deleted content entry.
    public let entryId: UUID

    /// 📑 Content type slug.
    public let contentType: String

    /// 👤 ID of the user who deleted the entry.
    public let userId: String?

    /// 🏗️ Creates a new content deleted event.
    ///
    /// - Parameters:
    ///   - entryId: UUID of the deleted entry
    ///   - contentType: Content type slug
    ///   - userId: Optional user ID
    ///
    /// 📊 **Example:**
    ///```swift
    /// let event = ContentDeletedEvent(
    ///     entryId: deletedId,
    ///     contentType: "blog-post",
    ///     userId: "user-123"
    /// )
    ///```
    public init(entryId: UUID, contentType: String, userId: String? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.userId = userId
    }
}

// MARK: - ✨ ContentPublishedEvent

/// ✨ Fired when a content entry is published.
///
/// Triggered when content transitions to the 'published' state, making it publicly
/// accessible. This is a key event for search indexing, CDN purging, and notifications.
///
/// 📊 **Event Payload:**
/// - `entryId`: UUID of the published entry
/// - `contentType`: Content type slug
/// - `userId`: Optional ID of the user who published
/// - `entry`: Published entry data
/// - `timestamp`: Publication time
///
/// 🎯 **Use Cases:**
/// - 🌐 CDN cache purging
/// - 🔍 Search index updates
/// - 📧 Publication notifications
/// - 🔔 Feed updates (RSS, sitemap, etc.)
/// - 📱 Push notifications to subscribers
///
/// 📊 **Example:**
///```swift
/// eventBus.subscribe(ContentPublishedEvent.self) { event, context in
///     // Purge CDN cache
///     try await cdnService.purge(event.contentType, event.entryId)
///
///     // Update search index
///     try await searchService.index(event.entry!, priority: .high)
///
///     // Send notifications to subscribers
///     try await notificationService.notifySubscribers(
///         contentType: event.contentType,
///         entryId: event.entryId
///     )
///
///     // Update RSS feed
///     try await feedService.updateRSS()
/// }
///```
public struct ContentPublishedEvent: CmsEvent {
    /// 🏷️ Event identifier: "content.published"
    public static let eventName = "content.published"

    /// 🆔 Unique identifier of the published content entry.
    public let entryId: UUID

    /// 📑 Content type slug.
    public let contentType: String

    /// 👤 ID of the user who published the entry.
    public let userId: String?

    /// 📦 Published entry data (the live version).
    public let entry: ContentEntryResponseDTO?

    /// ⏰ Publication timestamp.
    public let timestamp: Date

    /// 🏗️ Creates a new content published event.
    ///
    /// - Parameters:
    ///   - entryId: UUID of the published entry
    ///   - contentType: Content type slug
    ///   - userId: Optional user ID
    ///   - entry: Optional full entry DTO
    ///
    /// 📊 **Example:**
    ///```swift
    /// let event = ContentPublishedEvent(
    ///     entryId: publishedId,
    ///     contentType: "blog-post",
    ///     userId: "user-123",
    ///     entry: publishedDTO
    /// )
    ///```
    public init(entryId: UUID, contentType: String, userId: String? = nil, entry: ContentEntryResponseDTO? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.userId = userId
        self.entry = entry
        self.timestamp = Date()
    }
}

// MARK: - 🔄 ContentStateChangedEvent

/// 🔄 Fired when a content entry changes state.
///
/// Generic state change event that fires for any status transition (draft→review→published→archived).
/// This complements the specific publish/delete events by tracking all status changes.
///
/// 📊 **Event Payload:**
/// - `entryId`: UUID of the entry
/// - `contentType`: Content type slug
/// - `fromState`: Previous status
/// - `toState`: New status
/// - `userId`: Optional ID of the user who changed state
///
/// 🎯 **Use Cases:**
/// - 📊 Workflow analytics and reporting
/// - 📧 Status transition notifications
/// - 👁️ Audit trail completeness
/// - 🎯 Custom workflow automation
///
/// 📊 **Example:**
///```swift
/// eventBus.subscribe(ContentStateChangedEvent.self) { event, context in
///     // Log state transitions
///     context.logger.info(
///         "\(event.contentType) \(event.entryId) transitioned from \(event.fromState) to \(event.toState)"
///     )
///
///     // Custom workflow rules
///     if event.fromState == "draft" && event.toState == "review" {
///         // Notify reviewers
///         try await notifyReviewers(event.entryId)
///     }
/// }
///```
public struct ContentStateChangedEvent: CmsEvent {
    /// 🏷️ Event identifier: "content.stateChanged"
    public static let eventName = "content.stateChanged"

    /// 🆔 Unique identifier of the entry.
    public let entryId: UUID

    /// 📑 Content type slug.
    public let contentType: String

    /// ⏮️ Previous status (before the change).
    public let fromState: String

    /// ⏭️ New status (after the change).
    public let toState: String

    /// 👤 ID of the user who changed the state.
    public let userId: String?

    /// 🏗️ Creates a new content state change event.
    ///
    /// - Parameters:
    ///   - entryId: UUID of the entry
    ///   - contentType: Content type slug
    ///   - fromState: Previous status
    ///   - toState: New status
    ///   - userId: Optional user ID
    ///
    /// 📊 **Example:**
    ///```swift
    /// let event = ContentStateChangedEvent(
    ///     entryId: entryId,
    ///     contentType: "blog-post",
    ///     fromState: "draft",
    ///     toState: "review",
    ///     userId: "user-123"
    /// )
    ///```
    public init(entryId: UUID, contentType: String, fromState: String, toState: String, userId: String? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.fromState = fromState
        self.toState = toState
        self.userId = userId
    }
}

// MARK: - 🔧 SchemaChangedEvent

/// 🔧 Fired when a content type schema is created or changed.
///
/// Captures schema modifications including field additions, removals, or changes.
/// Critical for cache invalidation, webhook notifications, and SDK regeneration.
///
/// 📊 **Event Payload:**
/// - `contentTypeSlug`: Content type identifier
/// - `action`: Type of change ("created", "updated", "deleted")
///
/// 🎯 **Use Cases:**
/// - 🚀 Regenerating type-safe SDKs
/// - 🗑️ Clearing schema caches
/// - 📢 Notifying downstream systems of breaking changes
/// - 💾 Triggering content migration routines
///
/// 📊 **Example:**
///```swift
/// eventBus.subscribe(SchemaChangedEvent.self) { event, context in
///     // Invalidate schema cache
///     await schemaCache.invalidate(event.contentTypeSlug)
///
///     // Regenerate SDK if needed
///     if event.action == "updated" {
///         try await sdkGenerator.regenerate(for: event.contentTypeSlug)
///     }
///
///     // Purge CDN for content type
///     try await cdnService.purgeContentType(event.contentTypeSlug)
/// }
///```
public struct SchemaChangedEvent: CmsEvent {
    /// 🏷️ Event identifier: "schema.changed"
    public static let eventName = "schema.changed"

    /// 📑 Content type slug that was modified.
    public let contentTypeSlug: String

    /// 🎯 Type of change: "created", "updated", or "deleted".
    public let action: String

    /// 🏗️ Creates a new schema changed event.
    ///
    /// - Parameters:
    ///   - contentTypeSlug: Content type identifier
    ///   - action: Type of change
    ///
    /// 📊 **Example:**
    ///```swift
    /// let event = SchemaChangedEvent(
    ///     contentTypeSlug: "blog-post",
    ///     action: "updated"
    /// )
    ///```
    public init(contentTypeSlug: String, action: String) {
        self.contentTypeSlug = contentTypeSlug
        self.action = action
    }
}

// MARK: - 🔐 UserLoginEvent

/// 🔐 Fired when a user successfully logs in.
///
/// Captures authentication events for audit trails, analytics, and session management.
/// Useful for tracking user activity and detecting suspicious login patterns.
///
/// 📊 **Event Payload:**
/// - `userId`: User identifier
/// - `email`: User's email address (if available)
/// - `provider`: Authentication provider (e.g., "local", "auth0", "google")
///
/// 🎯 **Use Cases:**
/// - 📊 Login analytics and metrics
/// - 🚨 Security monitoring and anomaly detection
/// - 📧 Welcome emails or onboarding flows
/// - 🔔 Push notification registration
/// - 💾 Session tracking
///
/// 📊 **Example:**
///```swift
/// eventBus.subscribe(UserLoginEvent.self) { event, context in
///     // Record login in analytics
///     analyticsService.track("user.login", properties: [
///         "provider": event.provider,
///         "timestamp": event.timestamp
///     ])
///
///     // Update last login timestamp
///     try await userService.updateLastLogin(userId: event.userId)
///
///     // Send welcome notification (first login)
///     if try await userService.isFirstLogin(event.userId) {
///         try await notificationService.sendWelcomeEmail(event.email)
///     }
/// }
///```
public struct UserLoginEvent: CmsEvent {
    /// 🏷️ Event identifier: "user.login"
    public static let eventName = "user.login"

    /// 🆔 Unique user identifier.
    public let userId: String

    /// 📧 User's email address.
    public let email: String?

    /// 🔗 Authentication provider name (e.g., "local", "auth0", "google").
    public let provider: String

    /// 🏗️ Creates a new user login event.
    ///
    /// - Parameters:
    ///   - userId: User identifier
    ///   - email: Optional email address
    ///   - provider: Authentication provider
    ///
    /// 📊 **Example:**
    ///```swift
    /// let event = UserLoginEvent(
    ///     userId: "user-123",
    ///     email: "user@example.com",
    ///     provider: "auth0"
    /// )
    ///```
    public init(userId: String, email: String? = nil, provider: String) {
        self.userId = userId
        self.email = email
        self.provider = provider
    }
}

// MARK: - 📷 MediaUploadedEvent

/// 📷 Fired when media is successfully uploaded.
///
/// Captures file upload events for processing pipelines including thumbnail generation,
/// CDN distribution, and media management workflows.
///
/// 📊 **Event Payload:**
/// - `mediaId`: UUID of the uploaded media
/// - `filename`: Original filename
/// - `mimeType`: File MIME type (e.g., "image/jpeg", "video/mp4")
///
/// 🎯 **Use Cases:**
/// - 🖼️ Thumbnail generation
/// - ☁️ CDN upload and distribution
/// - 📊 Media library indexing
/// - 🏷️ Image analysis and tagging
/// - 🔄 Metadata extraction
///
/// 📈 **Processing Pipeline:**
///```
/// Upload → Validation → Event Fired → Queue Job → Thumbnails → CDN → Complete
///    ↓         ↓            ↓            ↓          ↓         ↓        ↓
///  Request  File Check  Database   Redis Queue  Convert  Upload  Notify
///```
///
/// 📊 **Example:**
///```swift
/// eventBus.subscribe(MediaUploadedEvent.self) { event, context in
///     // Generate thumbnails via background job
///     try await queue.dispatch(
///         ThumbnailJob.self,
///         .init(mediaId: event.mediaId)
///     )
///
///     // Upload to CDN
///     try await cdnService.upload(event.mediaId)
///
///     // Extract metadata
///     if event.mimeType.hasPrefix("image/") {
///         try await imageProcessor.extractMetadata(event.mediaId)
///     }
/// }
///```
public struct MediaUploadedEvent: CmsEvent {
    /// 🏷️ Event identifier: "media.uploaded"
    public static let eventName = "media.uploaded"

    /// 🆔 Unique media file identifier.
    public let mediaId: UUID

    /// 📄 Original filename including extension.
    public let filename: String

    /// 🎵 MIME type of the uploaded file (e.g., "image/jpeg", "video/mp4").
    public let mimeType: String

    /// 🏗️ Creates a new media uploaded event.
    ///
    /// - Parameters:
    ///   - mediaId: Media file identifier
    ///   - filename: Original filename
    ///   - mimeType: File MIME type
    ///
    /// 📊 **Example:**
    ///```swift
    /// let event = MediaUploadedEvent(
    ///     mediaId: UUID(),
    ///     filename: "hero-image.jpg",
    ///     mimeType: "image/jpeg"
    /// )
    ///```
    public init(mediaId: UUID, filename: String, mimeType: String) {
        self.mediaId = mediaId
        self.filename = filename
        self.mimeType = mimeType
    }
}

// MARK: - 🗑️ MediaDeletedEvent

/// 🗑️ Fired when media is deleted.
///
/// Captures media deletion for cleanup operations including file storage,
/// CDN cache, and database records.
///
/// 📊 **Event Payload:**
/// - `mediaId`: UUID of the deleted media
///
/// 🎯 **Use Cases:**
/// - 🗑️ Cleanup local storage
/// - 🗑️ Purge CDN caches
/// - 🗑️ Remove thumbnails
/// - 🗑️ Update database records
/// - 🗑️ Trigger related content updates
///
/// 📊 **Example:**
///```swift
/// eventBus.subscribe(MediaDeletedEvent.self) { event, context in
///     // Remove from storage
///     try await storageService.delete(mediaId: event.mediaId)
///
///     // Purge CDN
///     try await cdnService.purge(event.mediaId)
///
///     // Remove thumbnails
///     try await thumbnailService.deleteAll(event.mediaId)
///
///     // Update referencing content
///     try await contentService.removeMediaReferences(event.mediaId)
/// }
///```
public struct MediaDeletedEvent: CmsEvent {
    /// 🏷️ Event identifier: "media.deleted"
    public static let eventName = "media.deleted"

    /// 🆔 Unique media file identifier.
    public let mediaId: UUID

    /// 🏗️ Creates a new media deleted event.
    ///
    /// - Parameter mediaId: Media file identifier
    ///
    /// 📊 **Example:**
    ///```swift
    /// let event = MediaDeletedEvent(mediaId: UUID())
    ///```
    public init(mediaId: UUID) {
        self.mediaId = mediaId
    }
}

// MARK: - ✏️ UserEditingEvent

/// ✏️ Fired when a user starts editing a content entry.
///
/// Real-time collaboration event that enables live editing indicators,
/// collision detection, and conflict resolution.
///
/// 📊 **Event Payload:**
/// - `entryId`: Content entry being edited
/// - `contentType`: Content type slug
/// - `userId`: Editor's user ID
/// - `userEmail`: Editor's email (for display)
/// - `timestamp`: When editing started
///
/// 🎯 **Use Cases:**
/// - 👥 Live collaboration indicators ("John is editing...")
/// - 🚨 Collision prevention (multiple simultaneous edits)
/// - 📊 Edit session analytics
/// - 🔔 Notification of active editors
///
/// 📈 **Collaboration Flow:**
///```
/// User Opens Editor → Event Published → WebSocket Broadcast → UI Shows Indicator
///    ↓                     ↓                    ↓                     ↓
///  HTTP Request      Redis Stream      Real-time Update    "Jane is editing..."
///```
///
/// 📊 **Example:**
///```swift
/// eventBus.subscribe(UserEditingEvent.self) { event, context in
///     // Track active editing sessions
///     await collaborationService.trackEditingSession(
///         entryId: event.entryId,
///         userId: event.userId,
///         timestamp: event.timestamp
///     )
///
///     // Broadcast to WebSocket clients
///     try await websocketService.broadcast(event)
///
///     // Set expiration (auto-remove after 5 minutes of inactivity)
///     try await cacheService.set(
///         key: "editing:\(event.entryId):\(event.userId)",
///         value: event,
///         expireAfter: .minutes(5)
///     )
/// }
///```
public struct UserEditingEvent: CmsEvent {
    /// 🏷️ Event identifier: "user.editing"
    public static let eventName = "user.editing"

    /// 🆔 Unique identifier of the content entry being edited.
    public let entryId: UUID

    /// 📑 Content type slug.
    public let contentType: String

    /// 👤 Unique identifier of the editing user.
    public let userId: String

    /// 📧 Email address of the editing user (for display).
    public let userEmail: String?

    /// ⏰ Timestamp when editing started.
    public let timestamp: Date

    /// 🏗️ Creates a new user editing event.
    ///
    /// - Parameters:
    ///   - entryId: Content entry identifier
    ///   - contentType: Content type slug
    ///   - userId: Editor's user ID
    ///   - userEmail: Optional editor email
    ///
    /// 📊 **Example:**
    ///```swift
    /// let event = UserEditingEvent(
    ///     entryId: UUID(),
    ///     contentType: "blog-post",
    ///     userId: "user-123",
    ///     userEmail: "editor@example.com"
    /// )
    ///```
    public init(entryId: UUID, contentType: String, userId: String, userEmail: String? = nil) {
        self.entryId = entryId
        self.contentType = contentType
        self.userId = userId
        self.userEmail = userEmail
        self.timestamp = Date()
    }
}

// MARK: - 🚪 UserStoppedEditingEvent

/// 🚪 Fired when a user stops editing a content entry.
///
/// Complements UserEditingEvent by signaling when a user has finished editing.
/// Used to clear collaboration indicators and release editing locks.
///
/// 📊 **Event Payload:**
/// - `entryId`: Content entry that was being edited
/// - `contentType`: Content type slug
/// - `userId`: Editor's user ID
/// - `timestamp`: When editing stopped
///
/// 🎯 **Use Cases:**
/// - 🧹 Cleanup of collaboration UI elements
/// - 🔓 Releasing editing locks
/// - 📊 Edit duration analytics
/// - 📤 Triggering auto-save or validation
///
/// 📊 **Example:**
///```swift
/// eventBus.subscribe(UserStoppedEditingEvent.self) { event, context in
///     // Clear editing indicator
///     await collaborationService.clearEditingSession(
///         entryId: event.entryId,
    ///     userId: event.userId
///     )
///
///     // Broadcast to WebSocket clients
///     try await websocketService.broadcast(event)
///
///     // Calculate edit duration
///     if let startTime = await cacheService.getEditingStartTime(event) {
///         let duration = event.timestamp.timeIntervalSince(startTime)
///         analyticsService.track("edit.duration", value: duration)
///     }
/// }
///```
public struct UserStoppedEditingEvent: CmsEvent {
    /// 🏷️ Event identifier: "user.stoppedEditing"
    public static let eventName = "user.stoppedEditing"

    /// 🆔 Unique identifier of the content entry.
    public let entryId: UUID

    /// 📑 Content type slug.
    public let contentType: String

    /// 👤 Unique identifier of the user who stopped editing.
    public let userId: String

    /// ⏰ Timestamp when editing stopped.
    public let timestamp: Date

    /// 🏗️ Creates a new user stopped editing event.
    ///
    /// - Parameters:
    ///   - entryId: Content entry identifier
    ///   - contentType: Content type slug
    ///   - userId: User's identifier
    ///
    /// 📊 **Example:**
    ///```swift
    /// let event = UserStoppedEditingEvent(
    ///     entryId: UUID(),
    ///     contentType: "blog-post",
    ///     userId: "user-123"
    /// )
    ///```
    public init(entryId: UUID, contentType: String, userId: String) {
        self.entryId = entryId
        self.contentType = contentType
        self.userId = userId
        self.timestamp = Date()
    }
}