import XCTest
import XCTVapor
import SnapshotTesting
@testable import CMSAdmin
@testable import CMSCore // For context structs if accessible, or redefine mocks

/// 🧪 **Admin Snapshot Tests**
///
/// A comprehensive suite of snapshot tests for the SwiftCMS Admin UI.
/// These tests verify both the HTML structure (logic-less templates) and the visual rendering (CSS/JS integration).
///
/// **Coverage Areas:**
/// - 🔐 **Authentication**: Login success and error states.
/// - 📊 **Dashboard**: Metrics, charts, and activity feeds.
/// - 📱 **Responsiveness**: (Planned) Mobile breakpoint validation.
final class AdminSnapshotTests: LeafSnapshotTestCase {
    
    /// 🪵 **Logger**
    private let logger = Logger(label: "AdminSnapshotTests")
    
    struct DashboardContext: Encodable {
        let title: String
        let typeCount: Int
        let entryCount: Int
        let recentEntries: [MockEntry]
        let activePage: String
        let contentTypes: [SidebarContentType]
        let greeting: String
        let userCount: Int
        let storageUsed: String
        let recentMedia: [String]
    }

    struct SidebarContentType: Encodable {
        let slug: String
        let displayName: String
    }
    
    struct MockEntry: Encodable {
        let id: String
        let contentType: String
        let status: String
        let createdAt: String
        let data: [String: String]
    }

    /// 📸 **Test Login Page (Default State)**
    ///
    /// Verifies the initial state of the login page.
    /// - Expects: Clean form with email/password inputs and "Sign In" button.
    func testLoginSnapshot() async throws {
        logger.info("🎬 Starting testLoginSnapshot...")
        
        struct LoginContext: Encodable {
            let title: String
            let error: String?
        }

        let context = LoginContext(title: "Login", error: nil)
        logger.debug("📦 Context prepared: \(context)")
        
        let html = try await render("admin/login", context)
        
        // Verify HTML structure matches baseline
        logger.info("📸 Asserting snapshot for 'Login_Default'...")
        assertSnapshot(of: html, as: .lines, named: "Login_Default")
        logger.info("✅ testLoginSnapshot passed.")
    }

    /// 🚨 **Test Login Page (Error State)**
    ///
    /// Verifies the login page when an error message is present.
    /// - Expects: Alert banner displaying "Invalid credentials".
    func testLoginErrorSnapshot() async throws {
        logger.info("🎬 Starting testLoginErrorSnapshot...")
        
        struct LoginContext: Encodable {
            let title: String
            let error: String?
        }

        let context = LoginContext(title: "Login", error: "Invalid credentials")
        logger.debug("📦 Context prepared: \(context)")
        
        let html = try await render("admin/login", context)
        
        logger.info("📸 Asserting snapshot for 'Login_Error'...")
        assertSnapshot(of: html, as: .lines, named: "Login_Error")
        logger.info("✅ testLoginErrorSnapshot passed.")
    }

    /// 📊 **Test Dashboard (Default State)**
    ///
    /// Verifies the layout of the main dashboard.
    /// - Expects: Stats cards, sidebar navigation, and empty tables for recent activity.
    func testDashboardSnapshot() async throws {
        logger.info("🎬 Starting testDashboardSnapshot...")
        
        // Mock data for dashboard
        // Context structs moved to class level

        // Note: We need to match the context expected by dashboard.leaf exactly.
        // Since Leaf accepts any Encodable, we can mock the structure without needing existing model types
        // provided the property names match what the template uses.
        
        let context = DashboardContext(
            title: "Dashboard",
            typeCount: 5,
            entryCount: 42,
            recentEntries: [], // Empty for now to simplify
            activePage: "dashboard",
            contentTypes: [
                SidebarContentType(slug: "post", displayName: "Post"),
                SidebarContentType(slug: "product", displayName: "Product")
            ],
            greeting: "Good Morning",
            userCount: 3,
            storageUsed: "350MB",
            recentMedia: []
        )
        logger.debug("📦 Dashboard Context prepared.")

        let html = try await render("admin/dashboard", context)
        
        logger.info("📸 Asserting snapshot for 'Dashboard_Default'...")
        assertSnapshot(of: html, as: .lines, named: "Dashboard_Default")
        logger.info("✅ testDashboardSnapshot passed.")
    }


    #if canImport(WebKit)
    /// 🖼️ **Test Dashboard (Visual Snapshot)**
    ///
    /// Capture a full visual snapshot of the Dashboard using WebKit.
    /// - Requires: macOS environment with WebKit available.
    /// - Verifies: CSS styling, Layout, Chart.js placeholder rendering.
    @MainActor
    func testDashboardVisualSnapshot() async throws {
        logger.info("🎬 Starting testDashboardVisualSnapshot...")
        
        let context = DashboardContext(
            title: "Dashboard",
            typeCount: 5,
            entryCount: 42,
            recentEntries: [],
            activePage: "dashboard",
            contentTypes: [
                SidebarContentType(slug: "post", displayName: "Post"),
                SidebarContentType(slug: "product", displayName: "Product")
            ],
            greeting: "Good Morning",
            userCount: 3,
            storageUsed: "350MB",
            recentMedia: []
        )
        logger.debug("📦 Visual Context prepared.")

        let html = try await render("admin/dashboard", context)
        
        logger.info("🕸️ Spinning up WebView...")
        let webView = makeWebView(html: html)
        
        // Use a slightly larger tolerance for cross-platform rendering diffs if needed
        logger.info("📸 Asserting visual snapshot for 'Dashboard_Visual'...")
        assertSnapshot(of: webView, as: .image(precision: 0.98), named: "Dashboard_Visual")
        logger.info("✅ testDashboardVisualSnapshot passed.")
    }
    #endif
}
