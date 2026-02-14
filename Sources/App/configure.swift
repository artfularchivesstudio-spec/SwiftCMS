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

// MARK: - Application Configuration

/// ⚙️ **SwiftCMS Application Configuration**
///
/// Configures all subsystems and services for the SwiftCMS application.
/// This function orchestrates the setup of database connections, middleware,
/// authentication, caching, background jobs, and all other core services.
///
/// ## Configuration Sections
/// - 🗄️ **Database**: PostgreSQL (production) or SQLite (development)
/// - ♻️ **Redis**: Cache, sessions, and job queues
/// - 🌿 **Templates**: Leaf templating engine for admin panel
/// - 📊 **Telemetry**: Distributed tracing and metrics
/// - 🎯 **Middleware**: Security, CORS, request ID, and logging middleware
/// - 🗃️ **Migrations**: Database schema migrations and seed data
/// - 🔐 **Authentication**: Auth provider configuration (Auth0, Firebase, etc.)
/// - 📡 **EventBus**: In-process event publishing and subscription
/// - 📦 **Modules**: Plugin system for extensibility
/// - 📬 **Webhooks**: Outgoing webhook delivery system
/// - 🖼️ **Media**: Thumbnail generation and processing
/// - 👷 **Background Jobs**: Redis-backed job queue system
/// - 📝 **Audit Log**: Activity tracking and compliance logging
/// - 📡 **WebSockets**: Real-time communication for content updates
/// - 💾 **Cache Services**: Cache warming and invalidation
///
/// ## Environment Configuration
/// This function reads from environment variables and configures accordingly:
///
/// | Variable | Description | Default |
/// |----------|-------------|---------|
/// | `DATABASE_URL` | PostgreSQL connection string | SQLite (in-memory) |
/// | `REDIS_URL` | Redis connection string | Memory sessions |
/// | `DB_POOL_SIZE` | Database connection pool size | 10 |
/// | `ALLOWED_ORIGINS` | Comma-separated CORS origins | * (all) |
/// | `MULTI_TENANT` | Enable multi-tenancy | false |
///
/// ## Multi-Tenancy Support
/// When `MULTI_TENANT=true`, the application activates:
/// - `TenantContextMiddleware`: Extracts tenant from headers/JWT claims
/// - `TenantScopedQueryModifier`: Automatically scopes queries to tenant
/// - Tenant isolation for all content and user data
///
/// ## Plugin System
/// SwiftCMS uses a modular plugin architecture:
/// - Built-in plugins are registered automatically
/// - Additional plugins discovered from `Modules/` directory
/// - Plugins can extend functionality without modifying core code
///
/// ## Example Configuration
/// ```bash
/// # Production configuration example
/// export DATABASE_URL="postgres://user:pass@localhost:5432/swiftcms"
/// export REDIS_URL="redis://localhost:6379"
/// export MULTI_TENANT=true
/// export ALLOWED_ORIGINS="https://app.example.com,https://admin.example.com"
/// export DB_POOL_SIZE=50
/// ```
///
/// - Parameter app: The Vapor application instance to configure
/// - Throws: Various errors if configuration fails (database connection, etc.)
public func configure(_ app: Application) async throws {
    // 📝 Log configuration start
    app.logger.info("⚙️ Starting application configuration...")

    // MARK: - Database Configuration

    /// 🗄️ **Database Configuration**
    /// Configures the primary database connection using PostgreSQL in production
    /// or SQLite for development/testing environments.
    let poolSize = Int(Environment.get("DB_POOL_SIZE") ?? "10") ?? 10
    if let databaseURL = Environment.get("DATABASE_URL") {
        app.logger.info("📡 Configuring PostgreSQL database connection...")
        var pgConfig = try SQLPostgresConfiguration(url: databaseURL)
        app.databases.use(
            .postgres(configuration: pgConfig, maxConnectionsPerEventLoop: poolSize),
            as: .psql
        )
        app.logger.info("✅ Using PostgreSQL database (pool: \(poolSize) per event loop)")
    } else {
        app.logger.warning("⚠️ No DATABASE_URL set, falling back to SQLite in-memory (development only)")
        app.databases.use(.sqlite(.memory), as: .sqlite)
        app.logger.info("✅ Using SQLite in-memory database")
    }

    // MARK: - Redis Configuration

    /// ♻️ **Redis Configuration**
    /// Sets up Redis for caching, session storage, and background job queues.
    /// Falls back to in-memory storage if Redis is not available.
    if let redisURL = Environment.get("REDIS_URL") {
        app.logger.info("♻️ Configuring Redis connection...")
        try app.redis.configuration = RedisConfiguration(url: redisURL)
        app.logger.info("✅ Redis configured")

        // Sessions backed by Redis
        app.logger.info("🔐 Configuring Redis-backed sessions...")
        app.sessions.use(.redis)

        // Queues backed by Redis
        app.logger.info("👷 Configuring Redis-backed job queue...")
        try app.queues.use(.redis(url: redisURL))
    } else {
        app.logger.warning("⚠️ No REDIS_URL set, using memory sessions")
        app.sessions.use(.memory)
        app.logger.info("🔐 Using in-memory sessions (development only)")
    }

    // MARK: - Template Engine Configuration

    /// 🌿 **Leaf Template Configuration**
    /// Configures the Leaf templating engine for server-side rendering
    /// of the admin panel and other HTML responses.
    app.logger.info("🌿 Configuring Leaf template engine...")
    app.views.use(.leaf)
    app.logger.info("✅ Leaf templates configured")

    // MARK: - Telemetry Configuration

    /// 📊 **Telemetry & Observability Configuration**
    /// Sets up distributed tracing and metrics collection for monitoring
    /// application performance and debugging.
    app.logger.info("📊 Configuring telemetry and observability...")
    let telemetryConfig = TelemetryConfiguration.fromEnvironment()
    let telemetryManager = TelemetryManager(configuration: telemetryConfig, logger: app.logger)
    app.cms.telemetry = telemetryManager
    app.logger.info("✅ Telemetry configured: \(telemetryConfig.exporter.rawValue) exporter")

    // MARK: - Middleware Configuration

    /// 🎯 **Middleware Stack Configuration**
    /// Configures the middleware pipeline in execution order.
    /// Each middleware processes requests/responses in sequence.
    app.logger.info("🎯 Configuring middleware stack...")

    // Error handling (first to catch all errors)
    app.logger.debug("Adding ErrorMiddleware...")
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // Session management
    app.logger.debug("Adding SessionMiddleware...")
    app.middleware.use(app.sessions.middleware)

    // Static file serving
    app.logger.debug("Adding FileMiddleware for public directory...")
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // CORS (Cross-Origin Resource Sharing)
    app.logger.info("🌐 Configuring CORS middleware...")
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
    app.logger.info("✅ CORS configured for origins: \(allowedOrigins.joined(separator: ", "))")

    // Security headers
    app.logger.debug("Adding SecurityHeadersMiddleware...")
    app.middleware.use(SecurityHeadersMiddleware())

    // Request ID and structured logging
    app.logger.debug("Adding RequestIdMiddleware...")
    app.middleware.use(RequestIdMiddleware())
    app.logger.debug("Adding StructuredLoggingMiddleware...")
    app.middleware.use(StructuredLoggingMiddleware())

    // Distributed tracing
    if let telemetry = app.cms.telemetry {
        app.logger.debug("Adding TracingMiddleware...")
        app.middleware.use(TracingMiddleware(telemetry: telemetry))
        app.logger.info("✅ Distributed tracing enabled")
    }

    // Multi-tenancy (active only when MULTI_TENANT=true)
    app.logger.info("🔍 Checking multi-tenancy configuration...")
    if Environment.get("MULTI_TENANT")?.lowercased() == "true" {
        app.logger.info("🏢 Multi-tenancy mode: ENABLED")
        app.logger.debug("Adding TenantContextMiddleware...")
        app.middleware.use(TenantContextMiddleware())
        app.logger.debug("Adding TenantScopedQueryModifier...")
        app.middleware.use(TenantScopedQueryModifier())
    } else {
        app.logger.info("🏢 Multi-tenancy mode: DISABLED (single-tenant)")
    }

    app.logger.info("✅ Middleware stack configured")

    // MARK: - Database Migrations

    /// 🗃️ **Database Migration Registration**
    /// Registers all database schema migrations and seed data.
    /// Migrations run in order and track their execution state.
    app.logger.info("🗃️ Registering database migrations...")

    // Core CMS tables
    app.logger.debug("Adding CreateRoles migration...")
    app.migrations.add(CreateRoles())
    app.logger.debug("Adding CreateUsers migration...")
    app.migrations.add(CreateUsers())
    app.logger.debug("Adding CreatePermissions migration...")
    app.migrations.add(CreatePermissions())
    app.logger.debug("Adding CreateFieldPermissions migration...")
    app.migrations.add(CreateFieldPermissions())
    app.logger.debug("Adding CreateApiKeys migration...")
    app.migrations.add(CreateApiKeys())
    app.logger.debug("Adding CreateMediaFiles migration...")
    app.migrations.add(CreateMediaFiles())
    app.logger.debug("Adding CreateWebhooks migration...")
    app.migrations.add(CreateWebhooks())
    app.logger.debug("Adding CreateWebhookDeliveries migration...")
    app.migrations.add(CreateWebhookDeliveries())
    app.logger.debug("Adding CreateDeadLetterEntries migration...")
    app.migrations.add(CreateDeadLetterEntries())
    app.logger.debug("Adding CreateAuditLog migration...")
    app.migrations.add(CreateAuditLog())
    app.logger.debug("Adding CreateContentTypeDefinitions migration...")
    app.migrations.add(CreateContentTypeDefinitions())
    app.logger.debug("Adding CreateContentEntries migration...")
    app.migrations.add(CreateContentEntries())
    app.logger.debug("Adding CreateContentVersions migration...")
    app.migrations.add(CreateContentVersions())
    app.logger.debug("Adding CreateSavedFilter migration...")
    app.migrations.add(CreateSavedFilter())
    app.logger.debug("Adding SeedDefaultRoles migration...")
    app.migrations.add(SeedDefaultRoles())

    app.logger.info("✅ Registered \(app.migrations.storage.count) migrations")

    // Auto-migrate in development
    if app.environment == .development || app.environment == .testing {
        app.logger.info("🔄 Auto-migrating database (development mode)...")
        try await app.autoMigrate()
        app.logger.info("✅ Database migration complete")
    }

    // MARK: - Authentication Configuration

    /// 🔐 **Authentication Provider Configuration**
    /// Configures the authentication system with the selected provider
    /// (Auth0, Firebase Auth, or local JWT).
    app.logger.info("🔐 Configuring authentication provider...")
    let authProvider = AuthProviderFactory.create(from: app.environment)
    try authProvider.configure(app: app)
    app.storage[AuthProviderKey.self] = authProvider
    app.logger.info("✅ Auth provider configured: \(authProvider.name)")

    // MARK: - EventBus Configuration

    /// 📡 **EventBus Configuration**
    /// Sets up the in-process event bus for publishing and subscribing to events
    /// across the application.
    app.logger.info("📡 Configuring EventBus for inter-service communication...")
    app.eventBus = InProcessEventBus()
    app.logger.info("✅ EventBus configured")

    // MARK: - Module System Configuration

    /// 📦 **Module/Plugin System Configuration**
    /// Configures the plugin registry and module manager for extensibility.
    /// Discovers and registers plugins from the Modules/ directory.
    app.logger.info("📦 Configuring module/plugin system...")
    let pluginRegistry = PluginRegistry()
    let moduleManager = ModuleManager(pluginRegistry: pluginRegistry)
    app.cms.modules = moduleManager

    // Register built-in plugins
    app.logger.debug("Registering built-in plugins...")
    PluginLoader.registerPlugins(registry: pluginRegistry)

    // Discover and register additional plugins
    app.logger.info("🔍 Discovering plugins in Modules/ directory...")
    moduleManager.discoverAndRegisterPlugins(modulesPath: "Modules", logger: app.logger)
    app.logger.info("✅ Plugin discovery complete")

    // Register core modules
    app.logger.debug("Registering core SearchModule...")
    moduleManager.register(SearchModule())

    // Boot all modules
    app.logger.info("🚀 Booting all registered modules...")
    try moduleManager.bootAll(app: app)
    app.logger.info("✅ All modules booted successfully")

    // MARK: - Webhook Configuration

    /// 📬 **Webhook Dispatcher Configuration**
    /// Configures the webhook delivery system for sending HTTP callbacks
    /// when content changes occur.
    app.logger.info("📬 Configuring webhook dispatcher...")
    let webhookDispatcher = WebhookDispatcher()
    webhookDispatcher.configure(app: app)
    app.logger.info("✅ Webhook dispatcher configured")

    // MARK: - Media Configuration

    /// 🖼️ **Media Processing Configuration**
    /// Sets up automatic thumbnail generation for uploaded media files.
    app.logger.info("🖼️ Configuring media thumbnail generation...")
    MediaThumbnailSubscriber.configure(app: app)
    app.logger.info("✅ Media thumbnail subscriber configured")

    // MARK: - Background Jobs Configuration

    /// 👷 **Background Job Configuration**
    /// Registers and schedules background jobs when Redis is available.
    /// Jobs handle webhook deliveries, scheduled publishing, and thumbnail generation.
    if Environment.get("REDIS_URL") != nil {
        app.logger.info("👷 Configuring background job queue...")

        // Register webhook delivery job
        app.logger.debug("Registering WebhookDeliveryJob...")
        app.queues.add(WebhookDeliveryJob())

        // Schedule jobs
        app.logger.debug("Scheduling ScheduledPublishJob (runs minutely)...")
        app.queues.schedule(ScheduledPublishJob())
            .minutely()

        // Register thumbnail job
        app.logger.debug("Registering ThumbnailJob...")
        app.queues.add(ThumbnailJob())

        app.logger.info("✅ Background jobs configured and scheduled")
    } else {
        app.logger.warning("⚠️ No REDIS_URL set, background jobs disabled (development only)")
    }

    // MARK: - Audit Log Configuration

    /// 📝 **Audit Log Configuration**
    /// Configures activity tracking and compliance logging for all content operations.
    app.logger.info("📝 Configuring audit logging...")
    AuditLogService.configure(app: app)
    app.logger.info("✅ Audit log service configured")

    // MARK: - WebSocket Configuration

    /// 📡 **WebSocket Server Configuration**
    /// Sets up real-time communication for content updates and live previews.
    app.logger.info("📡 Configuring WebSocket server...")
    WebSocketServer.configure(app: app)
    app.logger.info("✅ WebSocket server configured")

    // MARK: - Cache Services Configuration

    /// 💾 **Cache Services Configuration**
    /// Configures cache warming and invalidation services for optimal performance.
    app.logger.info("💾 Configuring cache services...")
    CacheInvalidationService.configure(app: app)
    CacheWarmingService.configure(app: app)
    app.logger.info("✅ Cache services configured")

    // MARK: - Routes Registration

    /// 🛣️ **Route Registration**
    /// Registers all application routes and HTTP endpoint handlers.
    app.logger.info("🛣️ Registering application routes...")
    try routes(app)
    app.logger.info("✅ Routes registered")

    // MARK: - Graceful Shutdown Handler

    /// 🧹 **Graceful Shutdown Configuration**
    /// Ensures clean shutdown of all services and resources when the application terminates.
    app.logger.debug("Configuring graceful shutdown handler...")
    app.lifecycle.use(GracefulShutdownHandler())

    // MARK: - Configuration Complete

    /// ✅ **Configuration Complete**
    app.logger.info("✅ SwiftCMS configuration complete!")
    if Environment.get("MULTI_TENANT")?.lowercased() == "true" {
        app.logger.info("🏢 Multi-tenancy mode: ENABLED")
    } else {
        app.logger.info("🏢 Multi-tenancy mode: DISABLED (single-tenant)")
    }
}

