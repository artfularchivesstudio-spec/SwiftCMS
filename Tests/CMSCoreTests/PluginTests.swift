import XCTest
import Vapor
@testable import CMSCore

final class PluginTests: XCTestCase {

    // MARK: - Plugin Manifest Parsing Tests

    func testValidPluginManifestParsing() throws {
        // Given: A valid plugin.json
        let json = """
        {
            "name": "SEO Plugin",
            "version": "1.0.0",
            "description": "SEO optimization plugin",
            "author": "Plugin Author",
            "dependencies": ["Core"],
            "hooks": ["beforeSave", "afterPublish"],
            "adminPages": [
                {
                    "label": "SEO Settings",
                    "path": "/plugins/seo/settings",
                    "icon": "search"
                }
            ],
            "fieldTypes": ["seo-meta"]
        }
        """.data(using: .utf8)!

        // When: Parsing the manifest
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: json)

        // Then: All fields should be parsed correctly
        XCTAssertEqual(manifest.name, "SEO Plugin")
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertEqual(manifest.description, "SEO optimization plugin")
        XCTAssertEqual(manifest.author, "Plugin Author")
        XCTAssertEqual(manifest.dependencies, ["Core"])
        XCTAssertEqual(manifest.hooks, ["beforeSave", "afterPublish"])
        XCTAssertEqual(manifest.fieldTypes, ["seo-meta"])
        XCTAssertEqual(manifest.adminPages?.count, 1)
        XCTAssertEqual(manifest.adminPages?.first?.label, "SEO Settings")
        XCTAssertEqual(manifest.adminPages?.first?.path, "/plugins/seo/settings")
        XCTAssertEqual(manifest.adminPages?.first?.icon, "search")
    }

    func testMinimalPluginManifestParsing() throws {
        // Given: A minimal valid plugin.json
        let json = """
        {
            "name": "Simple Plugin",
            "version": "0.1.0"
        }
        """.data(using: .utf8)!

        // When: Parsing the manifest
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: json)

        // Then: Optional fields should be nil
        XCTAssertEqual(manifest.name, "Simple Plugin")
        XCTAssertEqual(manifest.version, "0.1.0")
        XCTAssertNil(manifest.description)
        XCTAssertNil(manifest.author)
        XCTAssertNil(manifest.dependencies)
        XCTAssertNil(manifest.hooks)
        XCTAssertNil(manifest.adminPages)
        XCTAssertNil(manifest.fieldTypes)
    }

    func testInvalidPluginManifestJSON() throws {
        // Given: Invalid JSON (missing required name field)
        let json = """
        {
            "version": "1.0.0"
        }
        """.data(using: .utf8)!

        // When & Then: Should throw error
        XCTAssertThrowsError(try JSONDecoder().decode(PluginManifest.self, from: json))
    }

    // MARK: - Plugin Discovery Tests

    func testPluginDiscovery() throws {
        // Given: A directory with plugin manifests
        let tempDir = NSTemporaryDirectory() + "/plugins-test/"
        let fm = FileManager.default

        // Create test directory structure
        try fm.createDirectory(atPath: tempDir + "seo-plugin", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: tempDir + "analytics-plugin", withIntermediateDirectories: true)

        // Create plugin.json files
        let seoManifest = """
        {
            "name": "SEO Plugin",
            "version": "1.0.0",
            "dependencies": ["Core"]
        }
        """
        let analyticsManifest = """
        {
            "name": "Analytics Plugin",
            "version": "2.0.0",
            "dependencies": ["Core", "SEO Plugin"]
        }
        """

        try seoManifest.write(toFile: tempDir + "seo-plugin/plugin.json", atomically: true, encoding: .utf8)
        try analyticsManifest.write(toFile: tempDir + "analytics-plugin/plugin.json", atomically: true, encoding: .utf8)

        // When: Discovering plugins
        let manifests = PluginDiscovery.discover(modulesPath: tempDir)

        // Then: Should find both plugins
        XCTAssertEqual(manifests.count, 2)

        // Cleanup
        try fm.removeItem(atPath: tempDir)
    }

    func testPluginDiscoveryEmptyDirectory() throws {
        // Given: Empty modules directory
        let tempDir = NSTemporaryDirectory() + "/empty-plugins-test/"
        let fm = FileManager.default
        try fm.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        // When: Discovering plugins
        let manifests = PluginDiscovery.discover(modulesPath: tempDir)

        // Then: Should return empty array
        XCTAssertEqual(manifests.count, 0)

        // Cleanup
        try fm.removeItem(atPath: tempDir)
    }

    func testPluginDiscoveryNonExistentDirectory() throws {
        // When: Discovering from non-existent directory
        let manifests = PluginDiscovery.discover(modulesPath: "/non/existent/path")

        // Then: Should return empty array gracefully
        XCTAssertEqual(manifests.count, 0)
    }

    // MARK: - Dependency Resolution Tests

    func testLinearDependencyResolution() {
        // Given: Plugins with linear dependencies
        let manifests = [
            PluginManifest(
                name: "C",
                version: "1.0.0",
                description: nil,
                author: nil,
                dependencies: ["B"],
                hooks: nil,
                adminPages: nil,
                fieldTypes: nil
            ),
            PluginManifest(
                name: "B",
                version: "1.0.0",
                description: nil,
                author: nil,
                dependencies: ["A"],
                hooks: nil,
                adminPages: nil,
                fieldTypes: nil
            ),
            PluginManifest(
                name: "A",
                version: "1.0.0",
                description: nil,
                author: nil,
                dependencies: nil,
                hooks: nil,
                adminPages: nil,
                fieldTypes: nil
            )
        ]

        // When: Sorting by dependencies
        let sorted = PluginDiscovery.sortByDependencies(manifests)

        // Then: Should be in dependency order (A, B, C)
        XCTAssertEqual(sorted[0].name, "A")
        XCTAssertEqual(sorted[1].name, "B")
        XCTAssertEqual(sorted[2].name, "C")
    }

    func testComplexDependencyResolution() {
        // Given: Plugins with complex dependency graph
        let manifests = [
            PluginManifest(
                name: "Analytics",
                version: "1.0.0",
                description: nil,
                author: nil,
                dependencies: ["SEO", "Core"],
                hooks: nil,
                adminPages: nil,
                fieldTypes: nil
            ),
            PluginManifest(
                name: "SEO",
                version: "1.0.0",
                description: nil,
                author: nil,
                dependencies: ["Core"],
                hooks: nil,
                adminPages: nil,
                fieldTypes: nil
            ),
            PluginManifest(
                name: "E-commerce",
                version: "1.0.0",
                description: nil,
                author: nil,
                dependencies: ["Analytics"],
                hooks: nil,
                adminPages: nil,
                fieldTypes: nil
            ),
            PluginManifest(
                name: "Core",
                version: "1.0.0",
                description: nil,
                author: nil,
                dependencies: nil,
                hooks: nil,
                adminPages: nil,
                fieldTypes: nil
            )
        ]

        // When: Sorting by dependencies
        let sorted = PluginDiscovery.sortByDependencies(manifests)

        // Then: Should respect all dependencies
        let analyticsIndex = sorted.firstIndex { $0.name == "Analytics" }!
        let seoIndex = sorted.firstIndex { $0.name == "SEO" }!
        let coreIndex = sorted.firstIndex { $0.name == "Core" }!
        let ecommerceIndex = sorted.firstIndex { $0.name == "E-commerce" }!

        XCTAssertLessThan(coreIndex, analyticsIndex)
        XCTAssertLessThan(coreIndex, seoIndex)
        XCTAssertLessThan(analyticsIndex, ecommerceIndex)
    }

    func testCircularDependencyDetection() {
        // Given: Plugins with circular dependencies
        let manifests = [
            PluginManifest(
                name: "A",
                version: "1.0.0",
                description: nil,
                author: nil,
                dependencies: ["B"],
                hooks: nil,
                adminPages: nil,
                fieldTypes: nil
            ),
            PluginManifest(
                name: "B",
                version: "1.0.0",
                description: nil,
                author: nil,
                dependencies: ["A"],
                hooks: nil,
                adminPages: nil,
                fieldTypes: nil
            )
        ]

        // When & Then: Should not hang or crash
        let sorted = PluginDiscovery.sortByDependencies(manifests)
        XCTAssertTrue(sorted.count >= 2) // Should still sort them
    }

    func testUnresolvableDependency() {
        // Given: Plugin depends on non-existent plugin
        let manifests = [
            PluginManifest(
                name: "MyPlugin",
                version: "1.0.0",
                description: nil,
                author: nil,
                dependencies: ["NonExistent"],
                hooks: nil,
                adminPages: nil,
                fieldTypes: nil
            )
        ]

        // When: Sorting
        let result = PluginDiscovery.sortByDependencies(manifests)

        // Then: Should not crash, just sort what it can
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "MyPlugin")
    }

    // MARK: - Hook Registration Tests

    func testHookDeclarationParsing() throws {
        // Given: Plugin with hooks
        let json = """
        {
            "name": "Validation Plugin",
            "version": "1.0.0",
            "hooks": ["beforeSave", "beforeDelete", "beforePublish"]
        }
        """.data(using: .utf8)!

        // When: Parsing
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: json)

        // Then: Hooks should be parsed
        XCTAssertEqual(manifest.hooks?.count, 3)
        XCTAssertTrue(manifest.hooks!.contains("beforeSave"))
        XCTAssertTrue(manifest.hooks!.contains("beforeDelete"))
        XCTAssertTrue(manifest.hooks!.contains("beforePublish"))
    }

    // MARK: - Admin Page Tests

    func testAdminPageParsing() throws {
        // Given: Plugin with admin pages
        let json = """
        {
            "name": "Settings Plugin",
            "version": "1.0.0",
            "adminPages": [
                {
                    "label": "General Settings",
                    "path": "/plugins/settings/general",
                    "icon": "cog"
                },
                {
                    "label": "Advanced Settings",
                    "path": "/plugins/settings/advanced"
                }
            ]
        }
        """.data(using: .utf8)!

        // When: Parsing
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: json)

        // Then: Admin pages should be parsed
        XCTAssertEqual(manifest.adminPages?.count, 2)
        XCTAssertEqual(manifest.adminPages?[0].label, "General Settings")
        XCTAssertEqual(manifest.adminPages?[0].icon, "cog")
        XCTAssertEqual(manifest.adminPages?[1].label, "Advanced Settings")
        XCTAssertNil(manifest.adminPages?[1].icon)
    }

    // MARK: - Field Type Tests

    func testCustomFieldTypesParsing() throws {
        // Given: Plugin with custom field types
        let json = """
        {
            "name": "Field Plugin",
            "version": "1.0.0",
            "fieldTypes": ["color-picker", "image-gallery", "location"]
        }
        """.data(using: .utf8)!

        // When: Parsing
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: json)

        // Then: Field types should be parsed
        XCTAssertEqual(manifest.fieldTypes?.count, 3)
        XCTAssertTrue(manifest.fieldTypes!.contains("color-picker"))
    }

    // MARK: - Integration Tests

    func testFullPluginLifecycle() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }

        // Given: A directory with multiple plugins
        let tempDir = NSTemporaryDirectory() + "/lifecycle-test/"
        let fm = FileManager.default

        // Create plugin directories and manifests
        try fm.createDirectory(atPath: tempDir + "plugin-a", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: tempDir + "plugin-b", withIntermediateDirectories: true)

        let manifestA = """
        {
            "name": "Plugin A",
            "version": "1.0.0",
            "dependencies": []
        }
        """
        let manifestB = """
        {
            "name": "Plugin B",
            "version": "2.0.0",
            "dependencies": ["Plugin A"],
            "hooks": ["beforeSave"]
        }
        """

        try manifestA.write(toFile: tempDir + "plugin-a/plugin.json", atomically: true, encoding: .utf8)
        try manifestB.write(toFile: tempDir + "plugin-b/plugin.json", atomically: true, encoding: .utf8)

        // When: Discovering and registering plugins
        let manifests = PluginDiscovery.discover(modulesPath: tempDir)
        let manager = ModuleManager()
        manager.discoverAndRegisterPlugins(modulesPath: tempDir, logger: app.logger)

        // Then: Should discover in correct order
        XCTAssertEqual(manifests.count, 2)
        XCTAssertEqual(manifests[0].name, "Plugin A")
        XCTAssertEqual(manifests[1].name, "Plugin B")

        // Cleanup
        try fm.removeItem(atPath: tempDir)
    }
}
