import Vapor
import CMSObjects
import Fluent
import Foundation

/// 🌐 **Distributed Tracing Middleware**
///
/// Vapor middleware that automatically creates and manages spans for all HTTP requests.
/// Instruments incoming requests, database operations, and external calls.
/// Integrates with TelemetryManager for comprehensive observability.
///
/// ## Features
/// - Automatic span creation for each HTTP request
/// - W3C and Jaeger context propagation from incoming headers
/// - Standard HTTP attribute collection (method, URL, status, etc.)
/// - Automatic metric recording (requests, errors, durations)
/// - Child spans for nested operations (database, cache, external calls)
///
/// ## Usage
/// ```swift
/// // Register in configure.swift
/// let telemetry = TelemetryManager(...)
/// app.telemetry = telemetry
/// app.middleware.use(TracingMiddleware(telemetry: telemetry))
///```
///
/// ## HTTP Attributes Collected
/// - `http.method`: GET, POST, PUT, DELETE, etc.
/// - `http.url`: Full request URL
/// - `http.scheme`: http or https
/// - `http.host`: Hostname
/// - `http.target`: Request path
/// - `http.user_agent`: Client user agent
/// - `net.peer.ip`: Client IP address
/// - `cms.tenant_id`: Multi-tenant identifier
/// - `http.status_code`: Response status code
public struct TracingMiddleware: AsyncMiddleware, Sendable {
    /// The telemetry manager for span and metric operations
    private let telemetry: TelemetryManager

    /// 🧰 **Initialize Tracing Middleware**
    ///
    /// Creates a new tracing middleware instance.
    ///
    /// - Parameter telemetry: TelemetryManager instance for span creation
    public init(telemetry: TelemetryManager) {
        self.telemetry = telemetry
    }

    /// 🌐 **Middleware Response Handler**
    ///
    /// Intercepts each HTTP request, creates a server span, and instruments the full lifecycle.
    /// Extracts trace context from headers, collects attributes, records metrics,
    /// and propagates context to response headers.
    ///
    /// - Parameters:
    ///   - request: Incoming HTTP request
    ///   - next: Next responder in middleware chain
    /// - Returns: HTTP response with tracing headers
    /// - Throws: Any errors from the request handler
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Extract parent context from incoming headers
        let parentContext = await telemetry.extractContext(from: request.headers)

        // Create a span for this request
        let spanName = "\(request.method.rawValue) \(request.url.path)"
        let span = await telemetry.createSpan(
            name: spanName,
            kind: .server,
            parentContext: parentContext
        )

        // Store span in request for use in handlers
        request.currentSpan = span
        request.spanContext = span.context

        // Set standard HTTP attributes
        span.setAttribute("http.method", value: request.method.rawValue)
        span.setAttribute("http.url", value: request.url.string)
        span.setAttribute("http.scheme", value: request.url.scheme ?? "http")
        span.setAttribute("http.host", value: request.url.host ?? "unknown")
        span.setAttribute("http.target", value: request.url.path)

        // Extract and set user agent
        if let userAgent = request.headers.first(name: "user-agent") {
            span.setAttribute("http.user_agent", value: userAgent)
        }

        // Extract and set client IP
        if let clientIP = request.headers.first(name: "x-forwarded-for") ?? request.remoteAddress?.description {
            span.setAttribute("net.peer.ip", value: clientIP)
        }

        // Extract tenant ID if multi-tenant
        if let tenantId = request.headers.first(name: "X-Tenant-ID") {
            span.setAttribute("cms.tenant_id", value: tenantId)
        }

        // Inject trace context into response headers
        var responseHeaders = HTTPHeaders()
        await telemetry.injectContext(span.context, into: &responseHeaders)

        let startTime = Date()

