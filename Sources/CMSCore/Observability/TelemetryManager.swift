import Vapor
import Fluent
import CMSObjects
import Foundation

/// Telemetry configuration for OpenTelemetry integration.
public struct TelemetryConfiguration: Sendable {
    /// The service name for tracing.
    public var serviceName: String

    /// The service version.
    public var serviceVersion: String

    /// The exporter type to use.
    public var exporter: ExporterType

    /// OTLP endpoint URL.
    public var otlpEndpoint: String?

    /// Jaeger endpoint URL.
    public var jaegerEndpoint: String?

    /// Whether to export metrics.
    public var exportMetrics: Bool

    /// Sampling rate (0.0 to 1.0).
    public var samplingRate: Double

    /// Batch export interval in milliseconds.
    public var batchInterval: TimeInterval

    public enum ExporterType: String, Sendable {
        case console
        case otlp
        case jaeger
        case none
    }

    public init(
        serviceName: String = "swiftcms",
        serviceVersion: String = "1.0.0",
        exporter: ExporterType = .console,
        otlpEndpoint: String? = nil,
        jaegerEndpoint: String? = nil,
        exportMetrics: Bool = true,
        samplingRate: Double = 1.0,
        batchInterval: TimeInterval = 5.0
    ) {
        self.serviceName = serviceName
        self.serviceVersion = serviceVersion
        self.exporter = exporter
        self.otlpEndpoint = otlpEndpoint
        self.jaegerEndpoint = jaegerEndpoint
        self.exportMetrics = exportMetrics
        self.samplingRate = samplingRate
        self.batchInterval = batchInterval
    }

    /// Create configuration from environment variables.
    public static func fromEnvironment() -> TelemetryConfiguration {
        let exporterString = Environment.get("OTEL_EXPORTER") ?? "console"
        let exporter: ExporterType
        switch exporterString.lowercased() {
        case "otlp": exporter = .otlp
        case "jaeger": exporter = .jaeger
        case "none": exporter = .none
        default: exporter = .console
        }

        return TelemetryConfiguration(
            serviceName: Environment.get("OTEL_SERVICE_NAME") ?? "swiftcms",
            serviceVersion: Environment.get("OTEL_SERVICE_VERSION") ?? "1.0.0",
            exporter: exporter,
            otlpEndpoint: Environment.get("OTEL_EXPORTER_OTLP_ENDPOINT"),
            jaegerEndpoint: Environment.get("OTEL_EXPORTER_JAEGER_ENDPOINT"),
            exportMetrics: Environment.get("OTEL_METRICS_ENABLED")?.lowercased() == "true",
            samplingRate: Double(Environment.get("OTEL_SAMPLING_RATE") ?? "1.0") ?? 1.0,
            batchInterval: Double(Environment.get("OTEL_BATCH_INTERVAL") ?? "5.0") ?? 5.0
        )
    }
}

/// Span kind for different operation types.
public enum SpanKind: String, Sendable {
    case server
    case client
    case producer
    case consumer
    case `internal`
}

/// A telemetry span representing an operation.
public final class TelemetrySpan: @unchecked Sendable {
    /// The span context containing trace and span IDs.
    public let context: SpanContext

    /// The span name.
    public let name: String

    /// The span kind.
    public let kind: SpanKind

    /// The start time.
    public let startTime: Date

    /// The end time (nil if span is active).
    private var _endTime: Date?

    /// Thread-safe access to end time.
    private let endTimeLock = NSLock()

    public var endTime: Date? {
        endTimeLock.lock()
        defer { endTimeLock.unlock() }
        return _endTime
    }

    /// Span attributes.
    private var _attributes: [String: AnyCodableValue]

    /// Thread-safe access to attributes.
    private let attributesLock = NSLock()

    public var attributes: [String: AnyCodableValue] {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        return _attributes
    }

    /// Span events.
    private var _events: [SpanEvent]

    /// Thread-safe access to events.
    private let eventsLock = NSLock()

    public var events: [SpanEvent] {
        eventsLock.lock()
        defer { eventsLock.unlock() }
        return _events
    }

    /// Parent span context.
    public let parentContext: SpanContext?

