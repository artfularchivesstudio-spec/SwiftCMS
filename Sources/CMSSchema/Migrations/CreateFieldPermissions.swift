import Fluent

// MARK: - CreateFieldPermissions Migration

/// 🔄 **CreateFieldPermissions Migration**
/// Creates the `field_permissions` table for fine-grained field access control
///
/// ## 📋 Schema Changes
/// - Creates table: `field_permissions`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `role_id` (UUID, Required, FK to roles)
///   - `content_type_slug` (String, Required)
///   - `field_name` (String, Required)
///   - `action` (String, Required - "read" or "edit")
///
/// ## 🔗 Foreign Keys
/// - `role_id` → `roles.id` (ON DELETE CASCADE)
///
/// ## 📊 Indexes
/// - Unique: `(role_id, content_type_slug, field_name, action)`
///   Prevents duplicate field permissions
///
/// ## 🔐 Permission Model
/// Granular field-level permissions complement role-level permissions
/// Controls access to specific fields within content entries
public struct CreateFieldPermissions: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration (create table and indexes)
    public func prepare(on database: Database) async throws {
        try await database.schema("field_permissions")
            .id()
            .field("role_id", .uuid, .required, .references("roles", "id", onDelete: .cascade))
            .field("content_type_slug", .string, .required)
            .field("field_name", .string, .required)
            .field("action", .string, .required)
            .unique(on: "role_id", "content_type_slug", "field_name", "action")
            .create()
    }

    /// 🔄 Revert migration (drop table)
    public func revert(on database: Database) async throws {
        try await database.schema("field_permissions").delete()
    }
}
