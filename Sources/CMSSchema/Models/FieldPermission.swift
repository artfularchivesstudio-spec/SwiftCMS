import Fluent
import Vapor
import CMSObjects

// MARK: - FieldPermission

/// Represents field-level permissions for a role and content type.
public final class FieldPermission: Model, Content, @unchecked Sendable {
    public static let schema = "field_permissions"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "role_id")
    public var role: Role

    @Field(key: "content_type_slug")
    public var contentTypeSlug: String

    @Field(key: "field_name")
    public var fieldName: String

    @Field(key: "action")
    public var action: String  // "read" or "edit"

    public init() {}

    public init(
        id: UUID? = nil,
        roleID: UUID,
        contentTypeSlug: String,
        fieldName: String,
        action: String
    ) {
        self.id = id
        self.$role.id = roleID
        self.contentTypeSlug = contentTypeSlug
        self.fieldName = fieldName
        self.action = action
    }
}

// MARK: - FieldPermissionDTO

public struct FieldPermissionDTO: Content {
    public let contentTypeSlug: String
    public let fieldName: String
    public let action: String

    public init(
        contentTypeSlug: String,
        fieldName: String,
        action: String
    ) {
        self.contentTypeSlug = contentTypeSlug
        self.fieldName = fieldName
        self.action = action
    }
}
