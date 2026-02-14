import XCTest
import XCTVapor
import SnapshotTesting
@testable import CMSAdmin
@testable import CMSCore // For context structs if accessible, or redefine mocks

final class AdminSnapshotTests: LeafSnapshotTestCase {

    func testLoginSnapshot() async throws {
        struct LoginContext: Encodable {
            let title: String
            let error: String?
        }

        let html = try await render("admin/login", LoginContext(title: "Login", error: nil))
        
        // Verify HTML structure matches baseline
        assertSnapshot(of: html, as: .lines, named: "Login_Default")
    }

    func testLoginErrorSnapshot() async throws {
        struct LoginContext: Encodable {
            let title: String
            let error: String?
        }

        let html = try await render("admin/login", LoginContext(title: "Login", error: "Invalid credentials"))
        
        assertSnapshot(of: html, as: .lines, named: "Login_Error")
    }

    func testDashboardSnapshot() async throws {
        // Mock data for dashboard
        struct SidebarContentType: Encodable {
            let slug: String
            let displayName: String
        }
        
        struct MockEntry: Encodable {
            let id: String
            let contentType: String
            let status: String
            let createdAt: String
            // Flattened data for simplicity in template access
            let data: [String: String] 
        }

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
            let recentMedia: [String] // Mock
        }

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

        let html = try await render("admin/dashboard", context)
        
        assertSnapshot(of: html, as: .lines, named: "Dashboard_Default")
    }
}
