import Vapor
import NIOConcurrencyHelpers

/// Manages the lifecycle of all registered CMS modules.
public final class ModuleManager: Sendable {
    private let _modules: NIOLockedValueBox<[CmsModule]>
    private let _pluginRegistry: PluginRegistry

    public var modules: [CmsModule] {
        _modules.withLockedValue { $0 }
    }

    public init(pluginRegistry: PluginRegistry = PluginRegistry()) {
        self._modules = NIOLockedValueBox([])
        self._pluginRegistry = pluginRegistry
    }

    /// Register a module. Call before bootAll().
    public func register(_ module: CmsModule) {
        _modules.withLockedValue { $0.append(module) }
    }

    /// Register a plugin module using the plugin registry.
    public func registerPlugin(byName name: String) -> Bool {
        guard let builder = _pluginRegistry.builder(for: name) else {
            return false
        }
        let module = builder()
        register(module)
        return true
    }

    /// Boot all modules in dependency order (if available) then by priority.
    /// Calls register(app:) on all modules first, then boot(app:).
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

    /// Boot modules using a provided sorted order (e.g., from PluginDiscovery)
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

    /// Shutdown all modules in reverse priority order.
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
