import Fluent
import Vapor
import CMSObjects

// MARK: - FieldPermission Model

/// 🗂️ **FieldPermission**
/// Represents field-level permissions for a role and content type.
///
/// Controls granular access to individual fields within content entries.
/// Each permission grants a specific action ("read" or "edit") on a field
/// for users with the specified role.
///
/// ## 🗄️ Database Schema
/// - Table: `field_permissions`
/// - Primary Key: `id` (UUID)
/// - Unique: `(role_id, content_type_slug, field_name, action)`
/// - Foreign Key: `role_id` → `roles.id` (cascade delete)
///
/// ## 🔗 Relationships
/// - 🔗 to Role (cascading delete)
/// - 🔗➡️ to ContentTypeDefinition via `content_type_slug`
///
/// ## 💾 Permission Model
/// - Each permission grants access to ONE field for ONE role
/// - Actions: "read" (view field) or "edit" (modify field)
/// - Applied during content entry CRUD operations
public final class FieldPermission: Model, Content, @unchecked Sendable {
    public static let schema = "field_permissions"

    // MARK: - 🎯 Primary Key
    /// 🆔 Unique identifier for this field permission
    @ID(key: .id)
    public var id: UUID?

    // MARK: - 🔗 Relationships
    /// 🔗 Parent role that this permission applies to
    /// - Cascade: Deleting the role removes all field permissions
    @Parent(key: "role_id")
    public var role: Role

    // MARK: - 🎯 Field Data
    /// 🎯 Slug of the content type this permission applies to
    @Field(key: "content_type_slug")
    public var contentTypeSlug: String

    /// 🎯 Name of the field this permission controls
    @Field(key: "field_name")
    public var fieldName: String

    /// 🎯 Action this permission grants: "read" or "edit"
    @Field(key: "action")
    public var action: String  // "read" or "edit"

    // MARK: - 🏗️ Initializers
    /// Initialize a new field permission
    /// - Parameters:
    ///   - id: Optional UUID (auto-generated if nil)
    ///   - roleID: UUID of the role this permission belongs to
    ///   - contentTypeSlug: Content type slug this permission applies to
    ///   - fieldName: Field name to control access to
    ///   - action: Permission action ("read" or "edit")
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

/// 📤 DTO for field permission data transfer
public struct FieldPermissionDTO: Content {
    public let contentTypeSlug: String
    public let fieldName: String
    public let action: String

    /// Initialize field permission DTO
    /// - Parameters:
    ///   - contentTypeSlug: Content type slug
    ///   - fieldName: Field name
    ///   - action: Permission action
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
