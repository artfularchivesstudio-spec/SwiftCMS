import Vapor
import Fluent
import CMSCore
import CMSApi
import CMSAdmin
import CMSAuth
import CMSMedia
import CMSSchema
import CMSObjects

/// Register all application routes.
public func routes(_ app: Application) throws {
    // ─── Health Checks ────────────────────────────────────────────
    app.get("healthz") { _ -> HTTPStatus in
        .ok
    }

    app.get("ready") { req async throws -> Response in
        // Check database
        do {
            _ = try await ContentTypeDefinition.query(on: req.db).all()
        } catch {
            let res = Response(status: .serviceUnavailable)
            try res.content.encode(["status": "database unavailable"])
            return res
        }
        let res = Response(status: .ok)
        try res.content.encode(["status": "ready"])
        return res
    }

    app.get("startup") { _ -> HTTPStatus in
        .ok
    }

    // Telemetry health check
    app.get("health", "telemetry") { req -> TelemetryHealthCheckResponse in
        guard let telemetry = req.cms.telemetry else {
            return TelemetryHealthCheckResponse(
                exporter: "none",
                healthy: true,
                activeSpans: 0,
                pendingSpans: 0,
                pendingMetrics: 0,
                samplingRate: 0.0,
                metricsEnabled: false
            )
        }
        return await telemetry.healthCheckResponse()
    }

    // ─── API v1 ───────────────────────────────────────────────────
    let api = app.grouped("api", "v1")
        .grouped(RateLimitMiddleware())
        .grouped(ResponseCacheMiddleware(ttl: 300))

    // Auth middleware (optional - allows unauthenticated for public reads)
    let authProvider = app.storage[AuthProviderKey.self]
    var protectedApi = api
    if let provider = authProvider {
        protectedApi = api.grouped(provider.middleware())
    }

    // Content type management
    try protectedApi.register(collection: ContentTypeController())

    // Dynamic content CRUD
    try protectedApi.register(collection: DynamicContentController())

    // Media endpoints
    try protectedApi.register(collection: MediaController())

    // Search
    try protectedApi.register(collection: SearchController())

    // Version endpoints
    try protectedApi.register(collection: VersionController())

    // Preview endpoints
    try protectedApi.register(collection: PreviewController())

    // Saved filters
    try app.register(collection: SavedFilterController())

    // Bulk operations
    try app.register(collection: BulkOperationsController())

    // Content type import/export
    try app.register(collection: ContentTypeImportExportController())

    // Auth endpoints
    api.post("auth", "login") { req async throws -> TokenResponseDTO in
        let dto = try req.content.decode(LoginDTO.self)

        guard let user = try await User.query(on: req.db)
            .filter(\User.$email == dto.email)
            .with(\User.$role)
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

    // ─── GraphQL API ──────────────────────────────────────────────
    try app.register(collection: GraphQLController())

    app.logger.info("Routes registered")
}
