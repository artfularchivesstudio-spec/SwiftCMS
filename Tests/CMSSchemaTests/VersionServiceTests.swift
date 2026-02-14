import XCTest
import Vapor
import Fluent
@testable import CMSSchema
@testable import CMSObjects
import XCTVapor

final class VersionServiceTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
        try await app.autoMigrate()
    }

    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
    }

    // MARK: - Basic Diff Tests

    func testDiffAddedFields() async throws {
        let entryId = UUID()
        let fromData: AnyCodableValue = ["title": "Original Title"]
        let toData: AnyCodableValue = [
            "title": "Original Title",
            "description": "New description"
        ]

        let diff = VersionService.computeDiff(from: fromData, to: toData)

        guard let diffDict = diff.dictionaryValue else {
            XCTFail("Expected dictionary diff")
            return
        }

        XCTAssertEqual(diffDict["title"], nil, "Unchanged fields should not appear in diff")

        guard let descriptionDiff = diffDict["description"], let descriptionDict = descriptionDiff.dictionaryValue else {
            XCTFail("Expected description diff with type 'added'")
            return
        }

        XCTAssertEqual(descriptionDict["type"], "added")
        XCTAssertEqual(descriptionDict["value"], "New description")
    }

    func testDiffRemovedFields() async throws {
        let fromData: AnyCodableValue = [
            "title": "Original Title",
            "description": "Old description"
        ]
        let toData: AnyCodableValue = ["title": "Original Title"]

        let diff = VersionService.computeDiff(from: fromData, to: toData)

        guard let diffDict = diff.dictionaryValue else {
            XCTFail("Expected dictionary diff")
            return
        }

        guard let descriptionDiff = diffDict["description"], let descriptionDict = descriptionDiff.dictionaryValue else {
            XCTFail("Expected description diff with type 'removed'")
            return
        }

        XCTAssertEqual(descriptionDict["type"], "removed")
        XCTAssertEqual(descriptionDict["value"], "Old description")
    }

    func testDiffChangedFields() async throws {
        let fromData: AnyCodableValue = ["title": "Original Title"]
        let toData: AnyCodableValue = ["title": "Updated Title"]

        let diff = VersionService.computeDiff(from: fromData, to: toData)

        guard let diffDict = diff.dictionaryValue else {
            XCTFail("Expected dictionary diff")
            return
        }

        guard let titleDiff = diffDict["title"], let titleDict = titleDiff.dictionaryValue else {
            XCTFail("Expected title diff with type 'changed'")
            return
        }

        XCTAssertEqual(titleDict["type"], "changed")
        XCTAssertEqual(titleDict["from"], "Original Title")
        XCTAssertEqual(titleDict["to"], "Updated Title")
    }

    // MARK: - Nested Object Tests

    func testDiffNestedObjectChanges() async throws {
        let fromData: AnyCodableValue = [
            "config": [
                "theme": "dark",
                "language": "en"
            ]
        ]
        let toData: AnyCodableValue = [
            "config": [
                "theme": "light",
                "language": "en"
            ]
        ]

        let diff = VersionService.computeDiff(from: fromData, to: toData)

        guard let diffDict = diff.dictionaryValue else {
            XCTFail("Expected dictionary diff")
            return
        }

        guard let configDiff = diffDict["config"], let configDict = configDiff.dictionaryValue else {
            XCTFail("Expected config diff")
            return
        }

        // Should recursively diff the nested object
        XCTAssertNotNil(configDict["theme"])
        XCTAssertNotNil(configDict["language"])
    }

    func testDiffNestedObjectAdded() async throws {
        let fromData: AnyCodableValue = ["title": "Test"]
        let toData: AnyCodableValue = [
            "title": "Test",
            "metadata": [
                "author": "John Doe",
                "tags": ["test", "sample"]
            ]
        ]

        let diff = VersionService.computeDiff(from: fromData, to: toData)

        guard let diffDict = diff.dictionaryValue else {
            XCTFail("Expected dictionary diff")
            return
        }

        guard let metadataDiff = diffDict["metadata"], let metadataDict = metadataDiff.dictionaryValue else {
            XCTFail("Expected metadata diff")
            return
        }

        XCTAssertEqual(metadataDict["type"], "added")
    }

    // MARK: - Array Tests

    func testDiffArrayChanges() async throws {
        let fromData: AnyCodableValue = [
            "tags": ["old", "tags"]
        ]
        let toData: AnyCodableValue = [
            "tags": ["new", "tags", "here"]
        ]

        let diff = VersionService.computeDiff(from: fromData, to: toData)

        guard let diffDict = diff.dictionaryValue else {
            XCTFail("Expected dictionary diff")
            return
        }

        guard let tagsDiff = diffDict["tags"], let tagsDict = tagsDiff.dictionaryValue else {
            XCTFail("Expected tags diff")
            return
        }

        XCTAssertEqual(tagsDict["type"], "array_changed")

        guard let changesArray = tagsDict["changes"]?.arrayValue else {
            XCTFail("Expected changes array")
            return
        }

        XCTAssertEqual(changesArray.count, 3) // max length of both arrays
    }

    func testDiffEmptyArrayToPopulated() async throws {
        let fromData: AnyCodableValue = ["items": []]
        let toData: AnyCodableValue = ["items": ["item1", "item2"]]

        let diff = VersionService.computeDiff(from: fromData, to: toData)

        guard let diffDict = diff.dictionaryValue else {
            XCTFail("Expected dictionary diff")
            return
        }

        guard let itemsDiff = diffDict["items"], let itemsDict = itemsDiff.dictionaryValue else {
            XCTFail("Expected items diff")
            return
        }

        XCTAssertEqual(itemsDict["type"], "array_changed")
    }

    func testDiffDifferentTypes() async throws {
        let fromData: AnyCodableValue = ["value": "string value"]
        let toData: AnyCodableValue = ["value": 42]

        let diff = VersionService.computeDiff(from: fromData, to: toData)

        guard let diffDict = diff.dictionaryValue else {
            XCTFail("Expected dictionary diff")
            return
        }

        guard let valueDiff = diffDict["value"], let valueDict = valueDiff.dictionaryValue else {
            XCTFail("Expected value diff")
            return
        }

        XCTAssertEqual(valueDict["type"], "changed")
        XCTAssertEqual(valueDict["from"], "string value")
        XCTAssertEqual(valueDict["to"], 42)
    }

    // MARK: - Complex Nested Structure Tests

    func testDiffComplexNestedStructure() async throws {
        let fromData: AnyCodableValue = [
            "page": [
                "title": "Home",
                "sections": [
                    [
                        "type": "hero",
                        "content": "Welcome"
                    ],
                    [
                        "type": "features",
                        "items": ["feat1", "feat2"]
                    ]
                ]
            ]
        ]

        let toData: AnyCodableValue = [
            "page": [
                "title": "Home",
                "sections": [
                    [
                        "type": "hero",
                        "content": "Welcome to our site"
                    ],
                    [
                        "type": "features",
                        "items": ["feat1", "feat2", "feat3"]
                    ],
                    [
                        "type": "cta",
                        "button": "Get Started"
                    ]
                ]
            ]
        ]

        let diff = VersionService.computeDiff(from: fromData, to: toData)

        guard let diffDict = diff.dictionaryValue else {
            XCTFail("Expected dictionary diff")
            return
        }

        // Should detect changes in nested structure
        XCTAssertNotNil(diffDict["page"])

        guard let pageDiff = diffDict["page"]?.dictionaryValue else {
            XCTFail("Expected page diff")
            return
        }

        // Hero section content changed
        XCTAssertNotNil(pageDiff["sections"])
    }

    // MARK: - Database Integration Tests

    func testListVersions() async throws {
        let entry = ContentEntry(contentType: "test")
        try await entry.save(on: app.db)

        // Create multiple versions
        for i in 1...3 {
            let version = ContentVersion(
                entryID: entry.id!,
                version: i,
                data: ["version": i],
                changedBy: "user\(i)"
            )
            try await version.save(on: app.db)
        }

        let versions = try await VersionService.listVersions(entryId: entry.id!, on: app.db)

        XCTAssertEqual(versions.count, 3)
        XCTAssertEqual(versions[0].version, 3) // Should be sorted descending
        XCTAssertEqual(versions[2].version, 1)
    }

    func testGetVersion() async throws {
        let entry = ContentEntry(contentType: "test")
        try await entry.save(on: app.db)

        let version = ContentVersion(
            entryID: entry.id!,
            version: 1,
            data: ["test": "data"],
            changedBy: "testuser"
        )
        try await version.save(on: app.db)

        let fetched = try await VersionService.getVersion(
            entryId: entry.id!,
            version: 1,
            on: app.db
        )

        XCTAssertEqual(fetched.version, 1)
        XCTAssertEqual(fetched.changedBy, "testuser")
    }

    func testDiffThroughService() async throws {
        let entry = ContentEntry(contentType: "test")
        try await entry.save(on: app.db)

        // Create version 1
        let version1 = ContentVersion(
            entryID: entry.id!,
            version: 1,
            data: ["title": "Version 1", "status": "draft"],
            changedBy: "user1"
        )
        try await version1.save(on: app.db)

        // Create version 2
        let version2 = ContentVersion(
            entryID: entry.id!,
            version: 2,
            data: ["title": "Version 2", "status": "published"],
            changedBy: "user2"
        )
        try await version2.save(on: app.db)

        let diff = try await VersionService.diff(
            entryId: entry.id!,
            fromVersion: 1,
            toVersion: 2,
            on: app.db
        )

        guard let diffDict = diff.dictionaryValue else {
            XCTFail("Expected dictionary diff")
            return
        }

        XCTAssertNotNil(diffDict["title"])
        XCTAssertNotNil(diffDict["status"])
    }
}

// MARK: - Helper Extensions

extension VersionService {
    static func computeDiff(from: AnyCodableValue, to: AnyCodableValue) -> AnyCodableValue {
        return VersionService.computeDiff(from: from, to: to)
    }
}
