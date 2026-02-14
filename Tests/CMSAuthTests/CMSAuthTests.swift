import XCTest
@testable import CMSAuth
@testable import CMSObjects

final class CMSAuthTests: XCTestCase {

    func testAuthenticatedUserRoles() {
        let user = AuthenticatedUser(
            userId: "u-1",
            email: "admin@test.com",
            roles: ["super-admin", "editor"]
        )
        XCTAssertTrue(user.hasRole("super-admin"))
        XCTAssertTrue(user.hasRole("editor"))
        XCTAssertTrue(user.hasRole("anything")) // super-admin bypasses
        XCTAssertTrue(user.isSuperAdmin)
    }

    func testNonAdminRoleCheck() {
        let user = AuthenticatedUser(
            userId: "u-2",
            email: "author@test.com",
            roles: ["author"]
        )
        XCTAssertTrue(user.hasRole("author"))
        XCTAssertFalse(user.hasRole("editor"))
        XCTAssertFalse(user.isSuperAdmin)
    }

    func testCmsUserFromAuthenticatedUser() {
        let auth = AuthenticatedUser(
            userId: "u-1",
            email: "test@test.com",
            roles: ["editor"],
            tenantId: "t-1"
        )
        let cms = CmsUser(from: auth)
        XCTAssertEqual(cms.userId, "u-1")
        XCTAssertEqual(cms.email, "test@test.com")
        XCTAssertEqual(cms.roles, ["editor"])
        XCTAssertEqual(cms.tenantId, "t-1")
    }

    func testAuthProviderFactory() {
        // Default should be local
        let provider = AuthProviderFactory.create(from: .development)
        XCTAssertEqual(provider.name, "local")
    }
}