    /// The status of the span.
    private var _status: SpanStatus

    /// Thread-safe access to status.
    private let statusLock = NSLock()

    public var status: SpanStatus {
        statusLock.lock()
        defer { statusLock.unlock() }
        return _status
    }

    init(
        name: String,
        kind: SpanKind = .internal,
        parentContext: SpanContext? = nil,
        traceId: String? = nil,
        spanId: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.parentContext = parentContext
        self.startTime = Date()
        self._attributes = [:]
        self._events = []
        self._status = .unset

        let traceIdValue = traceId ?? parentContext?.traceId ?? UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let spanIdValue = spanId ?? UUID().uuidString.prefix(16).description

        self.context = SpanContext(
            traceId: traceIdValue,
            spanId: spanIdValue,
            traceFlags: 1
        )
    }

    /// Set an attribute on the span.
    public func setAttribute(_ key: String, value: String) {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        _attributes[key] = .string(value)
    }

    /// Set an attribute on the span.
    public func setAttribute(_ key: String, value: Int) {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        _attributes[key] = .int(value)
    }

    /// Set an attribute on the span.
    public func setAttribute(_ key: String, value: UInt) {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        _attributes[key] = .int(Int(value))
    }

    /// Set an attribute on the span.
    public func setAttribute(_ key: String, value: Double) {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        _attributes[key] = .double(value)
    }

    /// Set an attribute on the span.
    public func setAttribute(_ key: String, value: Bool) {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        _attributes[key] = .bool(value)
    }

    /// Add an event to the span.
    public func addEvent(_ name: String, attributes: [String: AnyCodableValue] = [:]) {
        eventsLock.lock()
        defer { eventsLock.unlock() }
        _events.append(SpanEvent(name: name, timestamp: Date(), attributes: attributes))
    }

    /// Set the span status.
    public func setStatus(_ status: SpanStatus) {
        statusLock.lock()
        defer { statusLock.unlock() }
        _status = status
    }

    /// Record an error in the span.
    public func recordError(_ error: Error) {
        setStatus(.error(description: error.localizedDescription))
        addEvent("exception", attributes: [
            "exception.message": .string(error.localizedDescription),
            "exception.type": .string(String(describing: type(of: error)))
        ])
    }

    /// End the span.
    public func end() {
        endTimeLock.lock()
        defer { endTimeLock.unlock() }
        if _endTime == nil {
            _endTime = Date()
        }
    }

    /// Get the duration of the span.
    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
}

/// Context for a span containing trace and span IDs.
public struct SpanContext: Sendable, Codable {
    /// The trace ID (16-byte hex string).
    public let traceId: String

    /// The span ID (8-byte hex string).
    public let spanId: String

    /// Trace flags.
    public let traceFlags: Int
}

/// A span event.
public struct SpanEvent: Sendable {
    public let name: String
    public let timestamp: Date
    public let attributes: [String: AnyCodableValue]
}

/// Span status.
public enum SpanStatus: Sendable {
    case unset
    case ok
    case error(description: String)
}

/// A metric measurement.
public struct Metric: Sendable {
    public let name: String
    public let value: Double
    public let attributes: [String: AnyCodableValue]
    public let timestamp: Date

    public init(name: String, value: Double, attributes: [String: AnyCodableValue] = [:]) {
        self.name = name
        self.value = value
        self.attributes = attributes
        self.timestamp = Date()
    }
}

