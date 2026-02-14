import Fluent

// MARK: - CreateSavedFilter

public struct CreateSavedFilter: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("saved_filters")
            .id()
            .field("user_id", .uuid, .references("users", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("content_type", .string, .required)
            .field("filter_json", .string, .required)
            .field("sort_json", .string, .required)
            .field("is_public", .bool, .required, .custom("DEFAULT false"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("saved_filters").delete()
    }
}
