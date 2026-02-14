import Vapor
import Redis
import Fluent
import CMSAuth
import CMSSchema
import CMSEvents
import CMSObjects

// MARK: - Rate Limiting Middleware

/// Redis-backed rate limiting per IP/role tier.
/// Public: 60/min, Authenticated: 300/min, Admin: unlimited.
public struct RateLimitMiddleware: AsyncMiddleware, Sendable {

    public init() {}

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Determine tier
        let user = request.auth.get(CmsUser.self)
        if user?.roles.contains("super-admin") == true {
            return try await next.respond(to: request)  // Admin: unlimited
        }

        let limit: Int
        let window: Int = 60  // seconds
        let identifier: String

        if let user = user {
            limit = 300
            identifier = "rate:\(user.userId)"
        } else {
            limit = 60
            let ip = request.headers.first(name: "X-Forwarded-For")
                ?? request.remoteAddress?.description ?? "unknown"
            identifier = "rate:\(ip)"
        }

        // Check Redis if available
        let redis = request.redis
        do {
            let key = RedisKey(identifier)
            let current = try await redis.increment(key).get()
            if current == 1 {
                _ = try await redis.expire(key, after: .seconds(Int64(window))).get()
            }

            if current > limit {
                var headers = HTTPHeaders()
                headers.add(name: "Retry-After", value: "\(window)")
                headers.add(name: "X-RateLimit-Limit", value: "\(limit)")
                headers.add(name: "X-RateLimit-Remaining", value: "0")
                throw ApiError.tooManyRequests("Rate limit exceeded. Try again in \(window) seconds.")
            }

            let response = try await next.respond(to: request)
            response.headers.add(name: "X-RateLimit-Limit", value: "\(limit)")
            response.headers.add(name: "X-RateLimit-Remaining", value: "\(max(0, limit - Int(current)))")
            return response
        } catch let error as ApiError {
            throw error
        } catch {
            // Redis unavailable or other error, fall through
            request.logger.warning("Rate limiting error: \(error)")
        }

        return try await next.respond(to: request)
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
        let redis = request.redis
        do {
            if let cached = try await redis.get(RedisKey(cacheKey), as: String.self).get() {
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
            let redis = request.redis
            if let body = response.body.string {
                do {
                    let key = RedisKey(cacheKey)
                    _ = try await redis.set(key, to: body).get()
                    _ = try await redis.expire(key, after: .seconds(Int64(ttl))).get()
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
