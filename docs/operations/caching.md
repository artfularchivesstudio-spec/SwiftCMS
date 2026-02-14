# Caching Guide

SwiftCMS includes a robust caching system powered by Redis to improve performance and reduce database load.

## Overview

The caching system provides:

- **Query result caching** - Cache database query results
- **Content caching** - Cache rendered content and responses
- **Cache invalidation** - Automatic and manual cache clearing
- **Cache warming** - Pre-populate cache with frequently accessed data
- **Distributed caching** - Share cache across multiple instances
- **Cache metrics** - Monitor cache performance

## Configuration

### Redis Configuration

Configure Redis in your `.env` file:

```bash
# Redis Configuration
REDIS_URL=redis://localhost:6379
REDIS_PASSWORD=
REDIS_DB=0

# Cache Configuration
CACHE_ENABLED=true
CACHE_TTL=3600
CACHE_MAX_MEMORY=256mb
CACHE_EVICTION_POLICY=allkeys-lru

# Cache Keys Prefix
CACHE_KEY_PREFIX=swiftcms:
```

### Cache Options

| Option | Description | Default |
|--------|-------------|---------|
| `CACHE_ENABLED` | Enable/disable caching | `true` |
| `CACHE_TTL` | Default time-to-live in seconds | `3600` (1 hour) |
| `CACHE_MAX_MEMORY` | Maximum Redis memory usage | `256mb` |
| `CACHE_EVICTION_POLICY` | Redis eviction policy | `allkeys-lru` |
| `CACHE_KEY_PREFIX` | Prefix for all cache keys | `swiftcms:` |

### Redis Eviction Policies

Choose an appropriate eviction policy:

| Policy | Description | Use Case |
|--------|-------------|----------|
| `noeviction` | Never evict keys | Cache-only Redis |
| `allkeys-lru` | Evict least recently used | General purpose |
| `allkeys-lfu` | Evict least frequently used | Hot data focus |
| `volatile-ttl` | Evict with shortest TTL | TTL-based caching |
| `allkeys-random` | Evict random keys | Simple caching |

## Cache Strategies

### Content Entry Caching

Content entries are cached with automatic invalidation:

```swift
// Cache key: swiftcms:content:{contentType}:{id}
let cacheKey = "content:\(contentType):\(entryId)"

// Get from cache
if let cached = try await cache.get(cacheKey) {
    return cached
}

// Or fetch from database
let entry = try await ContentEntry.find(entryId, on: db)
try await cache.set(cacheKey, to: entry, expiresIn: .hours(1))

return entry
```

### Query Result Caching

Cache expensive query results:

```swift
struct ContentListCache {
    static func get(
        contentType: String,
        page: Int,
        perPage: Int,
        filter: [String: Any]
    ) async throws -> [ContentEntry] {
        // Create cache key from parameters
        let cacheKey = [
            "query",
            contentType,
            "page:\(page)",
            "perPage:\(perPage)",
            "filter:\(filter.hashValue)"
        ].joined(separator: ":")

        // Try cache first
        if let cached = try await cache.get(cacheKey) {
            return cached
        }

        // Query database
        let results = try await ContentEntry.query(on: db)
            .filter(\.$contentType == contentType)
            .paginate(page, perPage: perPage)

        // Cache results
        try await cache.set(cacheKey, to: results, expiresIn: .minutes(15))

        return results
    }
}
```

### Schema Caching

Content type definitions are cached:

```swift
// Cache key: swiftcms:schema:{contentType}
let schemaKey = "schema:\(contentType)"

if let cachedSchema = try await cache.get(schemaKey) {
    return cachedSchema
}

let schema = try await ContentTypeDefinition.query(on: db)
    .filter(\.$slug == contentType)
    .first()

try await cache.set(schemaKey, to: schema, expiresIn: .hours(24))

return schema
```

### Response Caching

Cache HTTP responses for public content:

```swift
// Cache-Control header
response.headers.add(name: "Cache-Control", value: "public, max-age=300")

// ETag for conditional requests
response.headers.add(name: "ETag", value: entry.etag)

// Last-Modified header
response.headers.add(name: "Last-Modified", value: entry.updatedAt)
```

## Cache Invalidation

### Automatic Invalidation