        do {
            // Execute the request
            let response = try await next.respond(to: request)

            // Record response attributes
            let duration = Date().timeIntervalSince(startTime)
            span.setAttribute("http.status_code", value: Int(response.status.code))
            span.setAttribute("http.response_time_ms", value: duration * 1000)

            // Set span status based on response
            if response.status.code >= 400 {
                span.setStatus(.error(description: "HTTP \(response.status.code)"))
            } else {
                span.setStatus(.ok)
            }

            // Inject trace context into response
            response.headers.replaceOrAdd(name: "traceparent", value: responseHeaders.first(name: "traceparent") ?? "")
            response.headers.replaceOrAdd(name: "X-Trace-Id", value: span.context.traceId)

            // Record HTTP metrics
            await telemetry.recordCounter(
                "http.requests.total",
                value: 1.0,
                attributes: [
                    "http.method": .string(request.method.rawValue),
                    "http.status_code": .string(String(response.status.code)),
                    "http.route": .string(request.url.path)
                ]
            )

            await telemetry.recordGauge(
                "http.request.duration_ms",
                value: duration * 1000,
                attributes: [
                    "http.method": .string(request.method.rawValue),
                    "http.route": .string(request.url.path)
                ]
            )

            // Count errors
            if response.status.code >= 400 {
                await telemetry.recordCounter(
                    "http.errors.total",
                    value: 1.0,
                    attributes: [
                        "http.method": .string(request.method.rawValue),
                        "http.status_code": .string(String(response.status.code))
                    ]
                )
            }

            // End the span
            await telemetry.endSpan(span)

            return response

        } catch {
            // Record error attributes
            let duration = Date().timeIntervalSince(startTime)
            span.recordError(error)
            span.setAttribute("http.response_time_ms", value: duration * 1000)

            // Record error metrics
            await telemetry.recordCounter(
                "http.errors.total",
                value: 1.0,
                attributes: [
                    "http.method": .string(request.method.rawValue),
                    "error.type": .string(String(describing: type(of: error)))
                ]
            )

            // End the span
            await telemetry.endSpan(span)

            throw error
        }
    }
}

/// 🔍 **Operation Tracer Helper**
///
/// Simplified interface for creating child spans within request handlers.
/// Provides convenient methods for tracing operations without direct telemetry access.
///
/// ## Usage
/// ```swift
/// let tracer = Tracer(request: req)
///
/// // Create child span
/// let span = await tracer.span("process-payment", kind: .internal)
///
/// // Trace operation with automatic timing
/// let result = try await tracer.trace("fetch-user") { span in
///     return try await fetchUser()
/// }
///```
public struct Tracer: Sendable {
    /// The request being traced
    private let request: Request

    /// 🧰 **Initialize Tracer**
    ///
    /// Creates a tracer for the given request.
    /// Ensures child spans inherit parent's trace context.
    ///
    /// - Parameter request: The request context
    public init(request: Request) {
        self.request = request
    }

    /// ➕ **Create Child Span**
    ///
    /// Creates a child span for an operation within the current request.
    /// Inherits trace context from the request's current span.
    ///
    /// - Parameters:
    ///   - name: Span name
    ///   - kind: Span kind (default: .internal)
    /// - Returns: New child span or nil if telemetry unavailable
    public func span(_ name: String, kind: SpanKind = .internal) async -> TelemetrySpan? {
        guard let telemetry = request.application.telemetry else {
            return nil
        }

        let parentContext = request.currentSpan?.context ?? request.spanContext
        let span = await telemetry.createSpan(
            name: name,
            kind: kind,
            parentContext: parentContext
        )

        return span
    }

    /// 🔄 **Trace Operation**
    ///
    /// Executes a block with automatic span lifecycle management.
    /// Creates span, records timing, handles errors, and ends span automatically.
    ///
    /// - Parameters:
    ///   - name: Span name
    ///   - kind: Span kind (default: .internal)
    ///   - operation: Async closure to trace with optional span access
    /// - Returns: Result from the operation
    /// - Throws: Any errors from the operation
    public func trace<T>(_ name: String, kind: SpanKind = .internal, operation: @Sendable (TelemetrySpan?) async throws -> T) async throws -> T {
        let span = await span(name, kind: kind)

        let startTime = Date()
        do {
            let result = try await operation(span)
            let duration = Date().timeIntervalSince(startTime)

            span?.setAttribute("success", value: true)
            span?.setAttribute("duration_ms", value: duration * 1000)

            if let span = span {
                await request.application.telemetry?.endSpan(span)
            }

            return result
        } catch {
            span?.recordError(error)
            if let span = span {
                await request.application.telemetry?.endSpan(span)
            }
            throw error
        }
    }
}

