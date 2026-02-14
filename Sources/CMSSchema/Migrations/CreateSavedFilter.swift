import Fluent

// MARK: - CreateSavedFilter Migration

/// 🔄 **CreateSavedFilter Migration**
/// Creates the `saved_filters` table for storing filter/sort presets
///
/// ## 📋 Schema Changes
/// - Creates table: `saved_filters`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `user_id` (UUID, Optional, FK to users)
///   - `name` (String, Required)
///   - `content_type` (String, Required)
///   - `filter_json` (String, Required - JSON string)
///   - `sort_json` (String, Required - JSON string)
///   - `is_public` (Bool, Required, Default: false)
///   - `created_at` (DateTime)
///   - `updated_at` (DateTime)
///
/// ## 🔗 Foreign Keys
/// - `user_id` → `users.id` (ON DELETE CASCADE, optional)
///
/// ## 💾 Preset Management
/// Store reusable filter/sort configurations for content listings
/// Public presets available to all users, private presets owned by creators
public struct CreateSavedFilter: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration (create table)
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

    /// 🔄 Revert migration (drop table)
    public func revert(on database: Database) async throws {
        try await database.schema("saved_filters").delete()
    }
}
