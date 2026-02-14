import Vapor
import Redis
import Fluent
import CMSCore
import CMSSchema
import CMSObjects
import CMSAuth

// MARK: - Cache Middleware

/// Intelligent Redis-backed response cache with advanced features:
/// - Cache key generation from path + query + auth
/// - Configurable TTL per route pattern
/// - Cache-Control header parsing
/// - ETag support for conditional requests
/// - Tag-based cache grouping
/// - Metrics tracking (hit/miss ratio, cache size)
public struct CacheMiddleware: AsyncMiddleware, Sendable {

    /// Cache configuration settings.
    public struct Configuration: Sendable {
        /// Default TTL in seconds for cached responses.
        public var defaultTTL: Int

        /// Route-specific TTL overrides (pattern: seconds).
        public var routeTTL: [String: Int]

        /// Cache key prefix.
        public var keyPrefix: String

        /// Whether to respect Cache-Control headers from clients.
        public var respectClientCacheControl: Bool

        /// Whether to include cache metrics in responses.
        public var includeMetrics: Bool

        /// Whether to enable ETag support.
        public var enableETag: Bool

        /// Maximum cache entry size in bytes (0 = unlimited).
        public var maxEntrySize: Int

        /// Paths to exclude from caching (regex patterns).
        public var excludePatterns: [String]

        /// Default tags to apply to all cached entries.
        public var defaultTags: [String]

        public init(
            defaultTTL: Int = 300,
            routeTTL: [String: Int] = [:],
            keyPrefix: String = "swiftcms:cache",
            respectClientCacheControl: Bool = true,
            includeMetrics: Bool = true,
            enableETag: Bool = true,
            maxEntrySize: Int = 1_048_576, // 1MB
            excludePatterns: [String] = [],
            defaultTags: [String] = []
        ) {
            self.defaultTTL = defaultTTL
            self.routeTTL = routeTTL
            self.keyPrefix = keyPrefix
            self.respectClientCacheControl = respectClientCacheControl
            self.includeMetrics = includeMetrics
            self.enableETag = enableETag
            self.maxEntrySize = maxEntrySize
            self.excludePatterns = excludePatterns
            self.defaultTags = defaultTags
        }

        /// Creates configuration from environment variables.
        public static func fromEnvironment() -> Configuration {
            var config = Configuration()

            if let ttl = Environment.get("CACHE_DEFAULT_TTL").flatMap(Int.init) {
                config.defaultTTL = ttl
            }

            if let maxSize = Environment.get("CACHE_MAX_ENTRY_SIZE").flatMap(Int.init) {
                config.maxEntrySize = maxSize
            }

            if let respect = Environment.get("CACHE_RESPECT_CLIENT_CONTROL") {
                config.respectClientCacheControl = respect.lowercased() == "true"
            }

            if let metrics = Environment.get("CACHE_INCLUDE_METRICS") {
                config.includeMetrics = metrics.lowercased() == "true"
            }

            if let etag = Environment.get("CACHE_ENABLE_ETAG") {
                config.enableETag = etag.lowercased() == "true"
            }

            // Parse exclude patterns
            if let excludeStr = Environment.get("CACHE_EXCLUDE_PATTERNS") {
                config.excludePatterns = excludeStr.split(separator: ",").map(String.init)
            }

            // Parse default tags
            if let tagsStr = Environment.get("CACHE_DEFAULT_TAGS") {
                config.defaultTags = tagsStr.split(separator: ",").map(String.init)
            }

            return config
        }
    }

    private let configuration: Configuration

    public init(configuration: Configuration = .fromEnvironment()) {
        self.configuration = configuration
    }

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Only cache GET and HEAD requests
        guard request.method == .GET || request.method == .HEAD else {
            return try await next.respond(to: request)
        }

        // Check if path is excluded
        if isPathExcluded(request.url.path) {
            return try await next.respond(to: request)
        }

