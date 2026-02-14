import Vapor

/// DTO for CORS configuration settings.
public struct CORSConfigurationDTO: Content, Sendable {
    /// Allowed origins for CORS requests.
    public let allowedOrigins: [String]

    /// Whether credentials (cookies, auth headers) are allowed.
    public let allowCredentials: Bool

    /// Allowed HTTP methods.
    public let allowedMethods: [String]

    /// Allowed HTTP headers.
    public let allowedHeaders: [String]

    /// Exposed HTTP headers.
    public let exposedHeaders: [String]

    /// Preflight cache duration in seconds.
    public let cacheExpiration: Int

    /// Whether to log CORS decisions.
    public let logDecisions: Bool

    /// Per-tenant origin overrides.
    public let tenantOrigins: [String: [String]]

    public init(
        allowedOrigins: [String],
        allowCredentials: Bool,
        allowedMethods: [String],
        allowedHeaders: [String],
        exposedHeaders: [String],
        cacheExpiration: Int,
        logDecisions: Bool,
        tenantOrigins: [String: [String]]
    ) {
        self.allowedOrigins = allowedOrigins
        self.allowCredentials = allowCredentials
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.exposedHeaders = exposedHeaders
        self.cacheExpiration = cacheExpiration
        self.logDecisions = logDecisions
        self.tenantOrigins = tenantOrigins
    }
}

/// DTO for updating CORS configuration.
public struct UpdateCORSConfigurationDTO: Content, Sendable, Validatable {
    /// Allowed origins for CORS requests.
    public let allowedOrigins: [String]?

    /// Whether credentials (cookies, auth headers) are allowed.
    public let allowCredentials: Bool?

    /// Allowed HTTP methods.
    public let allowedMethods: [String]?

    /// Allowed HTTP headers.
    public let allowedHeaders: [String]?

    /// Exposed HTTP headers.
    public let exposedHeaders: [String]?

    /// Preflight cache duration in seconds.
    public let cacheExpiration: Int?

    /// Whether to log CORS decisions.
    public let logDecisions: Bool?

    /// Per-tenant origin overrides to add/update.
    public let addTenantOrigins: [String: [String]]?

    /// Per-tenant origin overrides to remove.
    public let removeTenantOrigins: [String]?

    public init(
        allowedOrigins: [String]? = nil,
        allowCredentials: Bool? = nil,
        allowedMethods: [String]? = nil,
        allowedHeaders: [String]? = nil,
        exposedHeaders: [String]? = nil,
        cacheExpiration: Int? = nil,
        logDecisions: Bool? = nil,
        addTenantOrigins: [String: [String]]? = nil,
        removeTenantOrigins: [String]? = nil
    ) {
        self.allowedOrigins = allowedOrigins
        self.allowCredentials = allowCredentials
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.exposedHeaders = exposedHeaders
        self.cacheExpiration = cacheExpiration
        self.logDecisions = logDecisions
        self.addTenantOrigins = addTenantOrigins
        self.removeTenantOrigins = removeTenantOrigins
    }

    public static func validations(_ validations: inout Validations) {
        validations.add("allowedOrigins", as: [String].self, required: false)
        validations.add("cacheExpiration", as: Int?.self, is: .nil || .range(0...))
    }
}
