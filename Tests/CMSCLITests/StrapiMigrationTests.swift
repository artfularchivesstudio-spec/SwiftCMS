import XCTest
import Fluent
import Vapor
import CMSSchema
import CMSObjects
@testable import CMSCLI

final class StrapiMigrationTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)

        // Configure in-memory SQLite for tests
        app.databases.use(.sqlite(.memory), as: .sqlite)

        // Run migrations
        app.migrations.add(CreateContentTypeDefinitions())
        app.migrations.add(CreateContentEntries())
        app.migrations.add(CreateContentVersions())
        app.migrations.add(CreateUsers())
        app.migrations.add(CreateRoles())
        app.migrations.add(SeedDefaultRoles())

        try await app.autoMigrate()
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
        app = nil
    }

    // MARK: - Schema Parser Tests

    func testStrapiSchemaParsing() throws {
        // Given
        let fixturePath = "/Users/gurindersingh/Documents/Developer/Swift-CMS/Tests/CMSCLITests/Fixtures/strapi-schema.json"
        let schemaData = try Data(contentsOf: URL(fileURLWithPath: fixturePath))

        // When
        let parsed = try StrapiSchemaParser.parse(schemaJSON: schemaData)

        // Then
        XCTAssertEqual(parsed.name, "Article")
        XCTAssertEqual(parsed.slug, "article")
        XCTAssertGreaterThan(parsed.fields.count, 0)

        // Check specific fields
        let titleField = parsed.fields.first { $0.name == "title" }
        XCTAssertNotNil(titleField)
        XCTAssertEqual(titleField?.type, "shortText")
        XCTAssertTrue(titleField?.required ?? false)

        let contentField = parsed.fields.first { $0.name == "content" }
        XCTAssertNotNil(contentField)
        XCTAssertEqual(contentField?.type, "richText")

        let authorField = parsed.fields.first { $0.name == "author" }
        XCTAssertNotNil(authorField)
        XCTAssertEqual(authorField?.type, "relationHasOne")

        let tagsField = parsed.fields.first { $0.name == "tags" }
        XCTAssertNotNil(tagsField)
        XCTAssertEqual(tagsField?.type, "relationHasMany")

        let mediaField = parsed.fields.first { $0.name == "featuredImage" }
        XCTAssertNotNil(mediaField)
        XCTAssertEqual(mediaField?.type, "media")
    }

    // MARK: - Data Import Tests

    func testStrapiDataImport() async throws {
        // Given
        let fixturePath = "/Users/gurindersingh/Documents/Developer/Swift-CMS/Tests/CMSCLITests/Fixtures/strapi-data.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: fixturePath))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let entries = json?["data"] as? [[String: Any]] ?? []

        // Create schema
        let schemaData = try Data(contentsOf: URL(fileURLWithPath: "/Users/gurindersingh/Documents/Developer/Swift-CMS/Tests/CMSCLITests/Fixtures/strapi-schema.json"))
        let schema = try StrapiSchemaParser.parse(schemaJSON: schemaData)
        let parsedSchema = StrapiSchemaParser.ParsedType(
            name: schema.name,
            slug: schema.slug,
            fields: schema.fields
        )

        // When
        for entry in entries {
            try await importEntry(entry, contentType: "article", schema: parsedSchema)
        }

        // Then
        let importedCount = try await ContentEntry.query(on: app.db).count()
        XCTAssertEqual(importedCount, 2)

        // Verify first entry
        let firstEntry = try await ContentEntry.query(on: app.db)
            .filter(\.$id == UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001")!)
            .first()

        XCTAssertNotNil(firstEntry)
        XCTAssertEqual(firstEntry?.status, "published")
        XCTAssertEqual(firstEntry?.contentType, "article")

        // Verify data mapping
        guard case .dictionary(let data) = firstEntry?.data else {
            XCTFail("Data should be dictionary")
            return
        }

        XCTAssertEqual(data["title"]?.stringValue, "First Article")
        XCTAssertEqual(data["content"]?.stringValue, "<p>This is the first article content</p>")
        XCTAssertEqual(data["rating"]?.doubleValue, 4.5)
        XCTAssertTrue(data["published"]?.boolValue ?? false)

        // Verify relations mapped correctly
        XCTAssertEqual(data["author"]?.stringValue, "550e8400-e29b-41d4-a716-446655440002")
        XCTAssertNotNil(data["tags"]?.arrayValue?.first?.stringValue)
        XCTAssertEqual(data["tags"]?.arrayValue?.count, 2)
    }

    // MARK: - Import Command Tests

    func testImportStrapiCommandConfiguration() throws {
        // Given
        var command = ImportStrapiCommand()
        command.path = "/tmp/strapi-project"
        command.dryRun = true
        command.verbose = true

        // When & Then
        XCTAssertEqual(command.path, "/tmp/strapi-project")
        XCTAssertTrue(command.dryRun)
        XCTAssertTrue(command.verbose)
    }

    // MARK: - Helper Methods

    private func importEntry(_ entry: [String: Any], contentType: String, schema: StrapiSchemaParser.ParsedType) async throws {
        guard let idString = entry["id"] as? String,
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Entry missing or invalid UUID 'id' field")
        }

        // Map entry data to SwiftCMS format
        var mappedData: [String: AnyCodableValue] = [:]

        for (fieldName, value) in entry {
            // Skip Strapi metadata fields
            if ["id", "createdAt", "updatedAt", "publishedAt", "createdBy", "updatedBy"].contains(fieldName) {
                continue
            }

            // Find field definition
            if let fieldDef = schema.fields.first(where: { $0.name == fieldName }) {
                mappedData[fieldName] = mapValue(value, fieldType: fieldDef.type)
            } else {
                // Store unknown fields as-is
                mappedData[fieldName] = AnyCodableValue.from(value)
            }
        }

        // Map metadata
        let createdAt = entry["createdAt"] as? String
        let updatedAt = entry["updatedAt"] as? String
        let publishedAt = entry["publishedAt"] as? String
        let createdBy = entry["createdBy"] as? [String: Any]
        let updatedBy = entry["updatedBy"] as? [String: Any]

        // Determine status
        let isPublished = publishedAt != nil
        let status = isPublished ? "published" : "draft"

        // Create content entry
        let contentEntry = ContentEntry(
            id: id, // Preserve original Strapi ID
            contentType: contentType,
            data: .dictionary(mappedData),
            status: .fromRawValue(status) ?? .draft
        )

        // Set metadata
        if let createdAtStr = createdAt {
            contentEntry.createdAt = ISO8601DateFormatter().date(from: createdAtStr)
        }
        if let updatedAtStr = updatedAt {
            contentEntry.updatedAt = ISO8601DateFormatter().date(from: updatedAtStr)
        }
        if let publishedAtStr = publishedAt {
            contentEntry.publishedAt = ISO8601DateFormatter().date(from: publishedAtStr)
        }
        if let firstName = createdBy?["firstname"] as? String,
           let lastName = createdBy?["lastname"] as? String {
            contentEntry.createdBy = "\(firstName) \(lastName)"
        }
        if let firstName = updatedBy?["firstname"] as? String,
           let lastName = updatedBy?["lastname"] as? String {
            contentEntry.updatedBy = "\(firstName) \(lastName)"
        }

        try await contentEntry.create(on: app.db)
    }

    private func mapValue(_ value: Any, fieldType: String) -> AnyCodableValue {
        // Handle Strapi relation format
        if fieldType.starts(with: "relation") {
            if let relationData = value as? [String: Any] {
                // One-to-one relation - extract single ID
                if let id = relationData["id"] {
                    return AnyCodableValue.from(id)
                }
            } else if let relationArray = value as? [Any] {
                // One-to-many or many-to-many - extract array of IDs
                let ids = relationArray.compactMap { item -> String? in
                    if let itemDict = item as? [String: Any],
                       let id = itemDict["id"] as? String {
                        return id
                    }
                    return nil
                }
                return AnyCodableValue.from(ids)
            }
        }

        // Handle media fields
        if fieldType == "media" {
            if let mediaData = value as? [String: Any] {
                // Single media file
                if let url = mediaData["url"] as? String {
                    return AnyCodableValue.from(url)
                }
            } else if let mediaArray = value as? [Any] {
                // Multiple media files
                let urls = mediaArray.compactMap { item -> String? in
                    if let itemDict = item as? [String: Any],
                       let url = itemDict["url"] as? String {
                        return url
                    }
                    return nil
                }
                return AnyCodableValue.from(urls)
            }
        }

        // Default mapping
        return AnyCodableValue.from(value)
    }
}

// MARK: - ContentStatus Extension

extension ContentStatus {
    static func fromRawValue(_ rawValue: String) -> ContentStatus? {
        switch rawValue {
        case "published": return .published
        case "draft": return .draft
        case "review": return .review
        case "archived": return .archived
        case "deleted": return .deleted
        default: return nil
        }
    }
}
