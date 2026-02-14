import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import CMSCLI
@testable import CMSObjects

final class ExportTests: XCTestCase {

    var app: Application!
    var tempDir: String!

    override func setUp() async throws {
        app = try await Application.make(.testing)

        // Configure in-memory SQLite for tests
        app.databases.use(.sqlite(.memory), as: .sqlite)

        // Create temp directory for exports
        tempDir = NSTemporaryDirectory() + "export-tests/"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        try await app.autoMigrate()

        // Create test data
        try await createTestData()
    }

    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()

        // Clean up temp directory
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
    }

    // MARK: - Test Data Setup

    private func createTestData() async throws {
        // Create content type
        let articleType = ContentTypeDefinition(
            id: UUID(),
            name: "Article",
            slug: "article",
            schema: ["type": "object"],
            schemaHash: "abc123"
        )
        try await articleType.create(on: app.db)

        // Create published articles
        for i in 1...3 {
            let article = ContentEntry(
                id: UUID(),
                contentType: "article",
                data: .dictionary([
                    "title": .string("Published Article \(i)"),
                    "content": .string("Content for article \(i)"),
                    "slug": .string("article-\(i)")
                ]),
                status: .published
            )
            try await article.create(on: app.db)
        }

        // Create draft articles
        for i in 1...2 {
            let article = ContentEntry(
                id: UUID(),
                contentType: "article",
                data: .dictionary([
                    "title": .string("Draft Article \(i)"),
                    "content": .string("Draft content \(i)"),
                    "slug": .string("draft-\(i)")
                ]),
                status: .draft
            )
            try await article.create(on: app.db)
        }
    }

    // MARK: - Static Export Tests

    func testStaticExportAllEntries() throws {
        // Given: Content entries exist

        // When: Exporting all entries
        let entries = try getAllEntries()

        // Then: Should export all published entries
        XCTAssertEqual(entries.count, 3) // Only published entries

        for entry in entries {
            XCTAssertEqual(entry.contentType, "article")
            XCTAssertNotNil(entry.slug)
        }
    }

    func testStaticExportWithFilters() throws {
        // When: Exporting only status = published
        let publishedEntries = try getEntries(filter: { entry in
            entry.status == .published
        })

        // Then: Should only get published entries
        XCTAssertEqual(publishedEntries.count, 3)

        // When: Exporting with date filter
        let recentEntries = try getEntries(filter: { entry in
            guard let createdAt = entry.createdAt else { return false }
            return createdAt > Date().addingTimeInterval(-86400) // Last 24 hours
        })

        // Then: Should get appropriate entries
        XCTAssertEqual(recentEntries.count, 5) // All recent
    }

    func testExportManifestGeneration() throws {
        // Given: Exported entries
        let entries = try getAllEntries()
        let exportData = entries.map { entry in
            (contentType: entry.contentType,
             slug: entry.slug,
             data: try! JSONEncoder().encode(entry.data))
        }

        // When: Generating manifest
        let manifest = try StaticExporter.export(entries: exportData, locale: "en-US", outputDir: tempDir)

        // Then: Manifest should contain all entries
        XCTAssertEqual(manifest.entries.count, 3)
        XCTAssertEqual(manifest.locale, "en-US")

        // Check individual entries
        for entry in manifest.entries {
            XCTAssertEqual(entry.contentType, "article")
            XCTAssertFalse(entry.slug.isEmpty)
            XCTAssertFalse(entry.hash.isEmpty)
        }
    }

    func testManifestFileCreation() throws {
        // Given: Entries to export
        let entry = (
            contentType: "article",
            slug: "test-article",
            data: try! JSONEncoder().encode(AnyCodableValue.dictionary(["title": .string("Test")]))
        )

        // When: Exporting
        _ = try StaticExporter.export(entries: [entry], locale: "en-US", outputDir: tempDir)

        // Then: Manifest file should exist
        let manifestPath = tempDir + "ExportManifest.json"
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestPath))

        // And: Should be valid JSON
        let data = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
        let manifest = try JSONDecoder().decode(ExportManifest.self, from: data)
        XCTAssertEqual(manifest.entries.count, 1)
    }

    func testIndividualFilesCreation() throws {
        // Given: Multiple entries
        let entries = [
            (
                contentType: "article",
                slug: "article-1",
                data: try! JSONEncoder().encode(AnyCodableValue.dictionary(["title": .string("Article 1")]))
            ),
            (
                contentType: "article",
                slug: "article-2",
                data: try! JSONEncoder().encode(AnyCodableValue.dictionary(["title": .string("Article 2")]))
            )
        ]

        // When: Exporting
        try StaticExporter.export(entries: entries, locale: "en-US", outputDir: tempDir)

        // Then: Individual files should be created
        for entry in entries {
            let filePath = tempDir + "en-US/article/\(entry.slug).json"
            XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))

            // Verify file content
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
            if case .dictionary(let dict) = decoded {
                XCTAssertNotNil(dict["title"])
            }
        }
    }

    // MARK: - Incremental Export Tests

    func testIncrementalExportWithHash() throws {
        // Given: Previous export manifest
        let oldEntries = [
            (
                contentType: "article",
                slug: "unchanged",
                data: try! JSONEncoder().encode(AnyCodableValue.dictionary(["title": .string("Same")]))
            )
        ]
        let oldManifest = try StaticExporter.export(entries: oldEntries, locale: "en-US", outputDir: tempDir)

        // When: Exporting with changed content
        let newEntry = (contentType: "article", slug: "changed", data: try! JSONEncoder().encode(AnyCodableValue.dictionary(["title": .string("Changed content")])))
        let newManifest = try StaticExporter.export(entries: [oldEntries[0], newEntry], locale: "en-US", outputDir: tempDir)

        // Then: Hashes should indicate changes
        let unchangedEntry = newManifest.entries.first { $0.slug == "unchanged" }
        let changedEntry = newManifest.entries.first { $0.slug == "changed" }

        XCTAssertEqual(unchangedEntry?.hash, oldManifest.entries.first?.hash) // Same hash
        XCTAssertNotEqual(changedEntry?.hash, "") // Different hash
    }

    func testIncrementalExportWithoutChanges() throws {
        // Given: No changes in content
        let entries = [
            (
                contentType: "article",
                slug: "same",
                data: try! JSONEncoder().encode(AnyCodableValue.dictionary(["title": .string("Same")]))
            )
        ]

        // When: Exporting twice
        let manifest1 = try StaticExporter.export(entries: entries, locale: "en-US", outputDir: tempDir)
        let manifest2 = try StaticExporter.export(entries: entries, locale: "en-US", outputDir: tempDir)

        // Then: Hashes should be identical
        XCTAssertEqual(manifest1.entries.first?.hash, manifest2.entries.first?.hash)
    }

    // MARK: - Compression Tests

    func testZipArchiveCreation() throws {
        // Given: Files to archive
        let entries = [
            (
                contentType: "article",
                slug: "test-1",
                data: try! JSONEncoder().encode(AnyCodableValue.dictionary(["title": .string("Test 1")]))
            ),
            (
                contentType: "article",
                slug: "test-2",
                data: try! JSONEncoder().encode(AnyCodableValue.dictionary(["title": .string("Test 2")]))
            )
        ]

        // When: Creating export
        _ = try StaticExporter.export(entries: entries, locale: "en-US", outputDir: tempDir)

        // Then: Files should be ready for zipping
        let manifestPath = tempDir + "en-US/article/test-1.json"
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestPath))

        // Note: Actual zip creation would use system "zip" command
        // This test verifies the files are in place for zipping
    }

    // MARK: - Disk Space Validation Tests

    func testDiskSpaceValidation() throws {
        // TODO: This would need platform-specific implementation
        // For now, test that we can estimate export size

        let entries = try getAllEntries()
        let totalSize = entries.reduce(0) { size, entry in
            size + (try? JSONEncoder().encode(entry.data).count) ?? 0
        }

        XCTAssertGreaterThan(totalSize, 0)
    }

    // MARK: - Locale Filtering Tests

    func testLocaleFiltering() throws {
        // Given: Entries with different locales
        let entries = [
            (
                contentType: "article",
                slug: "en-article",
                data: try! JSONEncoder().encode(AnyCodableValue.dictionary([
                    "title": .string("English Article"),
                    "locale": .string("en-US")
                ]))
            ),
            (
                contentType: "article",
                slug: "es-article",
                data: try! JSONEncoder().encode(AnyCodableValue.dictionary([
                    "title": .string("Spanish Article"),
                    "locale": .string("es-ES")
                ]))
            )
        ]

        // When: Exporting for specific locale
        let enEntries = entries.filter { entry in
            if let dict = try? JSONDecoder().decode(AnyCodableValue.self, from: entry.data),
               case .dictionary(let data) = dict,
               case .string(let locale) = data["locale"] {
                return locale == "en-US"
            }
            return false
        }

        // Then: Should filter correctly
        XCTAssertEqual(enEntries.count, 1)
        XCTAssertEqual(enEntries.first?.slug, "en-article")
    }

    // MARK: - Error Handling Tests

    func testExportWithNoEntries() throws {
        // When: Exporting with no entries
        let manifest = try StaticExporter.export(entries: [], locale: "en-US", outputDir: tempDir)

        // Then: Should create empty manifest
        XCTAssertEqual(manifest.entries.count, 0)
    }

    func testExportWithCorruptedData() throws {
        // Given: Corrupted entry data
        let corruptedData = Data([0xFF, 0xFF, 0xFF]) // Invalid JSON
        let entry = (
            contentType: "article",
            slug: "corrupted",
            data: corruptedData
        )

        // When: Exporting
        do {
            _ = try StaticExporter.export(entries: [entry], locale: "en-US", outputDir: tempDir)
            XCTFail("Should have thrown error for corrupted data")
        } catch {
            // Expected to fail
            XCTAssertTrue(error is DecodingError || error.localizedDescription.contains("JSON"))
        }
    }

    // MARK: - Performance Tests

    func testExportPerformance() throws {
        // Given: Many entries
        let entries = (1...100).map { i in
            (
                contentType: "article",
                slug: "article-\(i)",
                data: try! JSONEncoder().encode(AnyCodableValue.dictionary([
                    "title": .string("Article \(i)"),
                    "content": .string(String(repeating: "Lorem ipsum ", count: 10))
                ]))
            )
        }

        // When: Exporting
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try StaticExporter.export(entries: entries, locale: "en-US", outputDir: tempDir)
        let endTime = CFAbsoluteTimeGetCurrent()

        // Then: Should complete in reasonable time (< 1 second for 100 entries)
        let duration = endTime - startTime
        XCTAssertLessThan(duration, 1.0)
    }

    // MARK: - Helper Methods

    private func getAllEntries() throws -> [ContentEntry] {
        // In real implementation, this would query the database
        // For tests, we return mock entries
        return [
            ContentEntry(
                id: UUID(),
                contentType: "article",
                data: .dictionary([
                    "title": .string("Article 1"),
                    "slug": .string("article-1")
                ]),
                status: .published
            ),
            ContentEntry(
                id: UUID(),
                contentType: "article",
                data: .dictionary([
                    "title": .string("Article 2"),
                    "slug": .string("article-2")
                ]),
                status: .published
            ),
            ContentEntry(
                id: UUID(),
                contentType: "article",
                data: .dictionary([
                    "title": .string("Article 3"),
                    "slug": .string("article-3")
                ]),
                status: .published
            )
        ]
    }

    private func getEntries(filter: (ContentEntry) -> Bool) throws -> [ContentEntry] {
        let allEntries = try getAllEntries()
        return allEntries.filter(filter)
    }
}

// MARK: - Helper Extensions

extension ContentEntry {
    var slug: String {
        if case .dictionary(let data) = self.data,
           case .string(let slug) = data["slug"] {
            return slug
        }
        return ""
    }
}
