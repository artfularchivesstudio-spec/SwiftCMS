import Vapor
import Redis
import Fluent
import CMSCore
import CMSSchema
import CMSEvents
import CMSJobs
import CMSObjects

// MARK: - Cache Invalidation Service

/// Service for invalidating cache entries when content changes.
public struct CacheInvalidationService: Sendable {

    /// Invalidates cache entries by content type.
    public static func invalidateByContentType(
        app: Application,
        contentType: String
    ) async throws {
        let prefix = Environment.get("CACHE_KEY_PREFIX") ?? "swiftcms:cache"
        let tagKey = RedisKey("\(prefix):tag:content:\(contentType)")

        // Get all keys for this content type
        let keys = try await app.redis.smembers(of: tagKey).get()

        // Delete each cached entry
        for key in keys {
            _ = try await app.redis.del(key).get()
        }
        // Clear the tag set
        _ = try await app.redis.del(tagKey).get()

        app.logger.info("Invalidated cache for content type: \(contentType)")
    }

    /// Invalidates cache entries by tag pattern (wildcard support).
    public static func invalidateByTagPattern(
        app: Application,
        pattern: String
    ) async throws {
        let prefix = Environment.get("CACHE_KEY_PREFIX") ?? "swiftcms:cache"

        // Find all matching tag keys
        var cursor = "0"
        var keysToDelete: [RedisKey] = []

        repeat {
            let result = try await app.redis.scan(startingFrom: cursor, matching: "\(prefix):tag:\(pattern)", count: 100).get()
            cursor = result.0
            keysToDelete.append(contentsOf: result.1)

            for tagKey in result.1 {
                // Get all keys for this tag
                let tagMembers = try await app.redis.smembers(of: tagKey).get()
                // Delete each cached entry
                for key in tagMembers {
                    _ = try await app.redis.del(key).get()
                }
                // Clear the tag set
                _ = try await app.redis.del(tagKey).get()
            }
        } while cursor != "0"

        app.logger.info("Invalidated cache for tag pattern: \(pattern)")
    }

    /// Invalidates all cache entries (flush all).
    public static func invalidateAll(app: Application) async throws {
        let prefix = Environment.get("CACHE_KEY_PREFIX") ?? "swiftcms:cache"

        // Find all cache keys
        var cursor = "0"
        var keysToDelete: [RedisKey] = []

        repeat {
            let result = try await app.redis.scan(startingFrom: cursor, matching: "\(prefix):*", count: 1000).get()
            cursor = result.0
            keysToDelete.append(contentsOf: result.1)
        } while cursor != "0"

        // Delete all keys
        if !keysToDelete.isEmpty {
            _ = try await app.redis.del(keysToDelete).get()
        }

        app.logger.info("Invalidated all cache entries")
    }

    /// Configures cache invalidation hooks.
    public static func configure(app: Application) {
        // Invalidate cache on content creation
        app.eventBus.subscribe(ContentCreatedEvent.self) { event, context in
            try await invalidateByContentType(
                app: app,
                contentType: event.contentType
            )
        }

        // Invalidate cache on content update
        app.eventBus.subscribe(ContentUpdatedEvent.self) { event, context in
            try await invalidateByContentType(
                app: app,
                contentType: event.contentType
            )
        }

        // Invalidate cache on content deletion
        app.eventBus.subscribe(ContentDeletedEvent.self) { event, context in
            try await invalidateByContentType(
                app: app,
                contentType: event.contentType
            )
        }

        // Invalidate cache on content publish
        app.eventBus.subscribe(ContentPublishedEvent.self) { event, context in
            try await invalidateByContentType(
                app: app,
                contentType: event.contentType
            )
        }

        // Invalidate cache on schema changes
        app.eventBus.subscribe(SchemaChangedEvent.self) { event, _ in
            try await invalidateByTagPattern(
                app: app,
                pattern: "content:\(event.contentTypeSlug)"
            )
        }

        app.logger.info("Cache invalidation service configured")
    }
}

// MARK: - Cache Warming Service

/// Service for pre-warming cache with popular content.
public struct CacheWarmingService: Sendable {

    /// Warms cache for a specific path.
    public static func warmPath(
        app: Application,
        path: String,
        headers: HTTPHeaders = [:]
    ) async throws {
        var request = Request(
            application: app,
            method: .GET,
            url: URI(string: path),
            headers: headers
        )

        let response = try await app.respond(to: request)
        app.logger.info("Warmed cache for path: \(path) -> \(response.status.code)")
    }

    /// Warms cache for multiple paths.
    public static func warmPaths(
        app: Application,
        paths: [String],
        headers: HTTPHeaders = [:]
    ) async throws {
        for path in paths {
            try? await warmPath(app: app, path: path, headers: headers)
        }
    }

    /// Warms cache for content entries of a specific type.
    public static func warmContentType(
        app: Application,
        contentType: String,
        limit: Int = 100
    ) async throws {
        let path = "/api/v1/content/\(contentType)?limit=\(limit)"
        try await warmPath(app: app, path: path)
    }

