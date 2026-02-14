import Vapor
import NIOConcurrencyHelpers

/// A handler for a specific hook type.
public typealias HookHandler<T> = @Sendable (T) async throws -> T

/// Registry for typed hooks that modules can register and invoke.
/// Hooks allow modules to modify data in transit (e.g., beforeSave, afterSave).
public final class HookRegistry: Sendable {
    private let _handlers: NIOLockedValueBox<[String: [AnyHookHandler]]>

    public init() {
        self._handlers = NIOLockedValueBox([:])
    }

    /// Register a handler for a named hook.
    /// - Parameters:
    ///   - hookName: The hook identifier (e.g., "beforeSave", "afterPublish").
    ///   - handler: The handler closure that receives and returns a value of type T.
    public func register<T: Sendable>(hookName: String, handler: @escaping HookHandler<T>) {
        let wrapper = TypedHookHandler(handler: handler)
        _handlers.withLockedValue { handlers in
            var list = handlers[hookName] ?? []
            list.append(wrapper)
            handlers[hookName] = list
        }
    }

    /// Invoke all handlers for a named hook, passing data through each in order.
    /// - Parameters:
    ///   - hookName: The hook identifier.
    ///   - args: The initial value to pass through handlers.
    /// - Returns: The final value after all handlers have processed it.
    public func invoke<T: Sendable>(hookName: String, args: T) async throws -> T {
        let handlers = _handlers.withLockedValue { $0[hookName] ?? [] }
        var result = args
        for handler in handlers {
            guard let typed = handler as? TypedHookHandler<T> else { continue }
            result = try await typed.handler(result)
        }
        return result
    }

    /// Invoke all handlers for a named hook without expecting a return value.
    public func notify(hookName: String, args: Any) async throws {
        let handlers = _handlers.withLockedValue { $0[hookName] ?? [] }
        for handler in handlers {
            if let typed = handler as? TypedHookHandler<Any> {
                _ = try await typed.handler(args)
            }
        }
    }

    /// Returns the number of handlers registered for a hook.
    public func handlerCount(for hookName: String) -> Int {
        _handlers.withLockedValue { $0[hookName]?.count ?? 0 }
    }
}

// MARK: - Internal Types

/// Type-erased protocol for hook handlers.
protocol AnyHookHandler: Sendable {}

/// Concrete typed hook handler.
struct TypedHookHandler<T: Sendable>: AnyHookHandler, Sendable {
    let handler: HookHandler<T>
}
