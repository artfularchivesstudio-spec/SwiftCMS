import Vapor
import Fluent
import CMSCore
import CMSApi
import CMSAdmin
import CMSAuth
import CMSMedia
import CMSSchema
import CMSObjects
import CMSOpenAPI

// MARK: - Route Registration

/// 🛣️ **SwiftCMS Route Registration**
///
/// Registers all HTTP routes and endpoint handlers for the SwiftCMS application.
/// Routes are organized by functionality and API version.
///
/// ## Route Categories
///
/// ### 🩺 Health Checks
/// - `/healthz` - Basic health check (returns 200 OK)
/// - `/ready` - Readiness check (verifies database connectivity)
/// - `/startup` - Startup probe (used by Kubernetes)
/// - `/health/telemetry` - Telemetry system health status
///
/// ### 🔌 API v1 (`/api/v1`)
/// All API endpoints are prefixed with `/api/v1` and include:
/// - Rate limiting to prevent abuse
/// - Caching for improved performance
/// - Optional authentication (allows public reads)
///
/// **Content Management:**
/// - `GET/POST/PUT/DELETE /api/v1/content-types` - Content type CRUD
/// - `GET/POST/PUT/DELETE /api/v1/:contentType` - Dynamic content CRUD
/// - `GET/POST/PUT/DELETE /api/v1/media` - Media file management
/// - `GET/POST /api/v1/search` - Full-text search
/// - `GET/POST/PUT/DELETE /api/v1/versions` - Content versioning
/// - `GET/POST /api/v1/preview` - Content preview
///
/// **System:**
/// - `GET/POST/PUT/DELETE /api/v1/saved-filters` - Saved filter presets
/// - `POST /api/v1/bulk` - Bulk content operations
/// - `GET/POST /api/v1/import-export` - Content type import/export
///
/// **Authentication:**
/// - `POST /api/v1/auth/login` - User authentication
/// - `POST /api/v1/auth/logout` - User logout
/// - `POST /api/v1/auth/refresh` - Token refresh
///
/// ### 🎛️ Admin Panel (`/admin`)
/// Server-side rendered HTML pages for content administration:
/// - `GET /admin` - Dashboard
/// - `GET /admin/content/:type` - Content listing
/// - `GET /admin/content/:type/:id` - Content editor
/// - `GET /admin/roles` - Role management
/// - `GET /admin/versions` - Version history
/// - `GET /admin/webhooks/dlqs` - Dead letter queue
/// - `GET /admin/search` - Admin search interface
/// - `GET /admin/locale-settings` - Localization settings
///
/// ### 📡 GraphQL API (`/graphql`)
/// GraphQL endpoint for advanced queries and mutations.
///
/// ### 📖 OpenAPI Documentation (`/docs`)
/// Interactive API documentation generated from OpenAPI specification.
///
/// ### 📦 SDK Generation (`/sdk`)
/// Endpoints for generating typed client SDKs:
/// - `POST /sdk/generate` - Generate Swift/TypeScript SDK
///
/// ### 🔌 WebSocket (`/ws`)
/// Real-time WebSocket endpoint for live content updates and collaboration.
///
/// ## Middleware Stack
/// Routes are protected by a comprehensive middleware stack:
/// 1. **Error handling** - Catches and formats all errors
/// 2. **Sessions** - Manages user sessions
/// 3. **Static files** - Serves static assets
/// 4. **CORS** - Cross-origin request handling
/// 5. **Security headers** - XSS, clickjacking protection
/// 6. **Request ID** - Request tracing
/// 7. **Structured logging** - Enhanced log formatting
/// 8. **Distributed tracing** - Performance monitoring
/// 9. **Multi-tenancy** - Tenant isolation (when enabled)
/// 10. **Authentication** - User authentication (optional for reads)
/// 11. **Rate limiting** - API abuse prevention
/// 12. **Caching** - Response caching
///
/// ## Example Usage
///
/// ```bash
/// # Health check
/// curl http://localhost:8080/healthz
///
/// # Create a content type
/// curl -X POST http://localhost:8080/api/v1/content-types \
///   -H "Content-Type: application/json" \
///   -H "Authorization: Bearer YOUR_TOKEN" \
///   -d '{"name": "Blog Post", "slug": "blog-post", "kind": "collection"}'
///
/// # Create content entry
/// curl -X POST http://localhost:8080/api/v1/blog-post \
///   -H "Content-Type: application/json" \
///   -d '{"title": "Hello World", "content": "My first post"}'
///
/// # Search content
/// curl "http://localhost:8080/api/v1/search?q=hello"
///
/// # Admin panel
/// open http://localhost:8080/admin
/// ```
///
/// - Parameter app: The Vapor application instance to configure routes on
/// - Throws: Various errors if route registration fails
public func routes(_ app: Application) throws {
    // 📝 Log route registration start
    app.logger.info("🛣️ Starting route registration...")

    // MARK: - Health Check Routes

    /// 🩺 **Basic Health Check**
    /// Returns 200 OK if the application is running.
    /// Used by load balancers and monitoring tools.
    app.get("healthz") { req -> HTTPStatus in
        req.logger.debug("Health check requested")
        return .ok
    }

    /// 🩺 **Readiness Check**
    /// Returns 200 OK if the application is ready to serve traffic.
    /// Verifies database connectivity before returning success.
    app.get("ready") { req async throws -> Response in
        req.logger.debug("Readiness check requested")

        // Check database connectivity
        do {
            _ = try await ContentTypeDefinition.query(on: req.db).all()
            req.logger.debug("Database connectivity verified")
        } catch {
            req.logger.error("Database unavailable: \(error)")
            let response = Response(status: .serviceUnavailable)
            try response.content.encode(["status": "database unavailable"])
            return response
        }

        let response = Response(status: .ok)
        try response.content.encode(["status": "ready"])
        req.logger.debug("Application is ready")
        return response
    }

    /// 🩺 **Startup Probe**
    /// Returns 200 OK when the application has started.
    /// Used by Kubernetes startup probes.
    app.get("startup") { _ -> HTTPStatus in
        .ok
    }

    /// 📊 **Telemetry Health Check**
    /// Returns health status of the telemetry/tracing system.
    app.get("health", "telemetry") { req -> TelemetryHealthCheckResponse in
        req.logger.debug("Telemetry health check requested")
        guard let telemetry = req.application.cms.telemetry else {
            req.logger.debug("Telemetry not configured")
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
        let response = await telemetry.healthCheckResponse()
        req.logger.debug("Telemetry health: \(response.healthy ? "healthy" : "unhealthy")")
        return response
    }

    // MARK: - API v1 Routes

    /// 🔌 **API v1 Route Group**
    /// Main API endpoint group with rate limiting and caching middleware.
    app.logger.info("Configuring API v1 routes...")
    let api = app.grouped("api", "v1")
        .grouped(RateLimitMiddleware())
        .grouped(CacheMiddleware())

    app.logger.debug("API v1 group created with RateLimitMiddleware and CacheMiddleware")

    // MARK: Cache Management

    /// 💾 **Cache Metrics Controller**
    /// Provides endpoints for monitoring and managing the application cache.
    try app.register(collection: CacheMetricsController())
    app.logger.debug("CacheMetricsController registered")

    // MARK: Authentication Setup

    /// 🔐 **Authentication Setup**
    /// Applies authentication middleware to protected routes.
    /// Authentication is optional for public read operations.
    let authProvider = app.storage[AuthProviderKey.self]
    var protectedApi = api

    if let provider = authProvider {
        app.logger.info("Authentication provider available: \(provider.name)")
        protectedApi = api.grouped(provider.middleware())
        app.logger.debug("Protected API routes configured with authentication")
    } else {
        app.logger.warning("No authentication provider configured - API routes are public")
    }

    // MARK: Content API Routes

    /// 📝 **Content Type Management**
    /// CRUD operations for content type definitions (schemas).
    try protectedApi.register(collection: ContentTypeController())
    app.logger.info("✅ ContentTypeController registered")

    /// 📝 **Dynamic Content CRUD**
    /// CRUD operations for content entries of any type.
    try protectedApi.register(collection: DynamicContentController())
    app.logger.info("✅ DynamicContentController registered")

    /// 🖼️ **Media Endpoints**
    /// File upload, download, and management for media assets.
    try protectedApi.register(collection: MediaController())
    app.logger.info("✅ MediaController registered")

    /// 🔍 **Search API**
    /// Full-text search across all content types.
    try protectedApi.register(collection: SearchController())
    app.logger.info("✅ SearchController registered")

    /// 🔄 **Version Management**
    /// Content versioning and history tracking.
    try protectedApi.register(collection: VersionController())
    app.logger.info("✅ VersionController registered")

    /// 👁️ **Preview Endpoints**
    /// Preview draft content before publishing.
    try protectedApi.register(collection: PreviewController())
    app.logger.info("✅ PreviewController registered")

    // MARK: System Routes

    /// 🔖 **Saved Filters**
    /// Save and reuse common filter presets.
    try app.register(collection: SavedFilterController())
    app.logger.info("✅ SavedFilterController registered")

    /// 📦 **Bulk Operations**
    /// Perform operations on multiple content entries at once.
    try app.register(collection: BulkOperationsController())
    app.logger.info("✅ BulkOperationsController registered")

    /// 🔄 **Import/Export**
    /// Import and export content type definitions.
    try app.register(collection: ContentTypeImportExportController())
    app.logger.info("✅ ContentTypeImportExportController registered")

    // MARK: Authentication Routes

    /// 🔐 **Public Authentication Endpoints**
    /// Login, logout, and token refresh (publicly accessible).
    try api.register(collection: AuthController())
    app.logger.info("✅ AuthController registered")

    // MARK: Admin Panel Routes

    /// 🎛️ **Admin Panel Routes**
    /// Server-side rendered HTML pages for content administration.
    app.logger.info("Configuring admin panel routes...")
    try app.register(collection: AdminController())
    try app.register(collection: RolesController())
    try app.register(collection: VersionAdminController())
    try app.register(collection: LocaleSettingsController())
    try app.register(collection: WebhookDLQController())
    try app.register(collection: AdminSearchController())
    app.logger.info("✅ Admin panel controllers registered")

    // MARK: GraphQL API

    /// 📡 **GraphQL API**
    /// Advanced GraphQL endpoint for flexible queries and mutations.
    app.logger.info("Configuring GraphQL API...")
    let eventBus = app.eventBus
    try app.register(collection: GraphQLController(app: app))
    app.logger.info("✅ GraphQL API configured")

    // MARK: OpenAPI Documentation

    /// 📖 **OpenAPI Documentation**
    /// Interactive API documentation generated from OpenAPI specification.
    app.logger.info("Configuring OpenAPI documentation...")
    try app.register(collection: OpenAPIController())
    app.logger.info("✅ OpenAPI documentation configured")

    // MARK: SDK Generation

    /// 📦 **SDK Generation**
    /// Endpoints for generating typed client SDKs.
    app.logger.info("Configuring SDK generation...")
    try app.register(collection: SDKController())
    app.logger.info("✅ SDK generation configured")

    // MARK: Route Registration Complete

    /// ✅ **Route Registration Complete**
    app.logger.info("✅ All routes registered successfully")
    app.logger.info("📊 Total route collections: \(app.routes.all.count)")
}
