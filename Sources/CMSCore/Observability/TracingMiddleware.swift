import Vapor
import CMSObjects
import Fluent
import Foundation

/// Middleware that automatically creates and manages spans for HTTP requests.
public struct TracingMiddleware: AsyncMiddleware, Sendable {
    /// The telemetry manager.
    private let telemetry: TelemetryManager

    /// Create a new tracing middleware.
    public init(telemetry: TelemetryManager) {
        self.telemetry = telemetry
    }

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

/// Tracing helper for creating child spans within request handlers.
public struct Tracer: Sendable {
    /// The request being traced.
    private let request: Request

    /// Create a tracer for the given request.
    public init(request: Request) {
        self.request = request
    }

    /// Create a child span for an operation.
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

    /// Execute a block with tracing.
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
    /// Get a tracer for creating child spans.
    public var tracer: Tracer {
        Tracer(request: self)
    }
}

// MARK: - Database Tracing Helpers

extension Database {
    /// Trace a database query.
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

// MARK: - Cache Tracing Helpers

extension Request {
    /// Trace a cache operation.
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

// MARK: - GraphQL Tracing Helpers

extension Request {
    /// Trace a GraphQL query.
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

// MARK: - Content CRUD Tracing Helpers

extension Request {
    /// Trace a content CRUD operation.
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

// MARK: - Health Check Endpoint

extension TelemetryManager {
    /// Create a health check response for telemetry.
    public func healthCheckResponse() -> [String: Any] {
        let status = getHealthStatus()
        return [
            "telemetry": [
                "exporter": status.exporter,
                "healthy": status.isHealthy,
                "active_spans": status.activeSpans,
                "pending_spans": status.completedSpans,
                "pending_metrics": status.metrics,
                "sampling_rate": 1.0,
                "metrics_enabled": true
            ]
        ]
    }
}
