import Vapor
import NIOConcurrencyHelpers
import NIOConcurrencyHelpers

/// Registry for mapping plugin names to their module builders.
public final class PluginRegistry: Sendable {
    private let _builders: NIOLockedValueBox<[String: ModuleBuilder]>

    public init() {
        self._builders = NIOLockedValueBox([:])
    }

    /// Register a module builder for a plugin name.
    public func register(_ name: String, builder: @escaping ModuleBuilder) {
        _builders.withLockedValue { builders in
            builders[name] = builder
        }
    }

    /// Get a module builder for the given plugin name.
    public func builder(for name: String) -> ModuleBuilder? {
        _builders.withLockedValue { builders in
            builders[name]
        }
    }

    /// Check if a plugin is registered.
    public func hasPlugin(_ name: String) -> Bool {
        _builders.withLockedValue { builders in
            builders[name] != nil
        }
    }
}

/// Typealias for module builder closures.
public typealias ModuleBuilder = @Sendable () -> (any CmsModule)
