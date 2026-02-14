import Vapor
import Fluent
import CMSApi
import CMSAdmin
import CMSAuth
import CMSMedia
import CMSObjects
import CMSSchema

/// Register all application routes.
public func routes(_ app: Application) throws {
    // ─── Health Checks ────────────────────────────────────────────
    app.get("healthz") { req -> HTTPStatus in
        .ok
    }

    app.get("ready") { req async throws -> Response in
        // Check database
        do {
            _ = try await CMSSchema.User.query(on: req.db).first()
        } catch {
            let res = Response(status: .serviceUnavailable)
            try res.content.encode(["status": "database unavailable"])
            return res
        }
        let res = Response(status: .ok)
        try res.content.encode(["status": "ready"])
        return res
    }

    app.get("startup") { req -> HTTPStatus in
        .ok
    }

    // ─── API v1 ───────────────────────────────────────────────────
    var api = app.grouped("api", "v1")
        .grouped(RateLimitMiddleware())
        .grouped(ResponseCacheMiddleware(ttl: 300))

    // Auth middleware (optional - allows unauthenticated for public reads)
    let authProvider = app.storage[AuthProviderKey.self]
    if let provider = authProvider {
        api = api.grouped(provider.middleware())
    }

    // Content type management
    try api.register(collection: ContentTypeController())

    // Dynamic content CRUD
    try api.register(collection: DynamicContentController())

    // Media endpoints
    try api.register(collection: MediaController())

    // Search
    try api.register(collection: SearchController())

    // Preview endpoints
    try api.register(collection: PreviewController())

    // Bulk operations
    try app.register(collection: BulkOperationsController())

    // Content type import/export
    try app.register(collection: ContentTypeImportExportController())

    // Auth endpoints
    api.post("auth", "login") { req async throws -> TokenResponseDTO in
        let dto = try req.content.decode(LoginDTO.self)

        guard let user = try await CMSSchema.User.query(on: req.db)
            .filter(\.$email == dto.email)
            .with(\.$role)
            .first(),
              let passwordHash = user.passwordHash,
              try Bcrypt.verify(dto.password, created: passwordHash)
        else {
            throw ApiError.unauthorized("Invalid credentials")
        }

        let token = try LocalJWTProvider.issueToken(
            userId: user.id?.uuidString ?? "",
            email: user.email,
            roles: [user.role.slug]
        )

        return TokenResponseDTO(token: token)
    }

    // ─── Admin Panel ──────────────────────────────────────────────
    try app.register(collection: AdminController())
    try app.register(collection: RolesController())
    try app.register(collection: VersionAdminController())
    try app.register(collection: LocaleSettingsController())

    app.logger.info("Routes registered")
}
