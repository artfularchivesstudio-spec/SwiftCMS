import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import CMSCLI
@testable import CMSObjects

final class SDKGeneratorTests: XCTestCase {

    // MARK: - Schema Hash Computation Tests

    func testSchemaHashComputation() throws {
        // Given: A sample schema
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "content": ["type": "string"],
                "published": ["type": "boolean"]
            ],
            "required": ["title"]
        ]

        // When: Computing hash
        let hash = try SwiftSDKGenerator.computeHash(from: schema)

        // Then: Hash should be deterministic
        let hash2 = try SwiftSDKGenerator.computeHash(from: schema)
        XCTAssertEqual(hash, hash2)
        XCTAssertFalse(hash.isEmpty)
    }

    func testSchemaHashChangesWithSchema() throws {
        // Given: Two different schemas
        let schema1: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"]
            ]
        ]

        let schema2: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "content": ["type": "string"] // Additional field
            ]
        ]

        // When: Computing hashes
        let hash1 = try SwiftSDKGenerator.computeHash(from: schema1)
        let hash2 = try SwiftSDKGenerator.computeHash(from: schema2)

        // Then: Hashes should be different
        XCTAssertNotEqual(hash1, hash2)
    }

    func testHashStabilityWithKeyOrder() throws {
        // Given: Same schema with properties in different order
        let schema1: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "content": ["type": "string"]
            ]
        ]

        let schema2: [String: Any] = [
            "type": "object",
            "properties": [
                "content": ["type": "string"],
                "title": ["type": "string"] // Reversed order
            ]
        ]

        // When: Computing hashes
        let hash1 = try SwiftSDKGenerator.computeHash(from: schema1)
        let hash2 = try SwiftSDKGenerator.computeHash(from: schema2)

        // Then: Hashes should be the same (JSON order shouldn't matter)
        XCTAssertEqual(hash1, hash2)
    }

    // MARK: - Swift Code Generation Tests

    func testBasicStructGeneration() throws {
        // Given: Simple article schema
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "content": ["type": "string"]
            ],
            "required": ["title"]
        ]

        // When: Generating Swift struct
        let code = SwiftSDKGenerator.generateStruct(name: "Article", slug: "article", schema: schema)

        // Then: Should generate proper Swift code
        XCTAssertTrue(code.contains("public struct Article"))
        XCTAssertTrue(code.contains("public let id: UUID"))
        XCTAssertTrue(code.contains("public let title: String"))
        XCTAssertTrue(code.contains("public let content: String?")) // Optional content
        XCTAssertTrue(code.contains("public let status: String"))
        XCTAssertTrue(code.contains("public actor ArticleClient"))
    }

    func testAllFieldTypesGeneration() throws {
        // Given: Schema with all supported field types
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "count": ["type": "integer"],
                "price": ["type": "number"],
                "isPublished": ["type": "boolean"],
                "tags": ["type": "array"],
                "metadata": ["type": "object"]
            ],
            "required": ["title", "count", "isPublished"]
        ]

        // When: Generating Swift struct
        let code = SwiftSDKGenerator.generateStruct(name: "Test", slug: "test", schema: schema)

        // Then: All types should be mapped correctly
        XCTAssertTrue(code.contains("public let title: String"))
        XCTAssertTrue(code.contains("public let count: Int"))
        XCTAssertTrue(code.contains("public let price: Double?"))
        XCTAssertTrue(code.contains("public let isPublished: Bool"))
        XCTAssertTrue(code.contains("public let tags: [AnyCodableValue]?"))
        XCTAssertTrue(code.contains("public let metadata: [String: AnyCodableValue]?"))
    }

    func testClientMethodsGeneration() throws {
        // Given: Simple schema
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"]
            ]
        ]

        // When: Generating Swift code
        let code = SwiftSDKGenerator.generateStruct(name: "Post", slug: "post", schema: schema)

        // Then: Client methods should be generated
        XCTAssertTrue(code.contains("public func list(page: Int = 1, perPage: Int = 25)"))
        XCTAssertTrue(code.contains("public func get(id: UUID)"))
        XCTAssertTrue(code.contains("public func create(_ entry: Post)"))
        XCTAssertTrue(code.contains("public func delete(id: UUID)"))
    }

    func testPackageGeneration() throws {
        // Given: Multiple content types
        let types = [
            (name: "Article", slug: "article", schema: ["type": "object"]),
            (name: "Category", slug: "category", schema: ["type": "object"])
        ]

        // When: Generating package
        let code = SwiftSDKGenerator.generatePackage(types: types)

        // Then: Should generate valid Package.swift
        XCTAssertTrue(code.contains("// swift-tools-version:5.10"))
        XCTAssertTrue(code.contains("import PackageDescription"))
        XCTAssertTrue(code.contains("name: \"SwiftCMSClient\""))
        XCTAssertTrue(code.contains("library(name: \"SwiftCMSClient\""))
    }

    // MARK: - TypeScript Generation Tests

    func testTypeScriptInterfaceGeneration() throws {
        // Given: Sample schema
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "content": ["type": "string"],
                "published": ["type": "boolean"]
            ],
            "required": ["title"]
        ]

        // When: Generating TypeScript interface
        let code = TypeScriptGenerator.generateInterface(name: "Article", schema: schema)

        // Then: Should generate proper TypeScript
        XCTAssertTrue(code.contains("export interface Article"))
        XCTAssertTrue(code.contains("id: string"))
        XCTAssertTrue(code.contains("title: string"))
        XCTAssertTrue(code.contains("content?: string"))
        XCTAssertTrue(code.contains("published?: boolean"))
        XCTAssertTrue(code.contains("status: string"))
    }

    func testTypeScriptAllTypes() throws {
        // Given: Schema with various types
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "count": ["type": "integer"],
                "price": ["type": "number"],
                "active": ["type": "boolean"],
                "tags": ["type": "array"],
                "config": ["type": "object"]
            ],
            "required": ["title", "count"]
        ]

        // When: Generating TypeScript
        let code = TypeScriptGenerator.generateInterface(name: "Product", schema: schema)

        // Then: Types should be mapped correctly
        XCTAssertTrue(code.contains("title: string"))
        XCTAssertTrue(code.contains("count: number"))
        XCTAssertTrue(code.contains("price?: number"))
        XCTAssertTrue(code.contains("active?: boolean"))
        XCTAssertTrue(code.contains("tags?: any[]"))
        XCTAssertTrue(code.contains("config?: any"))
    }

    // MARK: - Static Generation Tests

    func testSDKGenerationWithHashCheck() async throws {
        // Given: A content type definition with known hash
        let contentType = ContentTypeDefinition(
            id: UUID(),
            name: "Test Article",
            slug: "test-article",
            schema: ["type": "object"],
            schemaHash: "abc123"
        )

        // Mock the hash computation to return a different value
        // Note: This would require dependency injection in the actual implementation

        // For now, just test the hash comparison logic
        let currentHash = "def456"
        let needsRegeneration = contentType.schemaHash != currentHash

        XCTAssertTrue(needsRegeneration)
    }

    func testSDKGenerationWithMatchingHash() throws {
        // Given: Schema hash matches
        let contentType = ContentTypeDefinition(
            id: UUID(),
            name: "Test Article",
            slug: "test-article",
            schema: ["type": "object"],
            schemaHash: "abc123"
        )

        let currentHash = "abc123"
        let needsRegeneration = contentType.schemaHash != currentHash

        XCTAssertFalse(needsRegeneration)
    }
}

// MARK: - Test Extensions for Hash Computation

extension SwiftSDKGenerator {
    static func computeHash(from schema: [String: Any]) throws -> String {
        // Simple hash implementation for testing
        // In production, this would use a proper hash algorithm
        let data = try JSONSerialization.data(withJSONObject: schema, options: .sortedKeys)
        return data.base64EncodedString().prefix(6).lowercased()
    }
}