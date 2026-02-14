import Vapor

/// 🌐 **Request-Scoped CMS Services**
///
/// Provides CMS service access from within HTTP request handlers.
/// Bridges Application-level CMS services to Request context for convenience.
/// All properties are computed and delegate to Application storage.
///
/// ## Usage
/// ```swift
/// func createContent(req: Request) async throws -> ContentEntry {
///     let hooks = req.cms.hooks
///     let modules = req.cms.modules
///     // Use services in request context
/// }
/// ```
public struct RequestCmsServices: Sendable {
    public let req: Request

    /// 🎣 **Hook Registry Access**
    ///
    /// Access the global hook registry from request context.
    /// Used to register or invoke hooks within request handlers.
    ///
    /// - Returns: HookRegistry instance
    public var hooks: HookRegistry {
        req.application.cms.hooks
    }

    /// 🎯 **Module Manager Access**
    ///
    /// Access the global module manager from request context.
    /// Used for module introspection and management.
    ///
    /// - Returns: ModuleManager instance
    public var modules: ModuleManager {
        req.application.cms.modules
    }

    /// 📊 **Telemetry Manager Access**
    ///
    /// Access the telemetry manager for distributed tracing and metrics.
    /// Returns nil if telemetry is not configured.
    ///
    /// - Returns: Optional TelemetryManager instance
    public var telemetry: TelemetryManager? {
        req.application.telemetry
    }
}

extension Request {
    /// 🧩 **Request-Based CMS Services Access**
    ///
    /// Convenience accessor for CMS services from Request context.
    /// Provides the same functionality as `app.cms` but from request handlers.
    ///
    /// - Returns: RequestCmsServices instance with access to hooks, modules, and telemetry
    public var cms: RequestCmsServices {
        RequestCmsServices(req: self)
    }
}