        // Check client Cache-Control header
        if configuration.respectClientCacheControl {
            if let cacheControl = request.headers.first(name: "Cache-Control") {
                if cacheControl.contains("no-store") || cacheControl.contains("no-cache") {
                    return try await next.respond(to: request)
                }
            }
        }

        // Generate cache key
        let cacheKey = generateCacheKey(for: request)

        // Try to get from cache
        do {
            let cachedData = try await request.redis.get(RedisKey(cacheKey), as: Data.self).get()
            if let cachedData = cachedData,
               let cached = try? JSONDecoder().decode(CachedResponse.self, from: cachedData) {
                // Check ETag if enabled
                if configuration.enableETag,
                   let ifNoneMatch = request.headers.first(name: "If-None-Match"),
                   ifNoneMatch == cached.etag {
                    return Response(status: .notModified)
                }

                // Return cached response
                let response = Response(status: .ok)
                response.headers.contentType = cached.contentType
                response.headers.add(name: "Content-Type", value: cached.contentTypeString)
                response.body = .init(string: cached.body)
                response.headers.add(name: "X-Cache", value: "HIT")
                response.headers.add(name: "ETag", value: cached.etag)
                response.headers.add(name: "Age", value: "\(Int(Date().timeIntervalSince(cached.cachedAt)))")

                if configuration.includeMetrics {
                    try await updateMetrics(request: request, hit: true)
                }

                return response
            }
        } catch {
            request.logger.debug("Cache miss: \(error)")
        }

        // Execute handler
        let response = try await next.respond(to: request)

        // Cache successful responses
        guard shouldCache(response: response) else {
            response.headers.add(name: "X-Cache", value: "BYPASS")
            return response
        }

        // Get response body
        guard let body = response.body.string else {
            response.headers.add(name: "X-Cache", value: "BYPASS")
            return response
        }

        // Check entry size
        if configuration.maxEntrySize > 0 && body.utf8.count > configuration.maxEntrySize {
            response.headers.add(name: "X-Cache", value: "SIZE_EXCEEDED")
            return response
        }

        // Generate ETag if enabled
        var etag = ""
        if configuration.enableETag {
            etag = "\"\(body.hashValue)\""
            response.headers.add(name: "ETag", value: etag)
        }

        // Store in cache
        let ttl = getTTL(for: request)
        do {
            let cached = CachedResponse(
                body: body,
                contentType: response.headers.contentType ?? .json,
                statusCode: Int(response.status.code),
                etag: etag,
                cachedAt: Date(),
                tags: getTags(for: request)
            )

            // Encode to JSON for Redis storage
            let encoded = try JSONEncoder().encode(cached)
            let key = RedisKey(cacheKey)
            _ = try await request.redis.setex(key, to: encoded, expirationInSeconds: ttl).get()

            // Add to tag sets
            for tag in cached.tags {
                let tagKey = RedisKey("\(configuration.keyPrefix):tag:\(tag)")
                _ = try await request.redis.sadd([cacheKey], to: tagKey).get()
                _ = try await request.redis.expire(tagKey, after: .seconds(Int64(ttl))).get()
            }

            response.headers.add(name: "X-Cache", value: "MISS")

            if configuration.includeMetrics {
                try await updateMetrics(request: request, hit: false)
            }
        } catch {
            request.logger.debug("Cache store failed: \(error)")
            response.headers.add(name: "X-Cache", value: "STORE_FAILED")
        }

