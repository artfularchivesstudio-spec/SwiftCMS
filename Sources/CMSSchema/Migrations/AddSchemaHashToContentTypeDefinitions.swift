import Fluent
import Vapor

// MARK: - AddSchemaHashToContentTypeDefinitions

public struct AddSchemaHashToContentTypeDefinitions: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
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

    public func revert(on database: Database) async throws {
        try await database.schema("content_type_definitions")
            .deleteField("schema_hash")
            .update()
    }
}
