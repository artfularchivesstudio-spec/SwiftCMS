import Fluent
import Vapor
import CMSObjects

// MARK: - SavedFilter Model

/// 🗂️ **SavedFilter**
/// Represents a saved filter/sort preset for content listings.
///
/// Allows users to save and reuse complex filter and sort configurations
/// for content type listings. Public filters are available to all users.
///
/// ## 🗄️ Database Schema
/// - Table: `saved_filters`
/// - Primary Key: `id` (UUID)
/// - Foreign Key: `user_id` → `users.id` (cascade delete, optional)
///
/// ## 🔗 Relationships
/// - 🔗 to User (optional parent, owner of the filter)
/// - 🔗➡️ to ContentTypeDefinition via `content_type` slug
///
/// ## 💾 Usage
/// - Store filter/sort JSON strings for reuse
/// - Support both private (user-owned) and public filters
/// - Applied during content entry listing operations
public final class SavedFilter: Model, Content, @unchecked Sendable {
    public static let schema = "saved_filters"

    // MARK: - 🎯 Primary Key
    /// 🆔 Unique identifier for this saved filter
    @ID(key: .id)
    public var id: UUID?

    // MARK: - 🔗 Relationships
    /// 🔗 Optional parent user who owns this filter
    @OptionalParent(key: "user_id")
    public var user: User?

    // MARK: - 🎯 Field Data
    /// ✏️ Human-readable name for this saved filter
    @Field(key: "name")
    public var name: String

    /// 🎯 Slug of the content type this filter applies to
    @Field(key: "content_type")
    public var contentType: String

    /// 🔍 JSON string containing filter configuration
    /// - Format: Matches ContentEntryService.filter parameter
    @Field(key: "filter_json")
    public var filterJSON: String

    /// 📊 JSON string containing sort configuration
    /// - Format: Matches ContentEntryService.sort parameter
    @Field(key: "sort_json")
    public var sortJSON: String

    /// 🌐 Whether this filter is publicly available to all users
    @Field(key: "is_public")
    public var isPublic: Bool

    // MARK: - 📊 Timestamps
    /// ⏰ Timestamp when the filter was created
    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    /// ⏰ Timestamp when the filter was last updated
    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    // MARK: - 🏗️ Initializers
    /// Initialize a new saved filter
    /// - Parameters:
    ///   - id: Optional UUID (auto-generated if nil)
    ///   - userID: Optional owner user ID
    ///   - name: Human-readable filter name
    ///   - contentType: Content type slug
    ///   - filterJSON: Filter configuration JSON string
    ///   - sortJSON: Sort configuration JSON string
    ///   - isPublic: Whether filter is publicly accessible
    public init() {}

    public init(
        id: UUID? = nil,
        userID: UUID? = nil,
        name: String,
        contentType: String,
        filterJSON: String,
        sortJSON: String,
        isPublic: Bool = false
    ) {
        self.id = id
        if let userID = userID {
            self.$user.id = userID
        }
        self.name = name
        self.contentType = contentType
        self.filterJSON = filterJSON
        self.sortJSON = sortJSON
        self.isPublic = isPublic
    }
}

// MARK: - DTOs for SavedFilter

/// 📤 DTO for saved filter responses
public struct SavedFilterDTO: Content {
    public let id: UUID?
    public let userId: UUID?
    public let name: String
    public let contentType: String
    public let filterJSON: String
    public let sortJSON: String
    public let isPublic: Bool

    /// Initialize saved filter DTO
    /// - Parameters:
    ///   - id: Optional filter ID
    ///   - userId: Optional owner user ID
    ///   - name: Filter name
    ///   - contentType: Content type slug
    ///   - filterJSON: Filter JSON
    ///   - sortJSON: Sort JSON
    ///   - isPublic: Public flag
    public init(
        id: UUID? = nil,
        userId: UUID? = nil,
        name: String,
        contentType: String,
        filterJSON: String,
        sortJSON: String,
        isPublic: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.contentType = contentType
        self.filterJSON = filterJSON
        self.sortJSON = sortJSON
        self.isPublic = isPublic
    }
}

/// 📥 DTO for creating a new saved filter
public struct CreateSavedFilterDTO: Content {
    public let name: String
    public let contentType: String
    public let filterJSON: String
    public let sortJSON: String
    public let isPublic: Bool

    /// Initialize create saved filter DTO
    /// - Parameters:
    ///   - name: Filter name
    ///   - contentType: Content type slug
    ///   - filterJSON: Filter JSON
    ///   - sortJSON: Sort JSON
    ///   - isPublic: Public flag
    public init(
        name: String,
        contentType: String,
        filterJSON: String,
        sortJSON: String,
        isPublic: Bool = false
    ) {
        self.name = name
        self.contentType = contentType
        self.filterJSON = filterJSON
        self.sortJSON = sortJSON
        self.isPublic = isPublic
    }
}
