import Fluent
import Vapor

// MARK: - AddSchemaHashToContentTypeDefinitions Migration

/// 🔄 **AddSchemaHashToContentTypeDefinitions Migration**
/// Adds schema hash tracking to content type definitions
///
/// ## 📋 Schema Changes
/// - Adds column: `schema_hash` (String, Required, Default: '')
/// - Populates hash for existing content types
///
/// ## 🔐 Hash Computation
/// SHA256 hash of the `json_schema` field content
/// Used for SDK versioning and change detection
///
/// ## 🔄 Migration Strategy
/// This is an additive migration (can run on existing databases)
/// Computes and stores hashes for all existing content types
public struct AddSchemaHashToContentTypeDefinitions: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration (add column and populate hashes)
    public func prepare(on database: Database) async throws {
        // Add the schema_hash column
        try await database.schema("content_type_definitions")
            .field("schema_hash", .string, .required, .custom("DEFAULT ''"))
            .update()

        // Compute and update schema hashes for existing content types
        let contentTypes = try await ContentTypeDefinition.query(on: database).all()
        for contentType in contentTypes {
            contentType.updateSchemaHash()
            try await contentType.save(on: database)
        }
    }

    /// 🔄 Revert migration (remove column)
    public func revert(on database: Database) async throws {
        try await database.schema("content_type_definitions")
            .deleteField("schema_hash")
            .update()
    }
}