        return response
    }

    // MARK: - Cache Key Generation

    /// Generates a cache key from path + query + auth context.
    private func generateCacheKey(for request: Request) -> String {
        var components = [configuration.keyPrefix]

        // Add path
        components.append(request.url.path)

        // Add query string if present
        if let query = request.url.query, !query.isEmpty {
            components.append(query)
        }

        // Add tenant ID if multi-tenant
        if let tenantId = request.tenantId {
            components.append("tenant:\(tenantId)")
        }

        // Add user ID if authenticated (for per-user caching)
        if let user = request.auth.get(CmsUser.self) {
            components.append("user:\(user.userId)")
        }

        // Add locale if present
        if let locale = request.headers.first(name: "Accept-Language") {
            components.append("locale:\(locale)")
        }

        return components.joined(separator: ":")
    }

    /// Gets tags for the current request.
    private func getTags(for request: Request) -> [String] {
        var tags = configuration.defaultTags

        // Add content type tag if present in path
        if let contentType = extractContentType(from: request.url.path) {
            tags.append("content:\(contentType)")
        }

        // Add tenant tag
        if let tenantId = request.tenantId {
            tags.append("tenant:\(tenantId)")
        }

        // Add route pattern tag
        tags.append("route:\(request.url.path)")

        return tags
    }

    /// Extracts content type from path (e.g., /api/v1/content/blog -> blog).
    private func extractContentType(from path: String) -> String? {
        let pattern = "^/api/v1/content/([^/]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
              let range = Range(match.range(at: 1), in: path) else {
            return nil
        }
        return String(path[range])
    }

    // MARK: - Cache Control

    /// Determines if a path should be excluded from caching.
    private func isPathExcluded(_ path: String) -> Bool {
        for pattern in configuration.excludePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(path.startIndex..., in: path)
                if regex.firstMatch(in: path, range: range) != nil {
                    return true
                }
            }
        }
        return false
    }

    /// Determines if a response should be cached.
    private func shouldCache(response: Response) -> Bool {
        // Only cache successful responses
        guard response.status.code >= 200 && response.status.code < 300 else {
            return false
        }

        // Check response Cache-Control header
        if let cacheControl = response.headers.first(name: "Cache-Control") {
            if cacheControl.contains("no-store") || cacheControl.contains("private") {
                return false
            }
        }

        return true
    }

    /// Gets TTL for a specific route.
    private func getTTL(for request: Request) -> Int {
        let path = request.url.path

        // Check for exact match
        if let ttl = configuration.routeTTL[path] {
            return ttl
        }

        // Check for pattern match
        for (pattern, ttl) in configuration.routeTTL {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(path.startIndex..., in: path)
                if regex.firstMatch(in: path, range: range) != nil {
                    return ttl
                }
            }
        }

        return configuration.defaultTTL
    }

    // MARK: - Metrics

    /// Updates cache metrics.
    private func updateMetrics(request: Request, hit: Bool) async throws {
        let hitsKey = RedisKey("\(configuration.keyPrefix):metrics:hits")
        let missesKey = RedisKey("\(configuration.keyPrefix):metrics:misses")

        if hit {
            _ = try await request.redis.increment(hitsKey, by: 1).get()
        } else {
            _ = try await request.redis.increment(missesKey, by: 1).get()
        }

        // Set expiration on first hit/miss to reset metrics daily
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let expiration = tomorrow.timeIntervalSince1970 - Date().timeIntervalSince1970
        let expireSeconds = Int(expiration)
        _ = try await request.redis.expire(hitsKey, after: .seconds(Int64(expireSeconds))).get()
        _ = try await request.redis.expire(missesKey, after: .seconds(Int64(expireSeconds))).get()
    }
}

// MARK: - Cached Response

/// Represents a cached HTTP response.
public struct CachedResponse: Codable, Sendable {
    public let body: String
    public let contentTypeString: String
    public let statusCode: Int
    public let etag: String
    public let cachedAt: Date
    public let tags: [String]

    public init(body: String, contentType: HTTPMediaType, statusCode: Int, etag: String, cachedAt: Date, tags: [String]) {
        self.body = body
        self.contentTypeString = contentType.serialize()
        self.statusCode = statusCode
        self.etag = etag
        self.cachedAt = cachedAt
        self.tags = tags
    }

    public var contentType: HTTPMediaType {
        HTTPMediaType(contentTypeString) ?? .json
    }
}