    /// Warms cache for homepage and popular routes.
    public static func warmPopularRoutes(app: Application) async throws {
        let popularRoutes = [
            "/api/v1/content",
            "/api/v1/health",
            "/api/v1/media",
        ]

        try await warmPaths(app: app, paths: popularRoutes)
    }

    /// Configures scheduled cache warming.
    public static func configure(app: Application) {
        // Schedule daily cache warming
        if Environment.get("REDIS_URL") != nil {
            app.queues.schedule(CacheWarmupJob())
                .hourly()
                .at(0) // At the top of every hour

            app.logger.info("Cache warming service configured")
        }
    }
}

// MARK: - Cache Warmup Job

/// Background job for scheduled cache warming.
public struct CacheWarmupJob: Job, Sendable {
    public typealias Payload = CacheWarmupPayload

    public func dequeue(_ context: JobContext, _ payload: Payload) async throws {
        switch payload.task {
        case .popularRoutes:
            try await CacheWarmingService.warmPopularRoutes(app: context.application)

        case .contentType(let contentType):
            try await CacheWarmingService.warmContentType(
                app: context.application,
                contentType: contentType
            )

        case .custom(let path):
            try await CacheWarmingService.warmPath(
                app: context.application,
                path: path
            )
        }
    }
}

/// Payload for cache warmup job.
public struct CacheWarmupPayload: JobData, Sendable {
    public enum Task: Codable, Sendable {
        case popularRoutes
        case contentType(String)
        case custom(String)
    }

    public let task: Task
}

// MARK: - Cache Metrics Controller

/// Controller for cache statistics endpoint.
public struct CacheMetricsController: RouteCollection, Sendable {

    public func boot(routes: RoutesBuilder) throws {
        let cacheRoutes = routes.grouped("api", "v1", "cache")

        cacheRoutes.get("stats", use: getStats)
        cacheRoutes.post("invalidate", use: invalidate)
        cacheRoutes.post("invalidate", "tag", ":tag", use: invalidateByTag)
        cacheRoutes.post("warm", use: warm)
    }

    /// Returns cache statistics.
    private func getStats(_ req: Request) async throws -> CacheStatsResponse {
        let prefix = Environment.get("CACHE_KEY_PREFIX") ?? "swiftcms:cache"
        let hitsKey = RedisKey("\(prefix):metrics:hits")
        let missesKey = RedisKey("\(prefix):metrics:misses")

        let hitsData = try await req.redis.get(hitsKey, as: Data.self).get()
        let missesData = try await req.redis.get(missesKey, as: Data.self).get()

        let hits = hitsData.flatMap { try? JSONDecoder().decode(Int.self, from: $0) } ?? 0
        let misses = missesData.flatMap { try? JSONDecoder().decode(Int.self, from: $0) } ?? 0
        let total = hits + misses

        let hitRate = total > 0 ? Double(hits) / Double(total) * 100 : 0

        // Get cache size estimate
        var cursor = "0"
        var cacheSize = 0
        repeat {
            let result = try await req.redis.scan(startingFrom: cursor, matching: "\(prefix):*", count: 1000).get()
            cursor = result.0
            cacheSize += result.1.count
        } while cursor != "0"

        return CacheStatsResponse(
            hits: hits,
            misses: misses,
            hitRate: hitRate,
            cacheSize: cacheSize,
            timestamp: Date()
        )
    }

    /// Invalidates all cache.
    private func invalidate(_ req: Request) async throws -> HTTPStatus {
        try await CacheInvalidationService.invalidateAll(app: req.application)
        return .ok
    }

    /// Invalidates cache by tag.
    private func invalidateByTag(_ req: Request) async throws -> HTTPStatus {
        guard let tag = req.parameters.get("tag") else {
            throw Abort(.badRequest, reason: "Tag parameter required")
        }

        try await CacheInvalidationService.invalidateByTagPattern(
            app: req.application,
            pattern: tag
        )

        return .ok
    }

    /// Triggers cache warming.
    private func warm(_ req: Request) async throws -> HTTPStatus {
        let payload = try req.content.decode(CacheWarmRequest.self)

        switch payload.task {
        case .popularRoutes:
            try await CacheWarmingService.warmPopularRoutes(app: req.application)

        case .contentType(let contentType):
            try await CacheWarmingService.warmContentType(
                app: req.application,
                contentType: contentType,
                limit: payload.limit ?? 100
            )

        case .custom(let path):
            try await CacheWarmingService.warmPath(
                app: req.application,
                path: path
            )
        }

        return .accepted
    }
}

/// Cache statistics response.
public struct CacheStatsResponse: Content, Sendable {
    public let hits: Int
    public let misses: Int
    public let hitRate: Double
    public let cacheSize: Int
    public let timestamp: Date

    public init(hits: Int, misses: Int, hitRate: Double, cacheSize: Int, timestamp: Date) {
        self.hits = hits
        self.misses = misses
        self.hitRate = hitRate
        self.cacheSize = cacheSize
        self.timestamp = timestamp
    }
}

/// Cache warm request.
public struct CacheWarmRequest: Content, Sendable {
    public let task: CacheWarmupPayload.Task
    public let limit: Int?

    public init(task: CacheWarmupPayload.Task, limit: Int? = nil) {
        self.task = task
        self.limit = limit
    }
}
