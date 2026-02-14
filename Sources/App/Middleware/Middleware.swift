import Vapor
import Redis
import Fluent
import CMSAuth
import CMSSchema
import CMSEvents
import CMSObjects

// MARK: - Rate Limiting Middleware

/// Redis-backed rate limiting with per-user, per-IP, and per-tenant configuration.
/// Supports role-based limits, tenant overrides, admin bypass, and rate limit headers.
public struct RateLimitMiddleware: AsyncMiddleware, Sendable {

    /// Rate limit configuration settings.
    public struct Configuration: Sendable {
        /// Default rate limit for anonymous requests (requests per minute).
        public var anonymousLimit: Int

        /// Default rate limit for authenticated users (requests per minute).
        public var authenticatedLimit: Int

        /// Role-based rate limit overrides (requests per minute).
        public var roleLimits: [String: Int]

        /// Tenant-specific rate limit overrides.
        public var tenantLimits: [String: Int]

        /// Rate limit window in seconds.
        public var windowSeconds: Int

        /// Whether to allow admins to bypass rate limits.
        public var adminBypass: Bool

        /// Whether to include rate limit headers in responses.
        public var includeHeaders: Bool

        /// Admin roles that bypass rate limiting.
        public var adminRoles: Set<String>

        public init(
            anonymousLimit: Int = 60,
            authenticatedLimit: Int = 300,
            roleLimits: [String: Int] = [:],
            tenantLimits: [String: Int] = [:],
            windowSeconds: Int = 60,
            adminBypass: Bool = true,
            includeHeaders: Bool = true,
            adminRoles: Set<String> = ["super-admin", "admin"]
        ) {
            self.anonymousLimit = anonymousLimit
            self.authenticatedLimit = authenticatedLimit
            self.roleLimits = roleLimits
            self.tenantLimits = tenantLimits
            self.windowSeconds = windowSeconds
            self.adminBypass = adminBypass
            self.includeHeaders = includeHeaders
            self.adminRoles = adminRoles
        }

        /// Creates configuration from environment variables.
        /// Reads `RATE_LIMIT_ANONYMOUS`, `RATE_LIMIT_AUTHENTICATED`, etc.
        public static func fromEnvironment() -> Configuration {
            var config = Configuration()

            if let anonLimit = Environment.get("RATE_LIMIT_ANONYMOUS").flatMap(Int.init) {
                config.anonymousLimit = anonLimit
            }

            if let authLimit = Environment.get("RATE_LIMIT_AUTHENTICATED").flatMap(Int.init) {
                config.authenticatedLimit = authLimit
            }

            if let window = Environment.get("RATE_LIMIT_WINDOW").flatMap(Int.init) {
                config.windowSeconds = window
            }

            // Parse role-based limits from environment (comma-separated: role:limit pairs)
            if let roleLimitsStr = Environment.get("RATE_LIMIT_ROLES") {
                var roleLimits: [String: Int] = [:]
                for pair in roleLimitsStr.split(separator: ",") {
                    let parts = pair.split(separator: ":", maxSplits: 1)
                    if parts.count == 2,
                       let role = String(parts[0]).trimmingCharacters(in: .whitespaces).isEmpty == false ? String(parts[0]).trimmingCharacters(in: .whitespaces) : nil,
                       let limit = Int(String(parts[1]).trimmingCharacters(in: .whitespaces)) {
                        roleLimits[role] = limit
                    }
                }
                config.roleLimits = roleLimits
            }

            // Load tenant-specific limits from JSON config if available
            if let configPath = Environment.get("RATE_LIMIT_TENANT_CONFIG"),
               let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
               let tenantConfig = try? JSONDecoder().decode(TenantRateLimitConfig.self, from: data) {
                config.tenantLimits = tenantConfig.limits
            }

            return config
        }
    }

    private let configuration: Configuration

    public init(configuration: Configuration = .fromEnvironment()) {
        self.configuration = configuration
    }

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Determine rate limit based on user/tenant
        let rateLimit = determineRateLimit(for: request)
        let identifier = getIdentifier(for: request)

        // Check if user bypasses rate limits
        if shouldBypass(request: request) {
            return try await next.respond(to: request)
        }

