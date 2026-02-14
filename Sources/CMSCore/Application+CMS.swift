import Vapor

/// Container for CMS services accessible via `app.cms`.
public struct CmsServices: Sendable {
    public let app: Application

    /// The module manager.
    public var modules: ModuleManager {
        get {
            if let existing = app.storage[ModuleManagerKey.self] {
                return existing
            }
            let manager = ModuleManager()
            app.storage[ModuleManagerKey.self] = manager
            return manager
        }
        nonmutating set {
            app.storage[ModuleManagerKey.self] = newValue
        }
    }

    /// The hook registry.
    public var hooks: HookRegistry {
        get {
            if let existing = app.storage[HookRegistryKey.self] {
                return existing
            }
            let registry = HookRegistry()
            app.storage[HookRegistryKey.self] = registry
            return registry
        }
        nonmutating set {
            app.storage[HookRegistryKey.self] = newValue
        }
    }

    /// The telemetry manager.
    public var telemetry: TelemetryManager? {
        get {
            app.storage[TelemetryManagerKey.self]
        }
        nonmutating set {
            app.storage[TelemetryManagerKey.self] = newValue
        }
    }
}

// MARK: - Application Extension

extension Application {
    /// Access CMS services.
    public var cms: CmsServices {
        CmsServices(app: self)
    }
}

// MARK: - Storage Keys

struct ModuleManagerKey: StorageKey {
    typealias Value = ModuleManager
}

struct HookRegistryKey: StorageKey {
    typealias Value = HookRegistry
}

struct TelemetryManagerKey: StorageKey {
    typealias Value = TelemetryManager
}
