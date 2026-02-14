import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import App
@testable import CMSSchema
@testable import CMSObjects

final class VersioningTests: XCTestCase {

    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)

        // Use SQLite for testing
        app.databases.use(.sqlite(.memory), as: .sqlite)

        try await app.autoMigrate()
    }

    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
        app = nil
    }

    // MARK: - Version Creation Tests

    func testVersionCreationOnSave() async throws {
        // Given: A new content entry
        let entry = ContentEntry(
            id: UUID(),
            contentType: "article",
            data: .dictionary([
                "title": .string("Original Title"),
                "content": .string("Original content")
            ]),
            status: .draft
        )

        // When: Saving the entry
        try await entry.create(on: app.db)

        // Then: A version should be created
        let versions = try await ContentVersion.query(on: app.db)
            .filter(\.$entry.$id == entry.id!)
            .all()

        XCTAssertEqual(versions.count, 1)
        XCTAssertEqual(versions.first?.version, 1)
        XCTAssertEqual(versions.first?.data, entry.data)
    }

    func testMultipleVersionCreation() async throws {
        // Given: An existing entry
        let entry = ContentEntry(
            id: UUID(),
            contentType: "article",
            data: .dictionary(["title": .string("v1")]),
            status: .draft
        )
        try await entry.create(on: app.db)

        // When: Updating the entry multiple times
        entry.data = .dictionary(["title": .string("v2")])
        try await entry.save(on: app.db)

        entry.data = .dictionary(["title": .string("v3")])
        try await entry.save(on: app.db)

        // Then: All versions should be preserved
        let versions = try await ContentVersion.query(on: app.db)
            .filter(\.$entry.$id == entry.id!)
            .sort(\.$version, .ascending)
            .all()

        XCTAssertEqual(versions.count, 3)
        XCTAssertEqual(versions[0].data.dictionaryValue?["title"], .string("v1"))
        XCTAssertEqual(versions[1].data.dictionaryValue?["title"], .string("v2"))
        XCTAssertEqual(versions[2].data.dictionaryValue?["title"], .string("v3"))
    }

    // MARK: - Version Retrieval Tests

    func testListVersions() async throws {
        // Given: Entry with multiple versions
        let entry = ContentEntry(
            id: UUID(),
            contentType: "article",
            data: .dictionary(["title": .string("Version 1")]),
            status: .draft
        )
        try await entry.create(on: app.db)

        entry.data = .dictionary(["title": .string("Version 2")])
        try await entry.save(on: app.db)

        entry.data = .dictionary(["title": .string("Version 3")])
        try await entry.save(on: app.db)

        // When: Listing versions
        let versions = try await VersionService.listVersions(entryId: entry.id!, on: app.db)

        // Then: Should return all versions in descending order
        XCTAssertEqual(versions.count, 3)
        XCTAssertEqual(versions[0].version, 3)
        XCTAssertEqual(versions[1].version, 2)
        XCTAssertEqual(versions[2].version, 1)
    }

    func testGetSpecificVersion() async throws {
        // Given: Entry with multiple versions
        let entry = ContentEntry(
            id: UUID(),
            contentType: "article",
            data: .dictionary(["title": .string("Version 1")]),
            status: .draft
        )
        try await entry.create(on: app.db)

        entry.data = .dictionary(["title": .string("Version 2")])
        try await entry.save(on: app.db)

        // When: Getting specific version
        let version = try await VersionService.getVersion(entryId: entry.id!, version: 1, on: app.db)

        // Then: Should return the correct version data
        XCTAssertEqual(version.version, 1)
        XCTAssertEqual(version.data.dictionaryValue?["title"], .string("Version 1"))
    }

    func testGetNonExistentVersion() async throws {
        // Given: An entry
        let entry = ContentEntry(
            id: UUID(),
            contentType: "article",
            data: .dictionary(["title": .string("Version 1")]),
            status: .draft
        )
        try await entry.create(on: app.db)

        // When & Then: Should throw error for non-existent version
        do {
            _ = try await VersionService.getVersion(entryId: entry.id!, version: 999, on: app.db)
            XCTFail("Expected error for non-existent version")
        } catch let error as ApiError {
            if case .notFound = error {
                // Expected error type
            } else {
                XCTFail("Expected .notFound error, got \(error)")
            }
        }
    }

    // MARK: - Version Restore Tests

    func testRestoreVersion() async throws {
        // Given: Entry with multiple versions
        let entry = ContentEntry(
            id: UUID(),
            contentType: "article",
            data: .dictionary(["title": .string("Version 1")]),
            status: .draft
        )
        try await entry.create(on: app.db)

        entry.data = .dictionary(["title": .string("Version 2")])
        try await entry.save(on: app.db)

        entry.data = .dictionary(["title": .string("Version 3")])
        try await entry.save(on: app.db)

        // When: Restoring to version 2
        let restored = try await VersionService.restore(entryId: entry.id!, version: 2, on: app.db, userId: "test-user")

        // Then: Entry should have version 2 data
        XCTAssertEqual(restored.data.dictionaryValue?["title"], .string("Version 2"))

        // And: A new version should be created
        let versions = try await ContentVersion.query(on: app.db)
            .filter(\.$entry.$id == entry.id!)
            .all()

        XCTAssertEqual(versions.count, 4) // Original 3 + 1 restore

        let latestVersion = try await VersionService.getVersion(entryId: entry.id!, version: 4, on: app.db)
        XCTAssertEqual(latestVersion.version, 4)
        XCTAssertEqual(latestVersion.data.dictionaryValue?["title"], .string("Version 2"))
        XCTAssertEqual(latestVersion.changedBy, "test-user")
    }

    func testRestoreCreatesNewVersion() async throws {
        // Given: Entry with one version
        let entry = ContentEntry(
            id: UUID(),
            contentType: "article",
            data: .dictionary(["title": .string("Original")]),
            status: .draft
        )
        try await entry.create(on: app.db)

        // When: Restoring to the only version
        let restored = try await VersionService.restore(entryId: entry.id!, version: 1, on: app.db)

        // Then: Entry data should be unchanged
        XCTAssertEqual(restored.data.dictionaryValue?["title"], .string("Original"))

        // And: A new version should still be created
        let versions = try await ContentVersion.query(on: app.db)
            .filter(\.$entry.$id == entry.id!)
            .all()

        XCTAssertEqual(versions.count, 2)
    }

    // MARK: - Diff Computation Tests

    func testSimpleFieldDiff() async throws {
        // Given: Two versions with different title
        let fromData = AnyCodableValue.dictionary([
            "title": .string("Original Title"),
            "content": .string("Same content")
        ])
        let toData = AnyCodableValue.dictionary([
            "title": .string("Updated Title"),
            "content": .string("Same content")
        ])

        // When: Computing diff
        let diff = VersionService.computeDiff(from: fromData, to: toData)

        // Then: Should show title changed, content unchanged
        if case .dictionary(let changes) = diff {
            XCTAssertNotNil(changes["title"])
            XCTAssertNil(changes["content"]) // No change

            if case .dictionary(let titleChange) = changes["title"] {
                XCTAssertEqual(titleChange["type"], .string("changed"))
                XCTAssertEqual(titleChange["from"], .string("Original Title"))
                XCTAssertEqual(titleChange["to"], .string("Updated Title"))
            } else {
                XCTFail("Title should have a change record")
            }
        } else {
            XCTFail("Diff should be a dictionary")
        }
    }

    func testFieldAdditionDiff() async throws {
        // Given: Version with new field
        let fromData = AnyCodableValue.dictionary([
            "title": .string("Same title")
        ])
        let toData = AnyCodableValue.dictionary([
            "title": .string("Same title"),
            "newField": .string("New value")
        ])

        // When: Computing diff
        let diff = VersionService.computeDiff(from: fromData, to: toData)

        // Then: Should show field added
        if case .dictionary(let changes) = diff {
            if case .dictionary(let newFieldChange) = changes["newField"] {
                XCTAssertEqual(newFieldChange["type"], .string("added"))
                XCTAssertEqual(newFieldChange["value"], .string("New value"))
            }
        }
    }

    func testFieldRemovalDiff() async throws {
        // Given: Version with field removed
        let fromData = AnyCodableValue.dictionary([
            "title": .string("Same title"),
            "removedField": .string("Will be removed")
        ])
        let toData = AnyCodableValue.dictionary([
            "title": .string("Same title")
        ])

        // When: Computing diff
        let diff = VersionService.computeDiff(from: fromData, to: toData)

        // Then: Should show field removed
        if case .dictionary(let changes) = diff {
            if case .dictionary(let removedFieldChange) = changes["removedField"] {
                XCTAssertEqual(removedFieldChange["type"], .string("removed"))
                XCTAssertEqual(removedFieldChange["value"], .string("Will be removed"))
            }
        }
    }

    func testNestedObjectDiff() async throws {
        // Given: Versions with nested object changes
        let fromData = AnyCodableValue.dictionary([
            "metadata": .dictionary([
                "author": .string("John"),
                "tags": .array([.string("swift")])
            ])
        ])
        let toData = AnyCodableValue.dictionary([
            "metadata": .dictionary([
                "author": .string("Jane"), // Changed
                "tags": .array([.string("swift")]) // Same
            ])
        ])

        // When: Computing diff
        let diff = VersionService.computeDiff(from: fromData, to: toData)

        // Then: Should show nested change
        if case .dictionary(let changes) = diff {
            if let metadataChange = changes["metadata"] {
                if case .dictionary(let nestedChanges) = metadataChange {
                    XCTAssertNotNil(nestedChanges["author"])
                    XCTAssertNil(nestedChanges["tags"])
                }
            }
        }
    }

    func testArrayDiff() async throws {
        // Given: Versions with array changes
        let fromData = AnyCodableValue.dictionary([
            "tags": .array([.string("swift"), .string("ios")])
        ])
        let toData = AnyCodableValue.dictionary([
            "tags": .array([.string("swift"), .string("vapor"), .string("ios")])
        ])

        // When: Computing diff
        let diff = VersionService.computeDiff(from: fromData, to: toData)

        // Then: Should show array changes
        if case .dictionary(let changes) = diff {
            if case .dictionary(let arrayChange) = changes["tags"] {
                XCTAssertEqual(arrayChange["type"], .string("array_changed"))

                if case .array(let changeArray) = arrayChange["changes"] {
                    XCTAssertEqual(changeArray.count, 3) // Same length as longest array

                    // Check for added item at index 1
                    if case .dictionary(let change1) = changeArray[1] {
                        XCTAssertEqual(change1["type"], .string("changed"))
                    }
                }
            }
        }
    }

    func testEmptyArrayDiff() async throws {
        // Given: Versions with array to empty array
        let fromData = AnyCodableValue.dictionary([
            "tags": .array([.string("swift"), .string("ios")])
        ])
        let toData = AnyCodableValue.dictionary([
            "tags": .array([])
        ])

        // When: Computing diff
        let diff = VersionService.computeDiff(from: fromData, to: toData)

        // Then: Should show all items removed
        if case .dictionary(let changes) = diff {
            if case .dictionary(let arrayChange) = changes["tags"] {
                XCTAssertEqual(arrayChange["type"], .string("array_changed"))
            }
        }
    }

    // MARK: - Version Pruning Tests

    func testVersionPruningJob() async throws {
        // Given: Entry with many versions (> retention limit)
        let entry = ContentEntry(
            id: UUID(),
            contentType: "article",
            data: .dictionary(["title": .string("Version 1")]),
            status: .draft
        )
        try await entry.create(on: app.db)

        // Create 15 versions (if retention is 10, should keep 5 oldest + latest versions = 6)
        for i in 2...15 {
            entry.data = .dictionary(["title": .string("Version \(i)")])
            try await entry.save(on: app.db)
        }

        // When: Running version pruning job (assuming retention is 10)
        // Note: This would be a unit test for VersionPruningJob if it existed

        // Then: Should keep appropriate versions
        let versions = try await ContentVersion.query(on: app.db)
            .filter(\.$entry.$id == entry.id!)
            .sort(\.$version, .ascending)
            .all()

        // For now, just verify all versions were created
        XCTAssertEqual(versions.count, 15)
    }
}