extension Request {
    /// 🔍 **Request Tracer Access**
    ///
    /// Convenience property to get a tracer instance for this request.
    /// Creates a new Tracer instance each time (lightweight).
    public var tracer: Tracer {
        Tracer(request: self)
    }
}

// MARK: - Database Tracing Extensions

extension Database {
    /// 🔍 **Trace Database Operation**
    ///
    /// Wraps database operations with automatic tracing and timing.
    /// Records operation type, duration, and handles errors appropriately.
    ///
    /// - Parameters:
    ///   - operation: SQL operation name (e.g., "SELECT", "INSERT")
    ///   - request: Current request for span context
    ///   - block: Database operation to trace
    /// - Returns: Result from database operation
    /// - Throws: Database errors wrapped with trace context
    public func trace<T>(
        _ operation: String,
        on request: Request,
        block: @Sendable () async throws -> T
    ) async throws -> T {
        let span = await request.tracer.span("db.\(operation)", kind: .internal)
        span?.setAttribute("db.system", value: "sql")
        span?.setAttribute("db.operation", value: operation)

        let startTime = Date()
        do {
            let result = try await block()

            span?.setAttribute("db.rows_affected", value: 1)
            span?.setStatus(.ok)

            let duration = Date().timeIntervalSince(startTime)
            await request.application.telemetry?.recordGauge(
                "db.query.duration_ms",
                value: duration * 1000,
                attributes: ["db.operation": .string(operation)]
            )

            if let span = span {
                await request.application.telemetry?.endSpan(span)
            }

            return result
        } catch {
            span?.recordError(error)
            if let span = span {
                await request.application.telemetry?.endSpan(span)
            }
            throw error
        }
    }
}

// MARK: - Cache Tracing Extensions

extension Request {
    /// 🔍 **Trace Cache Operation**
    ///
    /// Wraps cache operations (Redis, internal cache) with automatic tracing.
    /// Records hit/miss rates, operation type, and performance.
    ///
    /// - Parameters:
    ///   - operation: Cache operation (get, set, delete, etc.)
    ///   - key: Cache key being operated on
    ///   - block: Cache operation to trace
    /// - Returns: Cached value or nil (get operations)
    /// - Throws: Cache errors wrapped with trace context
    public func traceCache<T>(
        _ operation: String,
        key: String,
        block: @Sendable () async throws -> T?
    ) async throws -> T? {
        let span = await tracer.span("cache.\(operation)", kind: .internal)
        span?.setAttribute("cache.operation", value: operation)
        span?.setAttribute("cache.key", value: key)

        let startTime = Date()
        do {
            let result = try await block()

            span?.setAttribute("cache.hit", value: result != nil)

            await application.telemetry?.recordCounter(
                "cache.operations.total",
                value: 1.0,
                attributes: [
                    "cache.operation": .string(operation),
                    "cache.hit": .string(result != nil ? "true" : "false")
                ]
            )

            if let span = span {
                await application.telemetry?.endSpan(span)
            }

            return result
        } catch {
            span?.recordError(error)
            if let span = span {
                await application.telemetry?.endSpan(span)
            }
            throw error
        }
    }
}

// MARK: - GraphQL Tracing Extensions

extension Request {
    /// 🔍 **Trace GraphQL Query**
    ///
    /// Instruments GraphQL query execution with comprehensive tracing.
    /// Sanitizes and truncates queries for safe logging.
    ///
    /// - Parameters:
    ///   - operation: GraphQL operation type (query, mutation, subscription)
    ///   - query: The GraphQL query/mutation string
    ///   - block: GraphQL execution to trace
    /// - Returns: Query execution result
    /// - Throws: GraphQL errors wrapped with trace context
    public func traceGraphQL<T>(
        operation: String,
        query: String,
        block: @Sendable () async throws -> T
    ) async throws -> T {
        let span = await tracer.span("graphql.query", kind: .server)
        span?.setAttribute("graphql.operation.type", value: operation)

        // Sanitize and truncate query for attributes
        let sanitizedQuery = query.prefix(1000).replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        span?.setAttribute("graphql.query", value: String(sanitizedQuery))

        let startTime = Date()
        do {
            let result = try await block()

            let duration = Date().timeIntervalSince(startTime)
            await application.telemetry?.recordCounter(
                "graphql.queries.total",
                value: 1.0,
                attributes: ["graphql.operation.type": .string(operation)]
            )

            await application.telemetry?.recordGauge(
                "graphql.query.duration_ms",
                value: duration * 1000,
                attributes: ["graphql.operation.type": .string(operation)]
            )

            if let span = span {
                await application.telemetry?.endSpan(span)
            }

            return result
        } catch {
            span?.recordError(error)
            if let span = span {
                await application.telemetry?.endSpan(span)
            }
            throw error
        }
    }
}

