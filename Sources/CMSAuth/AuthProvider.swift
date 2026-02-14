import Vapor
import Fluent
import CMSSchema
import CMSObjects

// MARK: - AuthProvider Protocol

/// Contract for authentication providers.
public protocol AuthProvider: Sendable {
    /// Provider name (e.g., "auth0", "firebase", "local").
    var name: String { get }

    /// Configure the provider on application boot.
    func configure(app: Application) throws

    /// Verify a token and return the authenticated user.
    func verify(token: String, on req: Request) async throws -> AuthenticatedUser

    /// Return middleware for protecting routes.
    func middleware() -> any AsyncMiddleware
}



// MARK: - RBAC Middleware

/// Middleware that enforces role-based access control.
public struct RBACMiddleware: AsyncMiddleware, Sendable {
    let contentTypeSlug: String?
    let action: String

    public init(contentTypeSlug: String? = nil, action: String) {
        self.contentTypeSlug = contentTypeSlug
        self.action = action
    }

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let user = request.auth.get(CmsUser.self) else {
            throw ApiError.unauthorized()
        }

        // Super admin bypasses all checks
        if user.roles.contains("super-admin") {
            return try await next.respond(to: request)
        }

        // Determine content type slug from route or initializer
        let slug = contentTypeSlug ?? request.parameters.get("contentType") ?? "*"

        // Check permissions in database
        let hasPermission = try await Permission.query(on: request.db)
            .join(Role.self, on: \Permission.$role.$id == \Role.$id)
            .group(.or) { group in
                for role in user.roles {
                    group.filter(Role.self, \.$slug == role)
                }
            }
            .group(.or) { group in
                group.filter(\.$contentTypeSlug == slug)
                group.filter(\.$contentTypeSlug == "*")
            }
            .filter(\.$action == action)
            .first() != nil

        guard hasPermission else {
            throw ApiError.forbidden("You do not have '\(action)' permission on '\(slug)'")
        }

        return try await next.respond(to: request)
    }
}

// MARK: - API Key Middleware

/// Middleware that authenticates via X-API-Key header.
public struct ApiKeyMiddleware: AsyncMiddleware, Sendable {
    public init() {}

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Skip if already authenticated
        if request.auth.has(CmsUser.self) {
            return try await next.respond(to: request)
        }

        guard let apiKeyValue = request.headers.first(name: "X-API-Key") else {
            return try await next.respond(to: request)
        }

        // Hash the key and look it up
        let keyHash = try Bcrypt.hash(apiKeyValue)
        // In practice, we'd store the hash and compare; simplified here
        guard let apiKey = try await ApiKey.query(on: request.db)
            .filter(\.$keyHash == keyHash)
            .first()
        else {
            throw ApiError.unauthorized("Invalid API key")
        }

        // Check expiry
        if let expiresAt = apiKey.expiresAt, expiresAt < Date() {
            throw ApiError.unauthorized("API key expired")
        }

        // Update last used
        apiKey.lastUsedAt = Date()
        try await apiKey.save(on: request.db)

        // Create synthetic user from API key
        let user = CmsUser(
            userId: "apikey:\(apiKey.id?.uuidString ?? "unknown")",
            email: nil,
            roles: ["super-admin"],  // API keys get full access for now
            tenantId: apiKey.tenantId
        )
        request.auth.login(user)

        return try await next.respond(to: request)
    }
}

// MARK: - Session Auth Middleware

/// Middleware for admin panel session authentication.
public struct SessionAuthRedirectMiddleware: AsyncMiddleware, Sendable {
    let loginPath: String

    public init(loginPath: String = "/admin/login") {
        self.loginPath = loginPath
    }

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        if request.auth.has(CmsUser.self) || request.auth.has(User.self) {
            return try await next.respond(to: request)
        }
        return request.redirect(to: loginPath)
    }
}

// MARK: - Auth Provider Factory

/// Factory for creating auth providers based on environment configuration.
public struct AuthProviderFactory: Sendable {
    public static func create(from environment: Environment) -> AuthProvider {
        let providerName = Environment.get("AUTH_PROVIDER") ?? "local"
        switch providerName.lowercased() {
        case "auth0":
            return Auth0Provider()
        case "firebase":
            return FirebaseAuthProvider()
        case "local":
            return LocalJWTProvider()
        default:
            return LocalJWTProvider()
        }
    }
}

// MARK: - JWT Bearer Authenticator

/// Generic JWT bearer authenticator for API requests.
public struct JWTBearerAuthenticator: AsyncBearerAuthenticator, Sendable {
    let provider: AuthProvider

    public init(provider: AuthProvider) {
        self.provider = provider
    }

    public func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        let user = try await provider.verify(token: bearer.token, on: request)
        let cmsUser = CmsUser(from: user)
        request.auth.login(cmsUser)
    }
}
