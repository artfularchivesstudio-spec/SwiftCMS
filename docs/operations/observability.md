# Observability Guide

SwiftCMS provides comprehensive observability features including structured logging, metrics, and distributed tracing for production monitoring and debugging.

## Overview

The observability stack includes:

- **Structured Logging** - JSON-formatted logs with context
- **Metrics Collection** - Application and business metrics
- **Distributed Tracing** - Request tracing across services
- **Health Checks** - System health endpoints
- **Performance Monitoring** - Response times, throughput
- **Error Tracking** - Automatic error aggregation

## Telemetry Setup

### Environment Variables

Configure observability in your `.env` file:

```bash
# Logging
LOG_LEVEL=info                    # trace, debug, info, warning, error
LOG_FORMAT=json                   # json or pretty
LOG_OUTPUT=stdout                 # stdout or file path

# Metrics
METRICS_ENABLED=true
METRICS_PORT=9090                 # Prometheus metrics endpoint
METRICS_PATH=/metrics

# Tracing
TRACING_ENABLED=true
TRACING_EXPORTER=jaeger           # jaeger, otlp, stdout
TRACING_ENDPOINT=http://localhost:4318
TRACING_SAMPLE_RATE=0.1           # 10% of requests

# Service Information
SERVICE_NAME=swiftcms
SERVICE_VERSION=1.0.0
SERVICE_ENVIRONMENT=production
```

### OpenTelemetry Configuration

SwiftCMS uses OpenTelemetry for observability:

```swift
import OpenTelemetry
import OpenTelemetrySdk
import OpenTelemetryProtocolExporter

func configureTelemetry(app: Application) {
    // Configure service
    let serviceResource = Resource(attributes: [
        "service.name": "swiftcms",
        "service.version": "1.0.0",
        "service.environment": "production"
    ])

    // Configure tracing
    let tracerProvider = TracerProviderBuilder()
        .add(spanProcessor: SimpleSpanProcessor(
            spanExporter: OtlpTraceExporter(
                endpoint: app.environment.tracingEndpoint
            )
        ))
        .withResource(serviceResource)
        .build()

    OpenTelemetry.registerTracerProvider(tracerProvider)

    // Configure metrics
    let meterProvider = MeterProviderBuilder()
        .withResource(serviceResource)
        .build()

    OpenTelemetry.registerMeterProvider(meterProvider)
}
```

## Structured Logging

### Log Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| `trace` | Detailed trace information | Debugging specific issues |
| `debug` | Debug information | Development debugging |
| `info` | Informational messages | Normal operation |
| `warning` | Warning messages | Potential issues |
| `error` | Error messages | Errors requiring attention |
| `fatal` | Fatal errors | Application failure |

### Logging Usage

```swift
// In handlers
req.logger.info("Content entry created", metadata: [
    "contentType": "blog-posts",
    "entryId": entry.id!.uuidString,
    "userId": user.id!.uuidString
])

// Warning
req.logger.warning("Cache miss", metadata: [
    "key": cacheKey,
    "cacheHitRate": "0.65"
])

// Error
req.logger.error("Database query failed", metadata: [
    "error": error.localizedDescription,
    "query": "SELECT * FROM content_entries"
])
```

### Log Format

JSON log format:

```json
{
  "timestamp": "2024-02-14T10:30:45.123Z",
  "level": "info",
  "message": "Content entry created",
  "logger": "swiftcms.content",
  "metadata": {
    "contentType": "blog-posts",
    "entryId": "550e8400-e29b-41d4-a716-446655440000",
    "userId": "123e4567-e89b-12d3-a456-426614174000",
    "requestId": "abc123"
  },
  "service": {
    "name": "swiftcms",
    "version": "1.0.0"
  }
}
```

## Metrics Collection

### Built-in Metrics

SwiftCMS collects these metrics automatically:

#### HTTP Metrics

```prometheus
# Request count
http_requests_total{method="GET",path="/api/v1/content",status="200"} 1234

# Request duration
http_request_duration_seconds{method="GET",path="/api/v1/content",quantile="0.5"} 0.045
http_request_duration_seconds{method="GET",path="/api/v1/content",quantile="0.95"} 0.123

# Request size
http_request_size_bytes{method="POST",path="/api/v1/content"} 1024

# Response size
http_response_size_bytes{method="GET",path="/api/v1/content"} 8192
```

#### Database Metrics

```prometheus
# Query count
db_queries_total{type="select",table="content_entries"} 4567

# Query duration
db_query_duration_seconds{type="select",table="content_entries",quantile="0.5"} 0.002

# Connection pool
db_connections_active{pool="default"} 5
db_connections_idle{pool="default"} 10
db_connections_max{pool="default"} 20
```

#### Cache Metrics

