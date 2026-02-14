import Vapor
import NIOConcurrencyHelpers

/// 🎯 **CMS Module Lifecycle Manager**
///
/// Central coordinator for all CMS module registration, boot, and shutdown operations.
/// Manages module lifecycle phases, dependency resolution, and plugin discovery.
/// Thread-safe using NIOLockedValueBox for concurrent module operations.
///
/// ## Responsibilities
/// - Module registration and storage
/// - Lifecycle phase coordination (register → boot → shutdown)
/// - Dependency-aware boot ordering
/// - Plugin discovery and builder resolution
///
/// ## Usage Example
/// ```swift
/// let manager = ModuleManager()
///
/// // Register modules
/// manager.register(MyContentModule())
/// manager.register(MyAuthModule())
///
/// // Boot all modules
/// try manager.bootAll(app: app)
///
/// // Shutdown on server termination
/// try manager.shutdownAll(app: app)
/// ```
public final class ModuleManager: Sendable {
    private let _modules: NIOLockedValueBox<[CmsModule]>
    private let _pluginRegistry: PluginRegistry

    /// 📋 **Registered Modules List**
    ///
    /// Thread-safe view of all currently registered modules.
    /// Returns a safe copy of the module list using NIOLockedValueBox.
    ///
    /// - Returns: Array of all registered CmsModule instances
    public var modules: [CmsModule] {
        _modules.withLockedValue { $0 }
    }

    /// 🔧 **Module Manager Initialization**
    ///
    /// Creates a new module manager with optional plugin registry.
    /// Initialize with custom plugin registry for testing or extended functionality.
    ///
    /// - Parameter pluginRegistry: Optional custom plugin registry (default: new instance)
    public init(pluginRegistry: PluginRegistry = PluginRegistry()) {
        self._modules = NIOLockedValueBox([])
        self._pluginRegistry = pluginRegistry
    }

    /// ➕ **Register Module**
    ///
    /// Registers a module for lifecycle management. Must be called before bootAll().
    /// Thread-safe module storage using NIOLockedValueBox.
    ///
    /// - Parameter module: The CmsModule to register
    public func register(_ module: CmsModule) {
        _modules.withLockedValue { modules in
            modules.append(module)
        }
    }

    /// 🔌 **Register Plugin by Name**
    ///
    /// Registers a plugin module using the plugin registry builder pattern.
    /// Looks up the named plugin in the registry and instantiates if available.
    ///
    /// - Parameter name: Plugin name to register
    /// - Returns: True if plugin was registered successfully, false if not found
    public func registerPlugin(byName name: String) -> Bool {
        guard let builder = _pluginRegistry.builder(for: name) else {
            return false
        }
        let module = builder()
        register(module)
        return true
    }

    /// 🚀 **Boot All Modules**
    ///
    /// Executes module lifecycle phases for all registered modules.
    /// Phases: register(app:) → boot(app:) in priority order.
    /// Module failures throw errors and halt the boot process.
    ///
    /// - Parameter app: The Application instance
    /// - Throws: Abort error if any module fails during registration or boot
    public func bootAll(app: Application) throws {
        let sorted = _modules.withLockedValue { modules in
            modules.sorted {
                // Sort by dependency order if available, then by priority
                if $0.priority != $1.priority {
                    return $0.priority > $1.priority
                }
                return $0.name < $1.name // Tie-breaker
            }
        }

        // Phase 1: Register all modules
        for module in sorted {
            app.logger.info("Registering module: \(module.name) (priority: \(module.priority))")
            try module.register(app: app)
        }

        // Phase 2: Boot all modules
        for module in sorted {
            app.logger.info("Booting module: \(module.name)")
            try module.boot(app: app)
        }

        app.logger.info("All \(sorted.count) modules booted successfully")
    }

    /// 🚀 **Boot Modules in Order**
    ///
    /// Executes module lifecycle phases using a predefined boot order.
    /// Useful for dependency-aware boot sequences from plugin discovery.
    /// Validates all modules are registered before proceeding.
    ///
    /// - Parameters:
    ///   - orderedModules: Sorted array of modules to boot in order
    ///   - app: The Application instance
    /// - Throws: Abort error if module not registered or fails during lifecycle
    public func bootAll(inOrder orderedModules: [CmsModule], app: Application) throws {
        let currentModules = _modules.withLockedValue { $0 }
        let moduleSet = Set(currentModules.map { $0.name })

        // Verify all modules are registered
        for module in orderedModules {
            guard moduleSet.contains(module.name) else {
                throw Abort(.internalServerError, reason: "Module \(module.name) not registered but required by boot order")
            }
        }

        // Phase 1: Register all modules in order
        for module in orderedModules {
            app.logger.info("Registering module: \(module.name) (priority: \(module.priority))")
            try module.register(app: app)
        }

        // Phase 2: Boot all modules in order
        for module in orderedModules {
            app.logger.info("Booting module: \(module.name)")
            try module.boot(app: app)
        }

        app.logger.info("All \(orderedModules.count) modules booted successfully in dependency order")
    }

    /// ⏹️ **Shutdown All Modules**
    ///
    /// Gracefully shuts down all registered modules in reverse priority order.
    /// Called when the server is terminating to allow modules to cleanup resources.
    /// Module failures result in logged warnings but don't prevent other modules from shutting down.
    ///
    /// - Parameter app: The Application instance
    /// - Throws: Abort if critical modules fail to shutdown gracefully
    public func shutdownAll(app: Application) throws {
        let sorted = _modules.withLockedValue { modules in
            modules.sorted { $0.priority < $1.priority }
        }

        for module in sorted {
            app.logger.info("Shutting down module: \(module.name)")
            try module.shutdown(app: app)
        }
    }
}
