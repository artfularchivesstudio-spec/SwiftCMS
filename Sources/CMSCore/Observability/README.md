# SwiftCMS Observability

This module provides OpenTelemetry-compatible distributed tracing and metrics collection for SwiftCMS.

## Features

- **Distributed Tracing**: Automatic span creation for HTTP requests with W3C Trace Context support
- **Custom Spans**: Create child spans for database queries, cache operations, GraphQL queries, and content CRUD operations
- **Metrics Collection**: Request count, latency, error tracking
- **Multiple Exporters**: Console, OTLP, Jaeger (extensible)
- **Health Monitoring**: `/health/telemetry` endpoint for telemetry status

## Configuration

Configure telemetry via environment variables:

```bash
# Enable telemetry and set exporter (console, otlp, jaeger, none)
OTEL_EXPORTER=console

# Service identification
OTEL_SERVICE_NAME=swiftcms
OTEL_SERVICE_VERSION=1.0.0

# Exporter endpoints
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
OTEL_EXPORTER_JAEGER_ENDPOINT=http://localhost:14268/api/traces

# Sampling and metrics
OTEL_SAMPLING_RATE=1.0
OTEL_METRICS_ENABLED=true
OTEL_BATCH_INTERVAL=5.0
```

## Usage

### Automatic HTTP Tracing

The `TracingMiddleware` automatically creates spans for all HTTP requests:

```swift
// In configure.swift
if let telemetry = app.cms.telemetry {
    app.middleware.use(TracingMiddleware(telemetry: telemetry))
}
```

### Manual Span Creation

Create child spans within request handlers:

```swift
app.get("api", "content") { req async throws -> [ContentEntry] in
    try await req.tracer.trace("content.list") { span in
        // Your code here
        let entries = try await ContentEntry.query(on: req.db).all()
        return entries
    }
}
```

### Database Tracing

```swift
let entries = try await req.db.trace("content_entries.find", on: req) {
    try await ContentEntry.query(on: req.db).all()
}
```

### GraphQL Tracing

```swift
let result = try await req.traceGraphQL(operation: "query", query: graphqlQuery) {
    try await executeGraphQL(query)
}
```

### Content CRUD Tracing

```swift
let entry = try await req.traceContent(
    operation: "create",
    contentType: "posts"
) {
    try await ContentEntryService.create(...)
}
```

### Manual Metrics

```swift
await req.application.telemetry?.recordCounter(
    "custom.operations.total",
    value: 1.0,
    attributes: ["operation": .string("export")]
)

await req.application.telemetry?.recordGauge(
    "custom.queue.size",
    value: Double(queue.count)
)
```

## Trace Context Propagation

The system automatically:
- Extracts trace context from incoming requests (W3C Trace Context, Jaeger headers)
- Injects trace context into outgoing requests and responses
- Maintains trace parent-child relationships across async boundaries

## Health Check

Check telemetry status:

```bash
curl http://localhost:8080/health/telemetry
```

Response:
```json
{
  "exporter": "console",
  "healthy": true,
  "activeSpans": 5,
  "pendingSpans": 12,
  "pendingMetrics": 8,
  "samplingRate": 1.0,
  "metricsEnabled": true
}
```

## Architecture

### Core Components

- **TelemetryManager**: Actor that manages spans and metrics
- **TracingMiddleware**: Vapor middleware for automatic HTTP tracing
- **TelemetrySpan**: Represents a single tracing operation
- **Metric**: Represents a metric measurement

### Span Lifecycle

1. Create span with parent context (if available)
2. Set attributes and events
3. End span (automatically exports on next batch)

### Thread Safety

All operations are thread-safe using:
- Actor isolation for TelemetryManager
- NSLock for span state access
- @unchecked Sendable for TelemetrySpan (locks ensure safety)

## Future Enhancements

- Full OTLP HTTP/JSON export implementation
- Jaeger Thrift export implementation
- Span batching and compression
- Metric aggregation and histograms
- Distributed context propagation across services
- Integration with Swift OpenTelemetry SDK when available

## Notes

This is a simplified OpenTelemetry implementation designed for Swift 6.1+ async/await patterns. It provides the core tracing functionality needed for observability without requiring external OpenTelemetry SDK dependencies, which are still maturing in the Swift ecosystem.