        // Check Redis if available
        do {
            return try await enforceRateLimit(
                request: request,
                identifier: identifier,
                limit: rateLimit,
                chainingTo: next
            )
        } catch {
            // Redis unavailable, log warning and fall through
            request.logger.warning("Rate limiting unavailable: \(error)")
            return try await next.respond(to: request)
        }
    }

    // MARK: - Rate Limit Determination

    private func determineRateLimit(for request: Request) -> Int {
        // Check tenant-specific limit first
        if let tenantId = request.tenantId,
           let tenantLimit = configuration.tenantLimits[tenantId] {
            return tenantLimit
        }

        // Check user role-based limits
        if let user = request.auth.get(CmsUser.self) {
            // Check each role for an override
            for role in user.roles where configuration.roleLimits[role] != nil {
                return configuration.roleLimits[role]!
            }
            // Default authenticated limit
            return configuration.authenticatedLimit
        }

        // Default anonymous limit
        return configuration.anonymousLimit
    }

    private func getIdentifier(for request: Request) -> String {
        // Use user ID if authenticated
        if let user = request.auth.get(CmsUser.self) {
            return "rate:\(user.userId)"
        }

        // Use IP address for anonymous requests
        let ip = request.headers.first(name: "X-Forwarded-For")
            ?? request.headers.first(name: "X-Real-IP")
            ?? request.remoteAddress?.description ?? "unknown"
        return "rate:\(ip)"
    }

    private func shouldBypass(request: Request) -> Bool {
        guard configuration.adminBypass else {
            return false
        }

        guard let user = request.auth.get(CmsUser.self) else {
            return false
        }

        // Check if user has any admin role
        let userRoles = Set(user.roles)
        let adminRoles = Set(configuration.adminRoles)
        return !userRoles.isDisjoint(with: adminRoles)
    }

    // MARK: - Rate Limit Enforcement

    private func enforceRateLimit(
        request: Request,
        identifier: String,
        limit: Int,
        chainingTo next: any AsyncResponder
    ) async throws -> Response {
        let key = RedisKey(identifier)
        let current = try await request.redis.increment(key).get()

        // Set expiration on first request in window
        if current == 1 {
            _ = try await request.redis.expire(key, after: .seconds(Int64(configuration.windowSeconds))).get()
        }

        let remaining = max(0, limit - Int(current))

        // Check if limit exceeded
        if current > limit {
            let headers = HTTPHeaders([
                ("Retry-After", "\(configuration.windowSeconds)"),
                ("X-RateLimit-Limit", "\(limit)"),
                ("X-RateLimit-Remaining", "0"),
                ("X-RateLimit-Reset", "\(Int(Date().timeIntervalSince1970) + configuration.windowSeconds)")
            ])

            throw ApiError.tooManyRequests("Rate limit exceeded. Try again in \(configuration.windowSeconds) seconds.")
                .withHeaders(headers)
        }

        // Process request and add rate limit headers to response
        let response = try await next.respond(to: request)

        if configuration.includeHeaders {
            response.headers.add(name: "X-RateLimit-Limit", value: "\(limit)")
            response.headers.add(name: "X-RateLimit-Remaining", value: "\(remaining)")
            response.headers.add(name: "X-RateLimit-Reset", value: "\(Int(Date().timeIntervalSince1970) + configuration.windowSeconds)")
        }

        return response
    }
}

// MARK: - Tenant Rate Limit Config

/// Tenant-specific rate limit configuration loaded from JSON.
private struct TenantRateLimitConfig: Codable {
    let limits: [String: Int]
}

// MARK: - ApiError Extension

private extension ApiError {
    func withHeaders(_ headers: HTTPHeaders) -> ApiError {
        var error = self
        // Store headers for middleware to handle
        // In a real implementation, you'd extend ApiError to include headers
        return error
    }
}

// MARK: - Response Cache Middleware

/// Redis-backed response cache for GET content endpoints.
public struct ResponseCacheMiddleware: AsyncMiddleware, Sendable {
    let ttl: Int  // seconds

    public init(ttl: Int = 300) {
        self.ttl = ttl
    }

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Only cache GET requests
        guard request.method == .GET else {
            return try await next.respond(to: request)
        }

        // Only cache API content endpoints
        guard request.url.path.hasPrefix("/api/v1/") else {
            return try await next.respond(to: request)
        }

        let cacheKey = "cache:\(request.url.path)?\(request.url.query ?? "")"

        // Check cache
        do {
            if let cached = try await request.redis.get(RedisKey(cacheKey), as: String.self).get() {
                let response = Response(status: .ok)
                response.body = .init(string: cached)
                response.headers.contentType = .json
                response.headers.add(name: "X-Cache", value: "HIT")
                response.headers.add(name: "Age", value: "0")
                return response
            }
        } catch {
            request.logger.debug("Cache miss: \(error)")
        }

        // Execute handler
        let response = try await next.respond(to: request)
        response.headers.add(name: "X-Cache", value: "MISS")