/// Telemetry manager for distributed tracing and metrics.
public actor TelemetryManager {
    /// The configuration.
    private let configuration: TelemetryConfiguration

    /// Active spans keyed by span ID.
    private var activeSpans: [String: TelemetrySpan]

    /// Completed spans ready for export.
    private var completedSpans: [TelemetrySpan]

    /// Metrics ready for export.
    private var metrics: [Metric]

    /// The logger.
    private let logger: Logger

    /// Background task for batch export.
    private var exportTask: Task<Void, Never>?

    public init(configuration: TelemetryConfiguration, logger: Logger) {
        self.configuration = configuration
        self.activeSpans = [:]
        self.completedSpans = []
        self.metrics = []
        self.logger = logger
        self.exportTask = nil

        // Start background export task after initialization
        Task {
            await self.startExportLoop()
        }
    }

    private func startExportLoop() {
        guard exportTask == nil else { return }
        exportTask = Task {
            await exportLoop()
        }
    }

    /// Create a new span.
    public func createSpan(
        name: String,
        kind: SpanKind = .internal,
        parentContext: SpanContext? = nil
    ) -> TelemetrySpan {
        let span = TelemetrySpan(
            name: name,
            kind: kind,
            parentContext: parentContext
        )

        // Apply sampling
        if configuration.samplingRate >= 1.0 || Double.random(in: 0...1) <= configuration.samplingRate {
            activeSpans[span.context.spanId] = span
        }

        return span
    }

    /// End a span and mark it for export.
    public func endSpan(_ span: TelemetrySpan) {
        span.end()
        if activeSpans.removeValue(forKey: span.context.spanId) != nil {
            completedSpans.append(span)
        }
    }

    /// Record a metric.
    public func recordMetric(_ metric: Metric) {
        if configuration.exportMetrics {
            metrics.append(metric)
        }
    }

    /// Record a counter metric.
    public func recordCounter(_ name: String, value: Double = 1.0, attributes: [String: AnyCodableValue] = [:]) {
        recordMetric(Metric(name: name, value: value, attributes: attributes))
    }

    /// Record a histogram/gauge metric.
    public func recordGauge(_ name: String, value: Double, attributes: [String: AnyCodableValue] = [:]) {
        recordMetric(Metric(name: name, value: value, attributes: attributes))
    }

    /// Export all completed spans and metrics.
    public func export() async {
        let spansToExport = completedSpans
        completedSpans = []

        let metricsToExport = metrics
        metrics = []

        guard !spansToExport.isEmpty || !metricsToExport.isEmpty else {
            return
        }

        switch configuration.exporter {
        case .console:
            exportToConsole(spans: spansToExport, metrics: metricsToExport)
        case .otlp:
            await exportToOTLP(spans: spansToExport, metrics: metricsToExport)
        case .jaeger:
            await exportToJaeger(spans: spansToExport)
        case .none:
            break
        }
    }

    /// Export to console (development).
    private func exportToConsole(spans: [TelemetrySpan], metrics: [Metric]) {
        for span in spans {
            let durationMs = span.duration * 1000
            logger.info(
                """
                [Span] \(span.name) (\(span.context.spanId.prefix(8)))
                Trace: \(span.context.traceId.prefix(8))
                Duration: \(String(format: "%.2f", durationMs))ms
                Status: \(span.status)
                Attributes: \(span.attributes)
                """
            )
        }

        for metric in metrics {
            logger.info(
                """
                [Metric] \(metric.name) = \(metric.value)
                Attributes: \(metric.attributes)
                """
            )
        }
    }

    /// Export to OTLP endpoint.
    private func exportToOTLP(spans: [TelemetrySpan], metrics: [Metric]) async {
        guard let endpoint = configuration.otlpEndpoint else {
            logger.warning("OTLP endpoint not configured")
            return
        }

        // For now, just log that we would export
        // In a full implementation, this would use URLSession to send OTLP format
        logger.info("Would export \(spans.count) spans and \(metrics.count) metrics to OTLP endpoint: \(endpoint)")

        // TODO: Implement actual OTLP HTTP export
        // Format: http://endpoint/v1/traces
        // Body: JSON in OTLP format
    }

    /// Export to Jaeger endpoint.
    private func exportToJaeger(spans: [TelemetrySpan]) async {
        guard let endpoint = configuration.jaegerEndpoint else {
            logger.warning("Jaeger endpoint not configured")
            return
        }

        // For now, just log that we would export
        // In a full implementation, this would use URLSession to send Jaeger format
        logger.info("Would export \(spans.count) spans to Jaeger endpoint: \(endpoint)")

        // TODO: Implement actual Jaeger Thrift/HTTP export
        // Format: http://endpoint/api/traces
        // Body: JSON in Jaeger format
    }

    /// Background export loop.
    private func exportLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(configuration.batchInterval * 1_000_000_000))
            await export()
        }
    }

    /// Shutdown and export remaining data.
    public func shutdown() async {
        exportTask?.cancel()
        await export()
    }

    /// Get the current span from a request's headers.
    public func extractContext(from headers: HTTPHeaders) -> SpanContext? {
        // Check for W3C Trace Context header
        if let traceParent = headers.first(name: "traceparent") {
            // Format: {version}-{traceId}-{spanId}-{traceFlags}
            let parts = traceParent.split(separator: "-")
            if parts.count >= 4 {
                let traceId = String(parts[1])
                let spanId = String(parts[2])
                let traceFlags = Int(String(parts[3]), radix: 16) ?? 1
                return SpanContext(traceId: traceId, spanId: spanId, traceFlags: traceFlags)
            }
        }

        // Check for Jaeger header format
        if let uberTraceId = headers.first(name: "uber-trace-id") {
            // Format: {traceId}:{spanId}:{parentSpanId}:{flags}
            let parts = uberTraceId.split(separator: ":")
            if parts.count >= 2 {
                let traceId = String(parts[0])
                let spanId = String(parts[1])
                return SpanContext(traceId: traceId, spanId: spanId, traceFlags: 1)
            }
        }

        return nil
    }

    /// Inject span context into headers.
    public func injectContext(_ context: SpanContext, into headers: inout HTTPHeaders) {
        // W3C Trace Context format
        let traceParent = "00-\(context.traceId)-\(context.spanId)-0\(String(context.traceFlags, radix: 16))"
        headers.replaceOrAdd(name: "traceparent", value: traceParent)
    }

    /// Get telemetry health status.
    public func getHealthStatus() -> TelemetryHealthStatus {
        TelemetryHealthStatus(
            exporter: configuration.exporter.rawValue,
            activeSpans: activeSpans.count,
            completedSpans: completedSpans.count,
            metrics: metrics.count,
            isHealthy: true
        )
    }
}