Cache is automatically invalidated when:

- **Content entry updated**: Clear entry cache
- **Content entry deleted**: Remove from cache
- **Schema changed**: Clear schema cache
- **Settings updated**: Clear settings cache

```swift
// Invalidate on update
entry.updatedAt = Date()
try await entry.save(on: db)
try await cache.delete("content:\(contentType):\(entryId)")

// Invalidate related caches
try await cache.delete("query:\(contentType):*")
```

### Manual Invalidation

Manually clear cache:

```swift
// Clear specific key
try await cache.delete("content:blog-posts:123")

// Clear pattern
try await cache.delete("content:blog-posts:*")

// Clear all content
try await cache.delete("content:*")

// Clear all cache
try await cache.flush()
```

### Cache Invalidation Endpoints

REST API endpoints for cache management:

```http
# Clear specific content cache
DELETE /api/v1/admin/cache/content/{contentType}/{id}

# Clear all content cache
DELETE /api/v1/admin/cache/content

# Clear all schema cache
DELETE /api/v1/admin/cache/schema

# Clear all cache
DELETE /api/v1/admin/cache/all
```

## Cache Warming

### Pre-populate Cache

Warm up cache with frequently accessed data:

```bash
# CLI command to warm cache
swift run App cache:warm --content-type=blog-posts --limit=100
```

### Scheduled Warming

Schedule cache warming during off-peak hours:

```swift
// Background job to warm cache
struct CacheWarmerJob: Job {
    func dequeue(_ context: JobContext, _ worker: EventLoopPromise<Void>) {
        // Warm content cache
        let contentTypes = ["blog-posts", "products", "pages"]

        for contentType in contentTypes {
            // Fetch and cache recent entries
            let entries = try await ContentEntry.query(on: db)
                .filter(\.$contentType == contentType)
                .sort(\.$createdAt, .descending)
                .limit(100)
                .all()

            for entry in entries {
                let cacheKey = "content:\(contentType):\(entry.id!)"
                try await cache.set(cacheKey, to: entry, expiresIn: .hours(1))
            }
        }
    }
}
```

## Cache Monitoring

### Cache Metrics

Monitor cache performance:

```swift
struct CacheMetrics {
    let hits: Int           // Cache hits
    let misses: Int         // Cache misses
    let hitRate: Double     // Hit rate (hits / total)
    let memoryUsed: Int     // Memory used in bytes
    let keyCount: Int       // Number of keys stored

    var hitRatePercentage: String {
        String(format: "%.2f%%", hitRate * 100)
    }
}
```

### Redis INFO Command

Get Redis cache statistics:

```bash
$ redis-cli INFO stats

# Key stats
keyspace_hits:12500
keyspace_misses:3500
keyspace_hit_rate:0.78

# Memory stats
used_memory:256000000
used_memory_peak:270000000
used_memory_percentage:0.25

# Key count
db0:keys=1250,expires=800
```

### Cache Dashboard

Monitor cache in the admin panel:

```
┌─────────────────────────────────────┐
│ Cache Performance                   │
├─────────────────────────────────────┤
│ Hit Rate:     78.5%                 │
│ Memory Used:  245 MB / 256 MB       │
│ Total Keys:   1,250                 │
│ Expire Keys:  800                   │
└─────────────────────────────────────┘
```

## Best Practices

### 1. Set Appropriate TTLs

Choose TTL based on content volatility:

| Content Type | Recommended TTL | Rationale |
|--------------|-----------------|-----------|
| Published content | 1-24 hours | Changes infrequently |
| Draft content | 5-15 minutes | Changes frequently |
| Schema definitions | 24 hours | Rarely changes |
| Settings | 1 hour | Occasionally changes |
| User sessions | 30 minutes | Security |

### 2. Use Cache Hierarchies

Implement multi-level caching:

```
L1: In-memory cache (fast, limited)
    ↓
L2: Redis cache (fast, shared)
    ↓
L3: Database (slow, authoritative)
```

### 3. Cache Granularly

Cache at appropriate granularity:

```swift
// Good - Cache individual entries
cache.set("content:blog:123", entry)

// Avoid - Cache entire lists
cache.set("content:blog:all", allEntries)
```

### 4. Handle Cache Failures

Degrade gracefully if cache fails:

```swift
func getFromCacheOrDB(key: String) async throws -> ContentEntry {
    do {
        return try await cache.get(key)
    } catch {
        // Log error but continue
        logger.warning("Cache miss, fetching from DB", metadata: ["key": key])
        return try await fetchFromDB(key)
    }
}
```

### 5. Monitor Cache Performance

Track cache metrics:

```swift
// Record cache hit
metrics.increment("cache.hit", ["contentType": "blog-posts"])

// Record cache miss
metrics.increment("cache.miss", ["contentType": "blog-posts"])

// Track cache size
metrics.gauge("cache.size", keyCount)
```

## Troubleshooting

### High Cache Miss Rate

**Symptoms**: Hit rate below 50%

**Solutions**:
1. Check if TTL is too short
2. Verify cache keys are consistent
3. Check for cache stampede (many requests for same key)
4. Consider cache warming

### High Memory Usage

**Symptoms**: Redis using > 80% of max memory

**Solutions**:
1. Review eviction policy
2. Reduce TTL for cached items
3. Reduce cache size for large objects
4. Add more Redis memory

### Stale Cache

**Symptoms**: Old data being served

**Solutions**:
1. Verify invalidation is working
2. Check cache expiration
3. Review cache key generation
4. Manual cache flush

### Connection Issues

**Symptoms**: Unable to connect to Redis

**Solutions**:
1. Verify Redis is running
2. Check connection settings
3. Review firewall rules
4. Check for DNS issues

## Redis CLI Commands

### Useful Commands

```bash
# Connect to Redis
redis-cli

# Check memory usage
INFO memory

# List all keys
KEYS swiftcms:*

# Get specific key
GET swiftcms:content:blog-posts:123

# Delete key
DEL swiftcms:content:blog-posts:123

# Delete pattern
EVAL "return redis.call('del', unpack(redis.call('keys', 'swiftcms:content:*')))" 0

# Flush all cache
FLUSHALL

# Flush current DB
FLUSHDB

# Get TTL
TTL swiftcms:content:blog-posts:123

# Set TTL
EXPIRE swiftcms:content:blog-posts:123 3600

# Monitor commands
MONITOR
```

## Advanced Features

### Cache Stampede Prevention

Prevent cache stampede with lock:

```swift
func getWithStampedeProtection(key: String) async throws -> ContentEntry {
    // Try cache first
    if let cached = try await cache.get(key) {
        return cached
    }

    // Acquire lock
    let lockKey = "lock:\(key)"
    let lockAcquired = try await cache.acquireLock(lockKey, expiresIn: .seconds(10))

    guard lockAcquired else {
        // Wait for other request to populate cache
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        return try await cache.get(key) ?? fetchFromDB(key)
    }

    defer {
        // Release lock
        try? cache.releaseLock(lockKey)
    }

    // Fetch from DB and cache
    let entry = try await fetchFromDB(key)
    try await cache.set(key, to: entry, expiresIn: .hours(1))

    return entry
}
```

### Cache Compression

Compress large cached values:

```swift
// Enable compression in Redis config
redis config set compression-max-depth 10
redis config set compression-min-length 1024

// Or compress before caching
func setCompressed<T>(_ key: String, value: T) async throws {
    let data = try JSONEncoder().encode(value)
    let compressed = try data.compressed(using: .zlib)
    try await cache.set(key, to: compressed)
}
```

### Distributed Cache Lock

Implement distributed locking:

```swift
struct DistributedLock {
    func acquire(key: String, ttl: TimeInterval) async throws -> Bool {
        let lockKey = "lock:\(key)"
        return try await cache.set(
            lockKey,
            to: UUID().uuidString,
            expiresIn: .seconds(ttl),
            onlyIfNotExists: true
        )
    }

    func release(key: String) async throws {
        let lockKey = "lock:\(key)"
        try await cache.delete(lockKey)
    }
}
```

## Additional Resources

- [Redis Documentation](https://redis.io/documentation)
- [Redis Best Practices](https://redis.io/topics/best-practices)
- [Cache Patterns](https://docs.aws.amazon.com/elasticache/latest/rediscaching/BestPractices.html)
- [Vapor Cache Documentation](https://docs.vapor.codes/advanced/cache/)