```prometheus
# Cache hits/misses
cache_operations_total{operation="hit",cache="redis"} 1234
cache_operations_total{operation="miss",cache="redis"} 345

# Cache hit rate
cache_hit_rate{cache="redis"} 0.78

# Cache size
cache_size_bytes{cache="redis"} 256000000
cache_keys{cache="redis"} 1250
```

#### Business Metrics

```prometheus
# Content operations
content_operations_total{type="create",content_type="blog-posts"} 45
content_operations_total{type="update",content_type="blog-posts"} 123
content_operations_total{type="delete",content_type="blog-posts"} 12

# Active users
active_users_total{type="authenticated"} 45
active_users_total{type="anonymous"} 123
```

### Custom Metrics

Create custom metrics:

```swift
import OpenTelemetryMetrics

// Counter
let entryCreatedCounter = meter
    .createCounter(name: "content_entries_created_total")
    .with(description: "Total number of content entries created")

entryCreatedCounter.add(1, attributes: [
    "contentType": "blog-posts"
])

// Gauge
let activeConnectionsGauge = meter
    .createGauge(name: "websocket_connections_active")
    .with(description: "Number of active WebSocket connections")

activeConnectionsGauge.record(45)

// Histogram
let queryDurationHistogram = meter
    .createHistogram(name: "db_query_duration_seconds")
    .with(description: "Database query duration")

queryDurationHistogram.record(0.045, attributes: [
    "queryType": "select",
    "table": "content_entries"
])
```

### Metrics Endpoint

Access Prometheus metrics:

```bash
curl http://localhost:8080/metrics
```

Example output:

```prometheus
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/api/v1/content",status="200"} 1234

# HELP http_request_duration_seconds HTTP request duration
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",path="/api/v1/content",le="0.005"} 100
http_request_duration_seconds_bucket{method="GET",path="/api/v1/content",le="0.01"} 200
http_request_duration_seconds_bucket{method="GET",path="/api/v1/content",le="0.025"} 400
http_request_duration_seconds_bucket{method="GET",path="/api/v1/content",le="+Inf"} 500
http_request_duration_seconds_sum{method="GET",path="/api/v1/content"} 5.5
http_request_duration_seconds_count{method="GET",path="/api/v1/content"} 500
```

## Distributed Tracing

### Trace Propagation

Traces are automatically propagated across services:

```swift
// Incoming request
let span = tracer.spanBuilder(spanName: "GET /api/v1/content")
    .setParent(req.headers["X-Trace-Parent"])
    .startSpan()

span.setAttribute("http.method", "GET")
span.setAttribute("http.path", "/api/v1/content")
span.setAttribute("user.id", user.id!.uuidString)

// Outgoing request (database)
let dbSpan = tracer.spanBuilder(spanName: "db.query")
    .setParent(span.context)
    .startSpan()

dbSpan.setAttribute("db.type", "postgresql")
dbSpan.setAttribute("db.table", "content_entries")
dbSpan.setAttribute("db.operation", "select")

// Execute query
let results = try await ContentEntry.query(on: req.db).all()

dbSpan.end()
span.end()
```

### Trace Visualization

View traces in Jaeger:

```
http://localhost:16686/search
```

Example trace:

```
GET /api/v1/content (123ms)
├── Authentication (15ms)
├── Authorization (10ms)
├── Cache Lookup (5ms)
├── Database Query (45ms)
│   ├── Connection (5ms)
│   ├── Query Execution (35ms)
│   └── Result Mapping (5ms)
├── Response Serialization (20ms)
└── Response (28ms)
```

### Trace Context

Trace context is included in logs:

```json
{
  "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
  "spanId": "00f067aa0ba902b7",
  "message": "Database query executed",
  "metadata": {
    "query": "SELECT * FROM content_entries",
    "rows": 10
  }
}
```

## Health Checks

### Health Endpoint

Check application health:

```bash
curl http://localhost:8080/healthz
```

Response:

```json
{
  "status": "healthy",
  "timestamp": "2024-02-14T10:30:45Z",
  "checks": {
    "database": {
      "status": "healthy",
      "latency_ms": 5
    },
    "redis": {
      "status": "healthy",
      "latency_ms": 1
    },
    "meilisearch": {
      "status": "healthy",
      "latency_ms": 10
    }
  }
}
```

### Readiness Endpoint

Check if application is ready to accept traffic:

```bash
curl http://localhost:8080/ready
```

Response:

```json
{
  "ready": true,
  "checks": {
    "database_connected": true,
    "cache_connected": true,
    "migrations_run": true
  }
}
```

### Liveness Endpoint

Check if application is alive:

```bash
curl http://localhost:8080/live
```

Response:

```json
{
  "alive": true,
  "uptime_seconds": 3600
}
```

## Error Tracking

### Automatic Error Reporting

Errors are automatically tracked:

```swift
// In Vapor error middleware
app.middleware.use(ErrorMiddleware.default(environment: app.environment))

// Errors are logged with context
req.logger.error("Request failed", metadata: [
    "error": error.localizedDescription,
    "stackTrace": error.stackTrace,
    "requestId": req.id.uuidString
])
```

### Error Aggregation

Errors are aggregated by type:

```json
{
  "errors": {
    "total": 45,
    "byType": {
      "ValidationError": 20,
      "NotFoundError": 15,
      "DatabaseError": 5,
      "AuthenticationError": 3,
      "AuthorizationError": 2
    }
  }
}
```

### Alerting

Configure alerting rules:

```yaml
# Prometheus alerting rules
groups:
  - name: swiftcms
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"

      - alert: HighLatency
        expr: histogram_quantile(0.95, http_request_duration_seconds) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High request latency"
```

## Monitoring Dashboards

### Grafana Dashboard

Import the SwiftCMS Grafana dashboard:

```json
{
  "title": "SwiftCMS Overview",
  "panels": [
    {
      "title": "Request Rate",
      "targets": [
        {
          "expr": "rate(http_requests_total[5m])"
        }
      ]
    },
    {
      "title": "Error Rate",
      "targets": [
        {
          "expr": "rate(http_requests_total{status=~\"5..\"}[5m])"
        }
      ]
    },
    {
      "title": "Response Time",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, http_request_duration_seconds)"
        }
      ]
    },
    {
      "title": "Cache Hit Rate",
      "targets": [
        {
          "expr": "cache_hit_rate"
        }
      ]
    }
  ]
}
```

## Performance Optimization

### Monitor Slow Queries

Identify slow database queries:

```swift
let queryStart = Date()

let results = try await ContentEntry.query(on: db).all()

let queryDuration = Date().timeIntervalSince(queryStart)

if queryDuration > 1.0 {
    req.logger.warning("Slow query detected", metadata: [
        "query": "SELECT * FROM content_entries",
        "duration": "\(queryDuration)s"
    ])
}
```

### Monitor N+1 Queries

Detect N+1 query problems:

```swift
// Bad: N+1 queries
for entry in entries {
    let author = try await entry.author.get(on: db)  // Query per entry
}

// Good: Eager loading
let entries = try await ContentEntry.query(on: db)
    .with(\.$author)  // Single query
    .all()
```

### Memory Profiling

Monitor memory usage:

```swift
let memoryInfo = MemoryInfo()
req.logger.info("Memory usage", metadata: [
    "used": "\(memoryInfo.used)",
    "total": "\(memoryInfo.total)",
    "percentage": "\(memoryInfo.usagePercentage)"
])
```

## Best Practices

### 1. Use Appropriate Log Levels

- `debug`: Development only
- `info`: Important operations
- `warning`: Potential issues
- `error`: Actual errors

### 2. Include Context

Add relevant context to logs:

```swift
// Good
req.logger.info("Content created", metadata: [
    "contentType": "blog-posts",
    "entryId": entry.id!.uuidString,
    "userId": user.id!.uuidString
])

// Bad
req.logger.info("Content created")
```

### 3. Don't Log Sensitive Data

Avoid logging sensitive information:

```swift
// Bad
req.logger.info("User logged in", metadata: [
    "password": user.password  // Never log passwords!
])

// Good
req.logger.info("User logged in", metadata: [
    "userId": user.id!.uuidString
])
```

### 4. Use Structured Logging

Use structured data, not strings:

```swift
// Good
req.logger.info("User action", metadata: [
    "action": "create",
    "resource": "content",
    "resourceId": entry.id!.uuidString
])

// Bad
req.logger.info("User created content entry \(entry.id!)")
```

### 5. Monitor Key Metrics

Track these key metrics:

- Request rate and latency
- Error rate
- Cache hit rate
- Database query performance
- Resource usage (CPU, memory)

## Troubleshooting

### High Memory Usage

**Symptoms**: Memory usage continuously increasing

**Diagnosis**:
1. Check memory metrics
2. Review logs for memory warnings
3. Profile memory allocation

**Solutions**:
1. Fix memory leaks
2. Implement connection pooling
3. Add cache size limits
4. Review resource cleanup

### Slow Response Times

**Symptoms**: High request latency

**Diagnosis**:
1. Check response time metrics
2. Review traces for slow spans
3. Check database query performance

**Solutions**:
1. Optimize database queries
2. Add caching
3. Implement pagination
4. Use CDN for static assets

### High Error Rate

**Symptoms**: Increased error rate

**Diagnosis**:
1. Check error logs
2. Review error aggregation
3. Check health endpoints

**Solutions**:
1. Fix identified errors
2. Add proper error handling
3. Implement circuit breakers
4. Add retries for transient failures

## Additional Resources

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Grafana Dashboards](https://grafana.com/docs/grafana/latest/dashboards/)
- [Vapor Logging](https://docs.vapor.codes/advanced/logging/)
