import Vapor

/// 🎯 **CMS Module Protocol**
///
/// Defines the lifecycle contract for all SwiftCMS modules, plugins, and core subsystems.
/// Each module implements three distinct phases: registration, boot, and shutdown.
/// Thread-safe conforming types enable concurrent module management.
///
/// ## Lifecycle Phases
///
/// 1. **Register**: Configure services, register dependencies before database access
/// 2. **Boot**: Full CMS access - setup routes, hooks, admin pages
/// 3. **Shutdown**: Cleanup resources when server terminates
///
/// ## Usage Example
/// ```swift
/// struct MyModule: CmsModule {
///     let name = "MyModule"
///     let version = "1.0.0"
///     let priority = 50
///
///     func register(app: Application) throws {
///         app.logger.info("🎯 Registering \(name)")
///         app.services.register(MyService.self) { _ in MyService() }
///     }
///
///     func boot(app: Application) throws {
///         app.logger.info("🚀 Booting \(name)")
///         try routes(app)
///     }
///
///     func shutdown(app: Application) throws {
///         app.logger.info("⏹️  Shutting down \(name)")
///         cleanupResources()
///     }
/// }
/// ```
public protocol CmsModule: Sendable {
    /// 🏷️ **Module Identifier**
    ///
    /// Unique identifier for this module. Must be unique across all loaded modules.
    /// Used for dependency resolution, plugin loading, and system identification.
    ///
    /// - Note: Typically uses kebab-case (e.g., "content-management")
    var name: String { get }

    /// 📋 **Module Version**
    ///
    /// Semantic version string following SemVer format (MAJOR.MINOR.PATCH).
    /// Optional - plugins commonly include version information.
    ///
    /// - Returns: Version string like "2.1.4" or nil if not versioned
    var version: String? { get }

    /// ⚡ **Boot Priority**
    ///
    /// Determines module initialization order. Higher values boot first (100+ for core modules).
    /// Used when modules lack explicit dependencies but require specific load order.
    ///
    /// - Returns: Priority value (default: 0)
    var priority: Int { get }

    /// 🔧 **Module Registration**
    ///
    /// Called during application startup before database connections are established.
    /// Use this phase to register services, configure dependencies, and prepare resources.
    ///
    /// - Parameter app: The Application instance
    /// - Throws: Abort error if registration fails
    func register(app: Application) throws

    /// 🚀 **Module Boot**
    ///
    /// Called after all modules have registered. Full access to database, event bus, and other modules.
    /// Use this phase to setup routes, register hooks, create admin pages, and initialize features.
    ///
    /// - Parameter app: The Application instance with full system access
    /// - Throws: Abort error if boot fails
    func boot(app: Application) throws

    /// 🛑 **Module Shutdown**
    ///
    /// Called when the server is shutting down gracefully. Perform cleanup, close connections,
    /// and release resources. Reverse operations from register() and boot().
    ///
    /// - Parameter app: The Application instance
    /// - Throws: Abort error if shutdown fails
    func shutdown(app: Application) throws
}

// MARK: - Default Implementations

extension CmsModule {
    /// 📋 **Default Version**
    ///
    /// Returns nil - modules are not required to have version information.
    public var version: String? { nil }

    /// ⚡ **Default Priority**
    ///
    /// Returns 0 - baseline priority for standard modules.
    public var priority: Int { 0 }

    /// 🔧 **Default Registration**
    ///
    /// No-op implementation - override for custom registration logic.
    public func register(app: Application) throws {
        app.logger.trace("🔧 \(name) registered with defaults")
    }

    /// 🚀 **Default Boot**
    ///
    /// No-op implementation - override for custom boot logic.
    public func boot(app: Application) throws {
        app.logger.trace("🚀 \(name) booted with defaults")
    }

    /// 🛑 **Default Shutdown**
    ///
    /// No-op implementation - override for custom cleanup logic.
    public func shutdown(app: Application) throws {
        app.logger.trace("🛑 \(name) shutdown with defaults")
    }
}
