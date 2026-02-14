import XCTest
import XCTVapor
import Leaf
import SnapshotTesting
@testable import CMSAdmin

// Ensure we run on the main actor for UI/Snapshot related tasks if needed, 
// though for HTML string snapshots it is less critical than UIWindow snapshots.
final class LeafSnapshotTestCase: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        
        // Configure Leaf
        app.views.use(.leaf)
        // Point to the correct views directory
        app.leaf.configuration.rootDirectory = DirectoryConfiguration.detect().resourcesDirectory + "Views/"
        
        // Register standard Leaf tags (e.g. #extend, #export, etc are built-in)
        // If you have custom tags, register them here.
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
        app = nil
    }

    /// Renders a Leaf template with the given context and returns the HTML string.
    /// - Parameters:
    ///   - template: The name of the template (e.g., "admin/login")
    ///   - context: The Encodable context data
    /// - Returns: The rendered HTML string
    func render<T: Encodable>(_ template: String, _ context: T) async throws -> String {
        let view = try await app.view.render(template, context)
        let data = view.data
        return String(decoding: data, as: UTF8.self)
    }
}