// MARK: - Storage Keys

/// 🔑 **Auth Provider Storage Key**
/// Storage key for accessing the configured authentication provider from the application storage.
struct AuthProviderKey: StorageKey {
    typealias Value = AuthProvider
}

// MARK: - Security Headers Middleware

/// 🛡️ **Security Headers Middleware**
///
/// Adds security headers to all HTTP responses to protect against common web vulnerabilities:
/// - `X-Content-Type-Options: nosniff`: Prevents MIME type sniffing
/// - `X-Frame-Options`: Protects against clickjacking (SAMEORIGIN for admin, DENY for API)
/// - `Strict-Transport-Security`: Enforces HTTPS connections
/// - `Referrer-Policy`: Controls referrer information sent with requests
///
/// This middleware is automatically added to all routes during application configuration.
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

/// 🆔 **Request ID Middleware**
///
/// Assigns a unique identifier to each incoming request and adds it to:
/// - Request logger metadata for correlation across logs
/// - Response headers as `X-Request-Id` for client tracing
///
/// If a request already contains an `X-Request-Id` header, that ID is preserved.
/// This enables distributed tracing across microservices.
struct RequestIdMiddleware: AsyncMiddleware, Sendable {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let requestId = request.headers.first(name: "X-Request-Id") ?? UUID().uuidString
        request.logger[metadataKey: "request-id"] = "\(requestId)"
        let response = try await next.respond(to: request)
        response.headers.add(name: "X-Request-Id", value: requestId)
        return response
    }
}
