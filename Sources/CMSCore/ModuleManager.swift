import Vapor
import NIOConcurrencyHelpers

/// Manages the lifecycle of all registered CMS modules.
public final class ModuleManager: Sendable {
    private let _modules: NIOLockedValueBox<[CmsModule]>

    public var modules: [CmsModule] {
        _modules.withLockedValue { $0 }
    }

    public init() {
        self._modules = NIOLockedValueBox([])
    }

    /// Register a module. Call before bootAll().
    public func register(_ module: CmsModule) {
        _modules.withLockedValue { $0.append(module) }
    }

    /// Boot all modules in priority order (highest first).
    /// Calls register(app:) on all modules first, then boot(app:).
    public func bootAll(app: Application) throws {
        let sorted = _modules.withLockedValue { modules in
            modules.sorted { $0.priority > $1.priority }
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
