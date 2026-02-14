import Fluent

// MARK: - CreateFieldPermissions

public struct CreateFieldPermissions: AsyncMigration {
    public init() {}

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

    public func revert(on database: Database) async throws {
        try await database.schema("field_permissions").delete()
    }
}
