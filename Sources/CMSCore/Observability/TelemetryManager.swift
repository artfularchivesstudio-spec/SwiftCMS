import Vapor
import Fluent
import CMSObjects
import Foundation

/// 📊 **Telemetry Configuration**
///
/// Comprehensive configuration for OpenTelemetry integration in SwiftCMS.
/// Supports multiple exporters (OTLP, Jaeger, Console), sampling rates,
/// and metric export settings.
///
/// ## Configuration Sources
/// - Direct initialization with custom values
/// - Environment variables (OTEL_*) auto-detection
/// - JSON configuration files
///
/// ## Environment Variables
/// ```bash
/// OTEL_SERVICE_NAME=swiftcms          # Service identifier
/// OTEL_SERVICE_VERSION=1.0.0         # Service version
/// OTEL_EXPORTER=otlp                 # otlp|jaeger|console|none
/// OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
/// OTEL_EXPORTER_JAEGER_ENDPOINT=http://localhost:14268
/// OTEL_METRICS_ENABLED=true          # Enable metrics collection
/// OTEL_SAMPLING_RATE=1.0            # 0.0 to 1.0
/// OTEL_BATCH_INTERVAL=5.0           # Export interval in seconds
/// ```
///
/// ## Usage
/// ```swift
/// // Environment-based configuration
/// let config = TelemetryConfiguration.fromEnvironment()
/// let telemetry = TelemetryManager(configuration: config, logger: logger)
///
/// // Custom configuration
/// let config = TelemetryConfiguration(
///     serviceName: "swiftcms-api",
///     exporter: .otlp,
///     otlpEndpoint: "http://jaeger:4317",
///     exportMetrics: true
/// )
/// ```
public struct TelemetryConfiguration: Sendable {
    /// The service name for tracing identification
    public var serviceName: String

    /// The service version for deployment tracking
    public var serviceVersion: String

    /// The exporter type to use for span and metric export
    public var exporter: ExporterType

    /// OTLP collector endpoint URL (format: http://host:port)
    public var otlpEndpoint: String?

    /// Jaeger collector endpoint URL
    public var jaegerEndpoint: String?

    /// Whether to export metrics alongside traces
    public var exportMetrics: Bool

    /// Sampling rate (0.0 = no traces, 1.0 = all traces, 0.5 = 50% sample)
    public var samplingRate: Double

    /// Batch export interval in seconds between export operations
    public var batchInterval: TimeInterval

    /// 🎯 **Exporter Types**
    ///
    /// Supported telemetry exporters for traces and metrics.
    ///- `console`: Development logging (default)
    /// - `otlp`: OpenTelemetry Protocol collector
    /// - `jaeger`: Jaeger-specific format
    /// - `none`: Disabled telemetry
    public enum ExporterType: String, Sendable {
        case console
        case otlp
        case jaeger
        case none
    }

    /// 🧰 **Custom Configuration Constructor**
    ///
    /// Creates a telemetry configuration with explicit settings.
    ///
    /// - Parameters:
    ///   - serviceName: Service identifier (default: "swiftcms")
    ///   - serviceVersion: Service version (default: "1.0.0")
    ///   - exporter: Exporter type (default: .console)
    ///   - otlpEndpoint: OTLP collector URL (required for .otlp exporter)
    ///   - jaegerEndpoint: Jaeger collector URL (required for .jaeger exporter)
    ///   - exportMetrics: Enable metric collection (default: true)
    ///   - samplingRate: Trace sampling rate 0.0-1.0 (default: 1.0)
    ///   - batchInterval: Export batch interval in seconds (default: 5.0)
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

    /// 🌍 **Environment Configuration**
    ///
    /// Creates configuration from standard OpenTelemetry environment variables.
    /// Auto-detects settings from environment with sensible defaults.
    ///
    /// - Returns: TelemetryConfiguration with environment-based settings
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

/// 📊 **Span Operation Type**
///
/// Categorizes spans by the role of the operation in distributed tracing.
/// Based on OpenTelemetry span kind specification.
public enum SpanKind: String, Sendable {
    case server
    case client
    case producer
    case consumer
    case `internal`
}

/// 📊 **Distributed Tracing Span**
///
/// Represents a single operation within a distributed trace.
/// Contains timing, attributes, events, and status information.
/// Thread-safe with lock-protected mutable state.
///
/// ## Span Lifecycle
/// - Create: `TelemetryManager.createSpan()` - operation starts
/// - Active: Set attributes, add events, record errors
/// - End: `TelemetryManager.endSpan()` - operation completes
/// - Export: Collected spans are exported to configured endpoint
public final class TelemetrySpan: @unchecked Sendable {
    /// The span context containing trace and span IDs
    public let context: SpanContext