// MARK: - Content CRUD Tracing Extensions

extension Request {
    /// 🔍 **Trace Content Operation**
    ///
    /// Instruments CMS content operations (create, read, update, delete).
    /// Records content type, operation type, and performance metrics.
    ///
    /// - Parameters:
    ///   - operation: CRUD operation type
    ///   - contentType: Content type identifier
    ///   - entryId: Optional content entry ID
    ///   - block: Content operation to trace
    /// - Returns: Operation result
    /// - Throws: Content operation errors wrapped with trace context
    public func traceContent<T>(
        operation: String,
        contentType: String,
        entryId: String? = nil,
        block: @Sendable () async throws -> T
    ) async throws -> T {
        let span = await tracer.span("content.\(operation)", kind: .server)
        span?.setAttribute("cms.content_type", value: contentType)
        span?.setAttribute("cms.operation", value: operation)

        if let entryId = entryId {
            span?.setAttribute("cms.entry_id", value: entryId)
        }

        let startTime = Date()
        do {
            let result = try await block()

            let duration = Date().timeIntervalSince(startTime)
            await application.telemetry?.recordCounter(
                "cms.content.operations.total",
                value: 1.0,
                attributes: [
                    "cms.operation": .string(operation),
                    "cms.content_type": .string(contentType)
                ]
            )

            await application.telemetry?.recordGauge(
                "cms.content.operation.duration_ms",
                value: duration * 1000,
                attributes: [
                    "cms.operation": .string(operation),
                    "cms.content_type": .string(contentType)
                ]
            )

            if let span = span {
                await application.telemetry?.endSpan(span)
            }

            return result
        } catch {
            span?.recordError(error)
            if let span = span {
                await application.telemetry?.endSpan(span)
            }
            throw error
        }
    }
}

// MARK: - Health Check Extensions

extension TelemetryManager {
    /// ❤️ **Health Check Response Builder**
    ///
    /// Creates a health check response including telemetry system status.
    /// Useful for monitoring endpoints and diagnostics dashboards.
    ///
    /// - Returns: Health check response dictionary
    public func healthCheckResponse() -> TelemetryHealthCheckResponse {
        let status = getHealthStatus()
        return TelemetryHealthCheckResponse(
            exporter: status.exporter,
            healthy: status.isHealthy,
            activeSpans: status.activeSpans,
            pendingSpans: status.completedSpans,
            pendingMetrics: status.metrics,
            samplingRate: samplingRate,
            metricsEnabled: exportMetrics
        )
    }
}

/// 📋 **Detailed Health Check Response**
///
/// Comprehensive health check response including telemetry configuration.
/// Used by health check endpoints and monitoring tools.
public struct TelemetryHealthCheckResponse: Sendable, Content {
    public let exporter: String
    public let healthy: Bool
    public let activeSpans: Int
    public let pendingSpans: Int
    public let pendingMetrics: Int
    public let samplingRate: Double
    public let metricsEnabled: Bool

    public init(
        exporter: String,
        healthy: Bool,
        activeSpans: Int,
        pendingSpans: Int,
        pendingMetrics: Int,
        samplingRate: Double,
        metricsEnabled: Bool
    ) {
        self.exporter = exporter
        self.healthy = healthy
        self.activeSpans = activeSpans
        self.pendingSpans = pendingSpans
        self.pendingMetrics = pendingMetrics
        self.samplingRate = samplingRate
        self.metricsEnabled = metricsEnabled
    }
}
