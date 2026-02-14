import Vapor

/// 🧩 **CMS Services Container**
///
/// Central access point for all CMS core services via `app.cms`.
/// Provides thread-safe access to module management, hook registration,
/// and other core CMS functionality across the application lifecycle.
///
/// ## Usage
/// ```swift
/// // Access from Application
/// app.cms.modules.register(MyModule())
/// app.cms.hooks.register("beforeSave", handler: myHandler)
///```
public struct CmsServices: Sendable {
    public let app: Application

    /// 🎯 **Module Manager Registry**
    ///
    /// Thread-safe manager for all registered CMS modules.
    /// Handles module lifecycle, dependency resolution, and boot order.
    /// Lazily initializes on first access and stores in Application storage.
    ///
    /// - Returns: The shared ModuleManager instance
    public var modules: ModuleManager {
        get {
            if let existing = app.storage[ModuleManagerKey.self] {
                return existing
            }
            let manager = ModuleManager()
            app.storage[ModuleManagerKey.self] = manager
            app.logger.debug("🎯 Initialized ModuleManager")
            return manager
        }
        nonmutating set {
            app.storage[ModuleManagerKey.self] = newValue
            app.logger.debug("🎯 Updated ModuleManager instance")
        }
    }

    /// 🎣 **Hook System Registry**
    ///
    /// Centralized hook registry for cross-module communication.
    /// Enables modules to register event handlers and modify data in transit.
    /// Thread-safe and supports multiple handlers per hook.
    ///
    /// - Returns: The shared HookRegistry instance
    public var hooks: HookRegistry {
        get {
            if let existing = app.storage[HookRegistryKey.self] {
                return existing
            }
            let registry = HookRegistry()
            app.storage[HookRegistryKey.self] = registry
            app.logger.debug("🎣 Initialized HookRegistry")
            return registry
        }
        nonmutating set {
            app.storage[HookRegistryKey.self] = newValue
            app.logger.debug("🎣 Updated HookRegistry instance")
        }
    }
}

// MARK: - Application Extension

extension Application {
    /// 🧩 **CMS Services Access Point**
    ///
    /// Main entry point for all CMS core functionality from Application context.
    /// Provides fluent access to modules, hooks, and other CMS services.
    ///
    /// - Returns: CmsServices instance with access to all CMS functionality
    public var cms: CmsServices {
        CmsServices(app: self)
    }
}

// MARK: - Storage Keys

/// 🗄️ **Module Manager Storage Key**
///
/// Internal storage key for persisting the ModuleManager instance
/// in Application.storage for thread-safe access across request handlers.
struct ModuleManagerKey: StorageKey {
    typealias Value = ModuleManager
}

/// 🗄️ **Hook Registry Storage Key**
///
/// Internal storage key for persisting the HookRegistry instance
/// in Application.storage for thread-safe access across request handlers.
struct HookRegistryKey: StorageKey {
    typealias Value = HookRegistry
}