    /// The span name (typically "operation target")
    public let name: String

    /// The span kind (server, client, producer, consumer, internal)
    public let kind: SpanKind

    /// The operation start time
    public let startTime: Date

    /// The operation end time (nil if span is active)
    private var _endTime: Date?

    /// Thread-safe access to end time using NSLock
    private let endTimeLock = NSLock()

    public var endTime: Date? {
        endTimeLock.lock()
        defer { endTimeLock.unlock() }
        return _endTime
    }

    /// Span attributes for trace analysis
    private var _attributes: [String: AnyCodableValue]

    /// Thread-safe attributes access using NSLock
    private let attributesLock = NSLock()

    public var attributes: [String: AnyCodableValue] {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        return _attributes
    }

    /// Timeline events within the span
    private var _events: [SpanEvent]

    /// Thread-safe events access using NSLock
    private let eventsLock = NSLock()

    public var events: [SpanEvent] {
        eventsLock.lock()
        defer { eventsLock.unlock() }
        return _events
    }

    /// Parent span context for trace hierarchy
    public let parentContext: SpanContext?

    /// Current span status
    private var _status: SpanStatus

    /// Thread-safe status access using NSLock
    private let statusLock = NSLock()

    public var status: SpanStatus {
        statusLock.lock()
        defer { statusLock.unlock() }
        return _status
    }

    /// 🧰 **Span Initialization**
    ///
    /// Creates a new span with complete configuration.
    /// Auto-generates trace/span IDs if not provided.
    ///
    /// - Parameters:
    ///   - name: The operation name
    ///   - kind: The span kind (default: .internal)
    ///   - parentContext: Parent span context for trace hierarchy
    ///   - traceId: Optional trace ID (auto-generates if nil)
    ///   - spanId: Optional span ID (auto-generates if nil)
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

    /// 📝 **Set String Attribute**
    ///
    /// Adds or updates a string attribute on the span.
    ///
    /// - Parameters:
    ///   - key: Attribute name
    ///   - value: String value
    public func setAttribute(_ key: String, value: String) {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        _attributes[key] = .string(value)
    }

    /// 📝 **Set Integer Attribute**
    ///
    /// Adds or updates an integer attribute on the span.
    ///
    /// - Parameters:
    ///   - key: Attribute name
    ///   - value: Integer value
    public func setAttribute(_ key: String, value: Int) {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        _attributes[key] = .int(value)
    }

    /// 📝 **Set Unsigned Integer Attribute**
    ///
    /// Adds or updates an unsigned integer attribute on the span.
    ///
    /// - Parameters:
    ///   - key: Attribute name
    ///   - value: Unsigned integer value
    public func setAttribute(_ key: String, value: UInt) {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        _attributes[key] = .int(Int(value))
    }

    /// 📝 **Set Floating Point Attribute**
    ///
    /// Adds or updates a double attribute on the span.
    ///
    /// - Parameters:
    ///   - key: Attribute name
    ///   - value: Double value
    public func setAttribute(_ key: String, value: Double) {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        _attributes[key] = .double(value)
    }

    /// 📝 **Set Boolean Attribute**
    ///
    /// Adds or updates a boolean attribute on the span.
    ///
    /// - Parameters:
    ///   - key: Attribute name
    ///   - value: Boolean value
    public func setAttribute(_ key: String, value: Bool) {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        _attributes[key] = .bool(value)
    }

    /// 📝 **Add Timeline Event**
    ///
    /// Records a timestamped event within the span's timeline.
    /// Useful for marking significant moments in an operation.
    ///
    /// - Parameters:
    ///   - name: Event name
    ///   - attributes: Optional attributes for the event
    public func addEvent(_ name: String, attributes: [String: AnyCodableValue] = [:]) {
        eventsLock.lock()
        defer { eventsLock.unlock() }
        _events.append(SpanEvent(name: name, timestamp: Date(), attributes: attributes))
    }

