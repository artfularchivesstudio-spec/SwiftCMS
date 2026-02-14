import Vapor
import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Leaf
import Redis
import QueuesRedisDriver
import CMSCore
import CMSSchema
import CMSAuth
import CMSEvents
import CMSJobs
import CMSSearch
import CMSMedia

/// Configure the Vapor application.
public func configure(_ app: Application) async throws {
    // ─── Load Environment ─────────────────────────────────────────
    // .env is loaded automatically by Vapor if present

    // ─── Database ─────────────────────────────────────────────────
    let poolSize = Int(Environment.get("DB_POOL_SIZE") ?? "10") ?? 10
    if let databaseURL = Environment.get("DATABASE_URL") {
        var pgConfig = try SQLPostgresConfiguration(url: databaseURL)
        app.databases.use(
            .postgres(configuration: pgConfig, maxConnectionsPerEventLoop: poolSize),
            as: .psql
        )
        app.logger.info("Using PostgreSQL database (pool: \(poolSize) per event loop)")
    } else {
        app.databases.use(.sqlite(.memory), as: .sqlite)
        app.logger.warning("No DATABASE_URL set, using SQLite in-memory (development only)")
    }

    // ─── Redis ────────────────────────────────────────────────────
    if let redisURL = Environment.get("REDIS_URL") {
        app.redis.configuration = try RedisConfiguration(url: redisURL)
        app.logger.info("Redis configured")

        // Sessions backed by Redis
        app.sessions.use(.redis)

        // Queues backed by Redis
        try app.queues.use(.redis(url: redisURL))
    } else {
        app.sessions.use(.memory)
        app.logger.warning("No REDIS_URL set, sessions in memory (development only)")
    }

    // ─── Leaf Templates ───────────────────────────────────────────
    app.views.use(.leaf)

    // ─── Middleware ────────────────────────────────────────────────
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(app.sessions.middleware)
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // CORS
    let allowedOrigins = (Environment.get("ALLOWED_ORIGINS") ?? "*")
        .split(separator: ",").map(String.init)
    let corsConfig = CORSMiddleware.Configuration(
        allowedOrigin: allowedOrigins.count == 1 && allowedOrigins[0] == "*"
            ? .all : .any(allowedOrigins),
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
        allowedHeaders: [.authorization, .contentType, .accept,
                         .init("X-API-Key"), .init("X-Request-Id"),
                         .init("X-Tenant-ID")]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfig))

    // Security headers
    app.middleware.use(SecurityHeadersMiddleware())

    // Request ID + structured logging
    app.middleware.use(RequestIdMiddleware())
    app.middleware.use(StructuredLoggingMiddleware())

    // Multi-tenancy (active only when MULTI_TENANT=true)
    app.middleware.use(TenantContextMiddleware())
    app.middleware.use(TenantScopedQueryModifier())

    // ─── Register Migrations ──────────────────────────────────────
    app.migrations.add(CreateRoles())
    app.migrations.add(CreateUsers())
    app.migrations.add(CreatePermissions())
    app.migrations.add(CreateFieldPermissions())
    app.migrations.add(CreateApiKeys())
    app.migrations.add(CreateMediaFiles())
    app.migrations.add(CreateWebhooks())
    app.migrations.add(CreateWebhookDeliveries())
    app.migrations.add(CreateDeadLetterEntries())
    app.migrations.add(CreateAuditLog())
    app.migrations.add(CreateContentTypeDefinitions())
    app.migrations.add(CreateContentEntries())
    app.migrations.add(CreateContentVersions())
    app.migrations.add(CreateSavedFilter())
    app.migrations.add(SeedDefaultRoles())

    // Auto-migrate in development
    if app.environment == .development || app.environment == .testing {
        try await app.autoMigrate()
    }

    // ─── Auth Provider ────────────────────────────────────────────
    let authProvider = AuthProviderFactory.create(from: app.environment)
    try authProvider.configure(app: app)
    app.storage[AuthProviderKey.self] = authProvider
    app.logger.info("Auth provider: \(authProvider.name)")

    // ─── EventBus ─────────────────────────────────────────────────
    app.eventBus = InProcessEventBus()

    // ─── Module System ────────────────────────────────────────────
    let pluginRegistry = PluginRegistry()
    let moduleManager = ModuleManager(pluginRegistry: pluginRegistry)
    app.cms.modules = moduleManager

    // Register built-in plugins
    PluginLoader.registerPlugins(registry: pluginRegistry)

    // Discover and register additional plugins
    moduleManager.discoverAndRegisterPlugins(modulesPath: "Modules", logger: app.logger)

    // Register core modules
    moduleManager.register(SearchModule())

    // Boot all modules
    try moduleManager.bootAll(app: app)

    // ─── Webhook Dispatcher ───────────────────────────────────────
    WebhookDispatcher.configure(app: app)

    // ─── Background Jobs ──────────────────────────────────────────
    if Environment.get("REDIS_URL") != nil {
        app.queues.schedule(ScheduledPublishJob())
            .minutely()
    }

    // ─── Audit Log ───────────────────────────────────────────────
    AuditLogService.configure(app: app)

    // ─── WebSocket Server ─────────────────────────────────────────
    WebSocketServer.configure(app: app)

    // ─── Plugin Discovery ─────────────────────────────────────────
    moduleManager.discoverAndRegisterPlugins(modulesPath: "Modules", logger: app.logger)

    // ─── Routes ───────────────────────────────────────────────────
    try routes(app)

    // ─── Graceful Shutdown ────────────────────────────────────────
    app.lifecycle.use(GracefulShutdownHandler())

    app.logger.info("SwiftCMS configured successfully")
    if Environment.get("MULTI_TENANT")?.lowercased() == "true" {
        app.logger.info("Multi-tenancy mode: ENABLED")
    } else {
        app.logger.info("Multi-tenancy mode: disabled (single-tenant)")
    }
}

// MARK: - Storage Keys

struct AuthProviderKey: StorageKey {
    typealias Value = AuthProvider
}

// MARK: - Security Headers Middleware

struct SecurityHeadersMiddleware: AsyncMiddleware, Sendable {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        response.headers.add(name: "X-Content-Type-Options", value: "nosniff")
        response.headers.add(name: "X-Frame-Options", value: request.url.path.hasPrefix("/admin") ? "SAMEORIGIN" : "DENY")
        response.headers.add(name: "Strict-Transport-Security", value: "max-age=31536000; includeSubDomains")
        response.headers.add(name: "Referrer-Policy", value: "strict-origin-when-cross-origin")
        return response
    }
}

// MARK: - Request ID Middleware

struct RequestIdMiddleware: AsyncMiddleware, Sendable {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let requestId = request.headers.first(name: "X-Request-Id") ?? UUID().uuidString
        request.logger[metadataKey: "request-id"] = "\(requestId)"
        let response = try await next.respond(to: request)
        response.headers.add(name: "X-Request-Id", value: requestId)
        return response
    }
}
