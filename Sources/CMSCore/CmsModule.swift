import Vapor

/// Protocol defining a SwiftCMS module with lifecycle hooks.
/// Every plugin and core subsystem implements this protocol.
public protocol CmsModule: Sendable {
    /// Unique identifier for this module.
    var name: String { get }

    /// Boot priority. Higher priority modules boot first.
    /// Default is 0. Core modules use 100+.
    var priority: Int { get }

    /// Called during registration phase. No database access available.
    /// Use this to register services, configure dependencies.
    func register(app: Application) throws

    /// Called after all modules register. Full access to database, event bus, other modules.
    /// Use this to set up routes, hooks, admin pages.
    func boot(app: Application) throws

    /// Called when the server is shutting down. Cleanup resources.
    func shutdown(app: Application) throws
}

// MARK: - Default Implementations

extension CmsModule {
    public var priority: Int { 0 }
    public func register(app: Application) throws {}
    public func boot(app: Application) throws {}
    public func shutdown(app: Application) throws {}
}