/// Telemetry health status.
public struct TelemetryHealthStatus: Content, Sendable {
    public let exporter: String
    public let activeSpans: Int
    public let completedSpans: Int
    public let metrics: Int
    public let isHealthy: Bool
}

// MARK: - Application Extension

extension Application {
    /// Storage key for telemetry manager.
    private struct TelemetryManagerKey: StorageKey {
        typealias Value = TelemetryManager
    }

    /// Access the telemetry manager.
    public var telemetry: TelemetryManager? {
        get {
            storage[TelemetryManagerKey.self]
        }
        set {
            storage[TelemetryManagerKey.self] = newValue
        }
    }
}

// MARK: - Request Extension

extension Request {
    /// Storage key for the current span.
    private struct CurrentSpanKey: StorageKey {
        typealias Value = TelemetrySpan
    }

    /// The current span for this request.
    public var currentSpan: TelemetrySpan? {
        get {
            storage[CurrentSpanKey.self]
        }
        set {
            storage[CurrentSpanKey.self] = newValue
        }
    }

    /// Storage key for span context.
    private struct SpanContextKey: StorageKey {
        typealias Value = SpanContext
    }

    /// The span context for this request.
    public var spanContext: SpanContext? {
        get {
            storage[SpanContextKey.self]
        }
        set {
            storage[SpanContextKey.self] = newValue
        }
    }
}

// MARK: - Health Check Endpoint

extension TelemetryManager {
    /// Create a health check response for telemetry.
    public func healthCheckResponse() -> TelemetryHealthCheckResponse {
        let status = getHealthStatus()
        return TelemetryHealthCheckResponse(
            exporter: status.exporter,
            healthy: status.isHealthy,
            activeSpans: status.activeSpans,
            pendingSpans: status.completedSpans,
            pendingMetrics: status.metrics,
            samplingRate: configuration.samplingRate,
            metricsEnabled: configuration.exportMetrics
        )
    }
}

/// Detailed health check response for telemetry.
public struct TelemetryHealthCheckResponse: Sendable, Content {
    public let exporter: String
    public let healthy: Bool
    public let activeSpans: Int
    public let pendingSpans: Int
    public let pendingMetrics: Int
    public let samplingRate: Double
    public let metricsEnabled: Bool
}
