import Fluent
import Vapor
import CMSObjects

// MARK: - SavedFilter Model

/// Represents a saved filter/sort preset for content listings.
public final class SavedFilter: Model, Content, @unchecked Sendable {
    public static let schema = "saved_filters"

    @ID(key: .id)
    public var id: UUID?

    @OptionalParent(key: "user_id")
    public var user: User?

    @Field(key: "name")
    public var name: String

    @Field(key: "content_type")
    public var contentType: String

    @Field(key: "filter_json")
    public var filterJSON: String

    @Field(key: "sort_json")
    public var sortJSON: String

    @Field(key: "is_public")
    public var isPublic: Bool

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

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

// MARK: - SavedFilterDTO

public struct SavedFilterDTO: Content {
    public let id: UUID?
    public let userId: UUID?
    public let name: String
    public let contentType: String
    public let filterJSON: String
    public let sortJSON: String
    public let isPublic: Bool

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

// MARK: - CreateSavedFilterDTO

public struct CreateSavedFilterDTO: Content {
    public let name: String
    public let contentType: String
    public let filterJSON: String
    public let sortJSON: String
    public let isPublic: Bool

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