    /// ✅ **Set Span Status**
    ///
    /// Sets the final status of the span operation (unset, ok, or error).
    ///
    /// - Parameter status: The span status
    public func setStatus(_ status: SpanStatus) {
        statusLock.lock()
        defer { statusLock.unlock() }
        _status = status
    }

    /// ❌ **Record Error**
    ///
    /// Records an error in the span, setting error status and adding an exception event.
    /// Automatically includes error type and message as attributes.
    ///
    /// - Parameter error: The error to record
    public func recordError(_ error: Error) {
        setStatus(.error(description: error.localizedDescription))
        addEvent("exception", attributes: [
            "exception.message": .string(error.localizedDescription),
            "exception.type": .string(String(describing: type(of: error)))
        ])
    }

    /// ⏹️ **End Span**
    ///
    /// Marks the span as completed by setting the end time.
    /// Idempotent - multiple calls don't extend the lifetime.
    public func end() {
        endTimeLock.lock()
        defer { endTimeLock.unlock() }
        if _endTime == nil {
            _endTime = Date()
        }
    }

    /// ⏱️ **Span Duration**
    ///
    /// Calculates the total duration of the span.
    ///
    /// - Returns: TimeInterval (seconds) between start and end times
    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
}

/// 🧬 **Span Context**
///
/// Contains the trace and span identifiers for distributed tracing.
/// Propagated between services via HTTP headers to maintain trace hierarchy.
///
/// - traceId: 16-byte hex string (32 characters)
/// - spanId: 8-byte hex string (16 characters)
/// - traceFlags: W3C trace flags
public struct SpanContext: Sendable, Codable {
    public let traceId: String
    public let spanId: String
    public let traceFlags: Int
}

/// 📅 **Span Timeline Event**
///
/// Timestamped event within a span representing a significant moment.
/// Contains event name, occurrence time, and optional attributes.
public struct SpanEvent: Sendable {
    public let name: String
    public let timestamp: Date
    public let attributes: [String: AnyCodableValue]
}

/// ✅ **Span Status**
///
/// Indicates the result status of a traced operation.
public enum SpanStatus: Sendable {
    case unset
    case ok
    case error(description: String)
}

/// 📊 **Metric Measurement**
///
/// A single metric data point with timestamp, value, and attributes.
/// Supports counters, gauges, and histograms through unified interface.
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

/// 📊 **Core Telemetry Manager**
///
/// Actor-based telemetry manager handling distributed tracing and metrics.
/// Manages span lifecycle, metric collection, and asynchronous export to configured endpoints.
/// Thread-safe and async-first using Swift concurrency.
///
/// ## Core Responsibilities
/// - Span creation and lifecycle management
/// - Metric collection and aggregation
/// - Batch export to configured endpoints
/// - Context propagation across services
///
/// ## Usage
/// ```swift
/// let telemetry = TelemetryManager(configuration: config, logger: logger)
/// app.telemetry = telemetry // Set on Application
///
/// // Create spans
/// let span = await telemetry.createSpan("process-order", kind: .server)
/// span.setAttribute("order.id", value: orderId)
/// // ... do work ...
/// await telemetry.endSpan(span)
///
/// // Record metrics
/// await telemetry.recordCounter("orders.processed", value: 1)
/// await telemetry.recordGauge("process.duration_ms", value: duration)
/// ```
public actor TelemetryManager {
    /// 📊 **Telemetry Configuration**
    ///
    /// Configuration values controlling sampling, export, and collection behavior.
    /// Internal storage with public read-only access via computed properties.
    private let configuration: TelemetryConfiguration

    /// 📊 **Sampling Rate for Traces**
    ///
    /// Returns the configured sampling rate (0.0 to 1.0).
    /// Used to determine whether spans should be recorded.
    public var samplingRate: Double {
        configuration.samplingRate
    }

    /// 📊 **Metrics Export Enabled**
    ///
    /// Returns true if metrics collection and export is enabled.
    public var exportMetrics: Bool {
        configuration.exportMetrics
    }

    /// 🎯 **Active Spans**
    ///
    /// Dictionary of spans currently being traced, keyed by span ID.
    private var activeSpans: [String: TelemetrySpan]

    /// 📦 **Completed Spans**
    ///
    /// Queue of spans ready for export to telemetry backend.
    private var completedSpans: [TelemetrySpan]

    /// 📈 **Collected Metrics**
    ///
    /// Array of metric data points awaiting export.
    private var metrics: [Metric]

    /// 📝 **Logger for Telemetry Operations**
    ///
    /// Structured logger for telemetry events and diagnostics.
    private let logger: Logger

    /// 🔄 **Background Export Task**
    ///
    /// Task handle for the continuous export loop.
    private var exportTask: Task<Void, Never>?

    /// 🧰 **Initialize Telemetry Manager**
    ///
    /// Creates a telemetry manager with configuration and starts background export loop.
    ///
    /// - Parameters:
    ///   - configuration: Telemetry configuration
    ///   - logger: Logger instance for telemetry operations
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

    /// ➕ **Create New Span**
    ///
    /// Creates a new telemetry span for tracing an operation.
    /// Applies sampling based on configuration.
    ///
    /// - Parameters:
    ///   - name: Span name
    ///   - kind: Span kind (default: .internal)
    ///   - parentContext: Parent span context for hierarchy
    /// - Returns: New TelemetrySpan instance (may be sampled out)
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

    /// ⏹️ **End Span**
    ///
    /// Marks a span as completed and moves it to the export queue.
    /// Removes from active collection and adds to completed queue.
    ///
    /// - Parameter span: The span to end
    public func endSpan(_ span: TelemetrySpan) {
        span.end()
        if activeSpans.removeValue(forKey: span.context.spanId) != nil {
            completedSpans.append(span)
        }
    }

    /// 📊 **Record Metric**
    ///
    /// Records a metric measurement for export.
    /// Ignores metrics if exportMetrics is disabled in configuration.
    ///
    /// - Parameter metric: The completed metric to record
    public func recordMetric(_ metric: Metric) {
        if configuration.exportMetrics {
            metrics.append(metric)
        }
    }

    /// 📈 **Record Counter Metric**
    ///
    /// Convenience method for recording counter metrics (monotonically increasing values).
    ///
    /// - Parameters:
    ///   - name: Metric name
    ///   - value: Increment amount (default: 1.0)
    ///   - attributes: Optional metric attributes
    public func recordCounter(_ name: String, value: Double = 1.0, attributes: [String: AnyCodableValue] = [:]) {
        recordMetric(Metric(name: name, value: value, attributes: attributes))
    }

    /// 📉 **Record Gauge Metric**
    ///
    /// Convenience method for recording gauge metrics (point-in-time values).
    ///
    /// - Parameters:
    ///   - name: Metric name
    ///   - value: Current value
    ///   - attributes: Optional metric attributes
    public func recordGauge(_ name: String, value: Double, attributes: [String: AnyCodableValue] = [:]) {
        recordMetric(Metric(name: name, value: value, attributes: attributes))
    }

    /// 🚚 **Export Telemetry Data**
    ///
    /// Exports all completed spans and queued metrics to configured endpoint.
    /// Called automatically by background export loop and on shutdown.
    ///
    /// - Note: Skips export if no data to export
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

    /// 💻 **Console Exporter**
    ///
    /// Development exporter that logs spans and metrics to console with formatted output.
    /// Useful for local development and debugging.
    ///
    /// - Parameters:
    ///   - spans: Completed spans to export
    ///   - metrics: Queued metrics to export
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

    /// 🌐 **OTLP Exporter**
    ///
    /// Exports traces and metrics to OpenTelemetry Collector via OTLP protocol.
    /// Currently logs intent (full implementation would use HTTP/JSON OTLP format).
    ///
    /// - Parameters:
    ///   - spans: Completed spans to export
    ///   - metrics: Queued metrics to export
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

    /// 🦘 **Jaeger Exporter**
    ///
    /// Exports traces to Jaeger collector.
    /// Currently logs intent (full implementation would use Jaeger HTTP format).
    ///
    /// - Parameter spans: Completed spans to export
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

    /// 🔄 **Background Export Loop**
    ///
    /// Continuously exports telemetry data at configured intervals.
    /// Runs for the lifetime of the application or until cancelled.
    /// Exports all pending spans and metrics on each iteration.
    private func exportLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(configuration.batchInterval * 1_000_000_000))
            await export()
        }
    }

    /// 🛑 **Graceful Shutdown**
    ///
    /// Cancels background export task and performs final export of pending data.
    /// Called when the application is shutting down gracefully.
    public func shutdown() async {
        exportTask?.cancel()
        await export()
    }

    /// 🧬 **Extract Context from Headers**
    ///
    /// Extracts parent span context from incoming HTTP headers.
    /// Supports W3C Trace Context and Jaeger propagation formats.
    ///
    /// - Parameter headers: HTTP headers containing trace context
    /// - Returns: Extracted span context or nil if not found
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

    /// ➡️ **Inject Context to Headers**
    ///
    /// Serializes span context to HTTP headers for propagation.
    /// Uses W3C Trace Context format for interoperability.
    ///
    /// - Parameters:
    ///   - context: Span context to inject
    ///   - headers: HTTP headers to modify
    public func injectContext(_ context: SpanContext, into headers: inout HTTPHeaders) {
        // W3C Trace Context format
        let traceParent = "00-\(context.traceId)-\(context.spanId)-0\(String(context.traceFlags, radix: 16))"
        headers.replaceOrAdd(name: "traceparent", value: traceParent)
    }

    /// ❤️ **Health Check**
    ///
    /// Returns current telemetry system health and statistics.
    /// Useful for monitoring and diagnostics.
    ///
    /// - Returns: TelemetryHealthStatus with current metrics
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

