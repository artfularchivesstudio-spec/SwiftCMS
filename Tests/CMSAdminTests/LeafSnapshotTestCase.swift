import XCTest
import XCTVapor
import Leaf
import SnapshotTesting
@testable import CMSAdmin

// Ensure we run on the main actor for UI/Snapshot related tasks if needed, 
// though for HTML string snapshots it is less critical than UIWindow snapshots.

/// 🍃 **LeafSnapshotTestCase**
///
/// A base class for running snapshot tests on Vapor Leaf templates.
/// This class handles the setup of a testing `Application`, configures the `Leaf` renderer,
/// and provides helper methods for rendering templates into HTML strings or `WKWebView` instances.
///
/// **Key Features:**
/// - 🚀 **Automated Setup**: Initializes a Vapor app in `.testing` mode.
/// - 📄 **Leaf Configuration**: Points to the correct `Resources/Views` directory.
/// - 📸 **Rendering Helpers**: Easy-to-use `render` method for generating HTML.
///
/// - Note: Ensure your templates are located in `Resources/Views` relative to the working directory.
final class LeafSnapshotTestCase: XCTestCase {
    
    /// 🪵 **Logger**
    ///
    /// A logger instance for tracking test lifecycle and rendering events.
    private let logger = Logger(label: "LeafSnapshotTestCase")
    var app: Application!

    override func setUp() async throws {
        logger.info("🎬 Setting up LeafSnapshotTestCase...")
        app = try await Application.make(.testing)
        
        // Configure Leaf
        app.views.use(.leaf)
        // Point to the correct views directory
        app.leaf.configuration.rootDirectory = DirectoryConfiguration.detect().resourcesDirectory + "Views/"
        logger.debug("📂 Leaf root directory set to: \(app.leaf.configuration.rootDirectory)")
        
        // Register standard Leaf tags (e.g. #extend, #export, etc are built-in)
        // If you have custom tags, register them here.
        logger.info("✅ LeafSnapshotTestCase setup complete.")
    }

    override func tearDown() async throws {
        logger.info("🎬 Tearing down LeafSnapshotTestCase...")
        try await app.asyncShutdown()
        app = nil
        logger.info("✅ LeafSnapshotTestCase teardown complete.")
    }

    /// Renders a Leaf template with the given context and returns the HTML string.
    /// - Parameters:
    ///   - template: The name of the template (e.g., "admin/login")
    ///   - context: The Encodable context data
    /// - Returns: The rendered HTML string
    /// 🎨 **Render Template**
    ///
    /// Renders a specific Leaf template with the provided context data.
    ///
    /// - Parameters:
    ///   - template: 📄 The name of the template file (e.g., `"admin/login"`). Do not include the `.leaf` extension.
    ///   - context: 📦 The `Encodable` context data to pass to the template.
    /// - Returns: 📝 The rendered HTML string.
    /// - Throws: An error if rendering fails.
    func render<T: Encodable>(_ template: String, _ context: T) async throws -> String {
        logger.info("🖌️ Rendering template: '\(template)'")
        let view = try await app.view.render(template, context)
        let data = view.data
        let html = String(decoding: data, as: UTF8.self)
        logger.debug("✅ Rendered \(html.count) bytes.")
        return html
    }

    /// Helper to get the Public directory URL for resolving local assets (CSS/JS)
    var publicDirectoryURL: URL {
        URL(fileURLWithPath: DirectoryConfiguration.detect().workingDirectory + "Public/")
    }
}

#if canImport(WebKit)
import WebKit

extension LeafSnapshotTestCase {
    /// 🕸️ **Make WebView**
    ///
    /// Creates a `WKWebView` instance loaded with the provided HTML content.
    /// This is useful for visual snapshot testing where you want to capture the actual rendering of the page.
    ///
    /// - Parameters:
    ///   - html: 📄 The HTML string to load into the WebView.
    ///   - size: 📏 The desired size of the WebView (default: 1280x800).
    /// - Returns: 🖼️ A configured `WKWebView` instance.
    @MainActor
    func makeWebView(html: String, size: CGSize = CGSize(width: 1280, height: 800)) -> WKWebView {
        logger.info("🕸️ Creating WebView with size: \(size)")
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: config)
        webView.loadHTMLString(html, baseURL: publicDirectoryURL)
        logger.debug("🔗 Base URL set to: \(publicDirectoryURL)")
        return webView
    }
}
#endif
