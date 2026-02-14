import Vapor

/// DTO for rate limit configuration settings.
public struct RateLimitConfigurationDTO: Content, Sendable {
    /// Default rate limit for anonymous requests (requests per minute).
    public let anonymousLimit: Int

    /// Default rate limit for authenticated users (requests per minute).
    public let authenticatedLimit: Int

    /// Role-based rate limit overrides (requests per minute).
    public let roleLimits: [String: Int]

    /// Tenant-specific rate limit overrides.
    public let tenantLimits: [String: Int]

    /// Rate limit window in seconds.
    public let windowSeconds: Int

    /// Whether to allow admins to bypass rate limits.
    public let adminBypass: Bool

    /// Admin roles that bypass rate limiting.
    public let adminRoles: Set<String>

    public init(
        anonymousLimit: Int,
        authenticatedLimit: Int,
        roleLimits: [String: Int],
        tenantLimits: [String: Int],
        windowSeconds: Int,
        adminBypass: Bool,
        adminRoles: Set<String>
    ) {
        self.anonymousLimit = anonymousLimit
        self.authenticatedLimit = authenticatedLimit
        self.roleLimits = roleLimits
        self.tenantLimits = tenantLimits
        self.windowSeconds = windowSeconds
        self.adminBypass = adminBypass
        self.adminRoles = adminRoles
    }
}

/// DTO for updating rate limit configuration.
public struct UpdateRateLimitConfigurationDTO: Content, Sendable, Validatable {
    /// Default rate limit for anonymous requests (requests per minute).
    public let anonymousLimit: Int?

    /// Default rate limit for authenticated users (requests per minute).
    public let authenticatedLimit: Int?

    /// Role-based rate limit overrides (requests per minute).
    public let roleLimits: [String: Int]?

    /// Tenant-specific rate limit overrides to add/update.
    public let addTenantLimits: [String: Int]?

    /// Tenant-specific rate limit overrides to remove.
    public let removeTenants: [String]?

    /// Rate limit window in seconds.
    public let windowSeconds: Int?

    /// Whether to allow admins to bypass rate limits.
    public let adminBypass: Bool?

    /// Admin roles that bypass rate limiting.
    public let addAdminRoles: [String]?

    /// Admin roles to remove from bypass list.
    public let removeAdminRoles: [String]?

    public init(
        anonymousLimit: Int? = nil,
        authenticatedLimit: Int? = nil,
        roleLimits: [String: Int]? = nil,
        addTenantLimits: [String: Int]? = nil,
        removeTenants: [String]? = nil,
        windowSeconds: Int? = nil,
        adminBypass: Bool? = nil,
        addAdminRoles: [String]? = nil,
        removeAdminRoles: [String]? = nil
    ) {
        self.anonymousLimit = anonymousLimit
        self.authenticatedLimit = authenticatedLimit
        self.roleLimits = roleLimits
        self.addTenantLimits = addTenantLimits
        self.removeTenants = removeTenants
        self.windowSeconds = windowSeconds
        self.adminBypass = adminBypass
        self.addAdminRoles = addAdminRoles
        self.removeAdminRoles = removeAdminRoles
    }

    public static func validations(_ validations: inout Validations) {
        validations.add("anonymousLimit", as: Int?.self, is: .nil || .range(1...))
        validations.add("authenticatedLimit", as: Int?.self, is: .nil || .range(1...))
        validations.add("windowSeconds", as: Int?.self, is: .nil || .range(1...))
    }
}

/// DTO for rate limit usage statistics.
public struct RateLimitUsageDTO: Content, Sendable {
    /// The identifier being rate limited (user ID or IP).
    public let identifier: String

    /// The rate limit for this identifier.
    public let limit: Int

    /// The number of requests made in the current window.
    public let current: Int

    /// The number of requests remaining in the current window.
    public let remaining: Int

    /// Unix timestamp when the rate limit window resets.
    public let resetAt: Int

    /// The rate limit window duration in seconds.
    public let windowSeconds: Int

    public init(
        identifier: String,
        limit: Int,
        current: Int,
        remaining: Int,
        resetAt: Int,
        windowSeconds: Int
    ) {
        self.identifier = identifier
        self.limit = limit
        self.current = current
        self.remaining = remaining
        self.resetAt = resetAt
        self.windowSeconds = windowSeconds
    }
}