/// 📊 **Telemetry Health Status**
///
/// Snapshot of telemetry system health and statistics.
public struct TelemetryHealthStatus: Content, Sendable {
    public let exporter: String
    public let activeSpans: Int
    public let completedSpans: Int
    public let metrics: Int
    public let isHealthy: Bool

    public init(
        exporter: String,
        activeSpans: Int,
        completedSpans: Int,
        metrics: Int,
        isHealthy: Bool
    ) {
        self.exporter = exporter
        self.activeSpans = activeSpans
        self.completedSpans = completedSpans
        self.metrics = metrics
        self.isHealthy = isHealthy
    }
}

// MARK: - Application Extensions

extension Application {
    /// 🗄️ **Telemetry Manager Storage Key**
    ///
    /// Internal storage key for persisting the TelemetryManager in Application.storage.
    private struct TelemetryManagerKey: StorageKey {
        typealias Value = TelemetryManager
    }

    /// 📊 **Telemetry Manager Access**
    ///
    /// Access the application-wide telemetry manager instance.
    /// Nil if telemetry is not configured.
    public var telemetry: TelemetryManager? {
        get {
            storage[TelemetryManagerKey.self]
        }
        set {
            storage[TelemetryManagerKey.self] = newValue
        }
    }
}

// MARK: - Request Extensions

extension Request {
    /// 🗄️ **Current Span Storage Key**
    ///
    /// Internal storage key for the current request span in Request.storage.
    private struct CurrentSpanKey: StorageKey {
        typealias Value = TelemetrySpan
    }

    /// 📊 **Current Span Access**
    ///
    /// The span representing the current request operation.
    /// Set by TracingMiddleware for each incoming request.
    public var currentSpan: TelemetrySpan? {
        get {
            storage[CurrentSpanKey.self]
        }
        set {
            storage[CurrentSpanKey.self] = newValue
        }
    }

    /// 🗄️ **Span Context Storage Key**
    ///
    /// Internal storage key for span context in Request.storage.
    private struct SpanContextKey: StorageKey {
        typealias Value = SpanContext
    }

    /// 🧬 **Span Context Access**
    ///
    /// The span context for this request (may be inherited from parent trace).
    /// Extracted from incoming HTTP headers by tracing middleware.
    public var spanContext: SpanContext? {
        get {
            storage[SpanContextKey.self]
        }
        set {
            storage[SpanContextKey.self] = newValue
        }
    }
}
