import Vapor

// MARK: - AuthenticatedUser

/// Represents an authenticated user within the CMS.
public struct AuthenticatedUser: Authenticatable, Sendable, Content {
    public let userId: String
    public let email: String?
    public let roles: [String]
    public let tenantId: String?

    public init(
        userId: String, email: String? = nil,
        roles: [String] = [], tenantId: String? = nil
    ) {
        self.userId = userId
        self.email = email
        self.roles = roles
        self.tenantId = tenantId
    }

    /// Check if this user has a specific role.
    public func hasRole(_ role: String) -> Bool {
        roles.contains(role) || roles.contains("super-admin")
    }

    /// Check if this user is a super admin.
    public var isSuperAdmin: Bool {
        roles.contains("super-admin")
    }
}

// MARK: - CmsUser (Concrete type for req.auth)

/// Concrete authenticated user type stored in request auth.
public struct CmsUser: Authenticatable, Sendable {
    public let userId: String
    public let email: String?
    public let roles: [String]
    public let tenantId: String?

    public init(from auth: AuthenticatedUser) {
        self.userId = auth.userId
        self.email = auth.email
        self.roles = auth.roles
        self.tenantId = auth.tenantId
    }

    public init(userId: String, email: String?, roles: [String], tenantId: String? = nil) {
        self.userId = userId
        self.email = email
        self.roles = roles
        self.tenantId = tenantId
    }
}