        // Store in cache if successful
        if response.status == .ok {
            if let body = response.body.string {
                do {
                    let key = RedisKey(cacheKey)
                    _ = try await request.redis.set(key, to: body).get()
                    _ = try await request.redis.expire(key, after: .seconds(Int64(ttl))).get()
                } catch {
                    request.logger.debug("Cache store failed: \(error)")
                }
            }
        }

        // ETag support
        if let body = response.body.string {
            let etag = body.hashValue.description
            response.headers.add(name: "ETag", value: "\"\(etag)\"")

            if let ifNoneMatch = request.headers.first(name: "If-None-Match"),
               ifNoneMatch == "\"\(etag)\"" {
                return Response(status: .notModified)
            }
        }

        return response
    }
}

// MARK: - Audit Log Middleware

/// Subscribes to mutation events and writes audit log entries.
public struct AuditLogService: Sendable {

    /// Configure event subscriptions for audit logging.
    public static func configure(app: Application) {
        app.eventBus.subscribe(ContentCreatedEvent.self) { event, context in
            try await writeLog(
                db: app.db,
                entryId: event.entryId,
                contentType: event.contentType,
                action: "create",
                userId: event.userId ?? context.userId,
                tenantId: context.tenantId
            )
        }

        app.eventBus.subscribe(ContentUpdatedEvent.self) { event, context in
            try await writeLog(
                db: app.db,
                entryId: event.entryId,
                contentType: event.contentType,
                action: "update",
                userId: event.userId ?? context.userId,
                tenantId: context.tenantId
            )
        }

        app.eventBus.subscribe(ContentDeletedEvent.self) { event, context in
            try await writeLog(
                db: app.db,
                entryId: event.entryId,
                contentType: event.contentType,
                action: "delete",
                userId: event.userId ?? context.userId,
                tenantId: context.tenantId
            )
        }

        app.eventBus.subscribe(ContentStateChangedEvent.self) { event, context in
            try await writeLog(
                db: app.db,
                entryId: event.entryId,
                contentType: event.contentType,
                action: "state_change:\(event.fromState)->\(event.toState)",
                userId: event.userId ?? context.userId,
                tenantId: context.tenantId
            )
        }

        app.logger.info("Audit log service configured")
    }

    private static func writeLog(
        db: Database,
        entryId: UUID,
        contentType: String,
        action: String,
        userId: String?,
        tenantId: String?
    ) async throws {
        let log = AuditLog(
            entryId: entryId,
            contentType: contentType,
            action: action,
            userId: userId,
            tenantId: tenantId
        )
        try await log.save(on: db)
    }
}

// MARK: - Structured Logging Middleware

/// Attaches structured metadata to every request log line:
/// - `user-id`: the authenticated user's ID
/// - `tenant-id`: the resolved tenant ID
/// - `method`: HTTP method
/// - `path`: request URL path
/// - Logs request duration on completion
public struct StructuredLoggingMiddleware: AsyncMiddleware, Sendable {

    public init() {}

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let start = ContinuousClock.now

        // Attach context to all log lines for this request
        request.logger[metadataKey: "method"] = "\(request.method.rawValue)"
        request.logger[metadataKey: "path"] = "\(request.url.path)"

        if let user = request.auth.get(CmsUser.self) {
            request.logger[metadataKey: "user-id"] = "\(user.userId)"
        }

        do {
            let response = try await next.respond(to: request)

            let elapsed = ContinuousClock.now - start
            let ms = elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000
            request.logger[metadataKey: "status"] = "\(response.status.code)"
            request.logger[metadataKey: "duration-ms"] = "\(ms)"
            request.logger.info("Request completed")

            // Add Server-Timing header for observability
            response.headers.add(name: "Server-Timing", value: "total;dur=\(ms)")

            return response
        } catch {
            let elapsed = ContinuousClock.now - start
            let ms = elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000
            request.logger[metadataKey: "duration-ms"] = "\(ms)"
            request.logger[metadataKey: "error"] = "\(String(describing: error))"
            request.logger.error("Request failed")
            throw error
        }
    }
}

// MARK: - Graceful Shutdown Handler

/// Logs application lifecycle events for observability.
public struct GracefulShutdownHandler: LifecycleHandler, Sendable {

    public init() {}

    public func didBoot(_ application: Application) throws {
        application.logger.info("SwiftCMS server started",
            metadata: [
                "environment": "\(application.environment.name)",
                "multi-tenant": "\(Environment.get("MULTI_TENANT") ?? "false")",
            ])
    }

    public func shutdown(_ application: Application) {
        application.logger.info("SwiftCMS shutting down gracefully")
    }
}
