import Foundation
import Fluent
import Vapor
import CMSSchema
import CMSObjects

/// Imports Strapi data export files into SwiftCMS content entries.
public struct StrapiDataImporter: Sendable {
    private let db: any Database
    private let logger: Logger
    private let schemas: [StrapiSchemaParser.ParsedType]

    public init(db: any Database, logger: Logger, schemas: [StrapiSchemaParser.ParsedType]) {
        self.db = db
        self.logger = logger
        self.schemas = schemas
    }

    /// Imports Strapi data from the specified path.
    public func importData(from dataPath: String, dryRun: Bool = false) async throws {
        logger.info("Importing Strapi data from: \(dataPath)")

        // Get all JSON files in data directory
        let fm = FileManager.default
        guard fm.fileExists(atPath: dataPath) else {
            throw Abort(.notFound, reason: "Data path not found: \(dataPath)")
        }

        var importCount = 0
        var errorCount = 0

        // Create a dictionary for quick schema lookup
        let schemaDict = Dictionary(uniqueKeysWithValues: schemas.map { ($0.slug, $0) })

        // Process each content type directory
        let contents = try fm.contentsOfDirectory(atPath: dataPath)
        for contentTypeDir in contents {
            let contentTypePath = "\(dataPath)/\(contentTypeDir)"
            guard fm.fileExists(atPath: contentTypePath),
                  let schema = schemaDict[contentTypeDir] else {
                logger.warning("No schema found for content type: \(contentTypeDir), skipping...")
                continue
            }

            logger.info("Processing content type: \(contentTypeDir)")

            // Find export.json files
            let jsonFiles = try fm.contentsOfDirectory(atPath: contentTypePath)
                .filter { $0.hasSuffix(".json") }

            for jsonFile in jsonFiles {
                let filePath = "\(contentTypePath)/\(jsonFile)"
                do {
                    let count = try await importJSONFile(
                        filePath: filePath,
                        contentType: contentTypeDir,
                        schema: schema,
                        dryRun: dryRun
                    )
                    importCount += count
                    logger.info("  Imported \(count) entries from \(jsonFile)")
                } catch {
                    logger.error("  Failed to import \(jsonFile): \(error)")
                    errorCount += 1
                }
            }
        }

        if dryRun {
            logger.info("Dry run complete. Would import \(importCount) entries.")
        } else {
            logger.info("Import complete. Imported \(importCount) entries with \(errorCount) errors.")
        }
    }

    private func importJSONFile(filePath: String, contentType: String, schema: StrapiSchemaParser.ParsedType, dryRun: Bool) async throws -> Int {
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let entries = json?["data"] as? [[String: Any]] else {
            throw Abort(.badRequest, reason: "Invalid Strapi export format in \(filePath)")
        }

        var importCount = 0

        for entry in entries {
            do {
                try await importEntry(entry, contentType: contentType, schema: schema, dryRun: dryRun)
                importCount += 1
            } catch {
                logger.error("Failed to import entry: \(error)")
                throw error
            }
        }

        return importCount
    }

    private func importEntry(_ entry: [String: Any], contentType: String, schema: StrapiSchemaParser.ParsedType, dryRun: Bool) async throws {
        // Extract ID and preserve it
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
            status: ContentStatus(rawValue: status) ?? .draft
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

        if !dryRun {
            try await contentEntry.create(on: db)
        }
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
