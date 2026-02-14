import Vapor
import NIOConcurrencyHelpers

/// 🎣 **Hook Handler Type**
///
/// A handler closure type for hook events that transforms data of type T.
/// Receives input data, performs operations, and returns modified data.
/// Fully async and Sendable for safe concurrent usage across modules.
///
/// ## Usage
/// ```swift
/// let handler: HookHandler<ContentEntry> = { entry in
///     // Modify entry before saving
///     entry.updatedAt = Date()
///     return entry
/// }
/// ```
public typealias HookHandler<T> = @Sendable (T) async throws -> T

/// 🎣 **Central Hook Registry**
///
/// Thread-safe registry for typed hooks that modules can register and invoke.
/// Enables cross-module communication through event-driven hooks.
/// Supports multiple handlers per hook with sequential processing order.
///
/// ## Hook Types
/// - `beforeSave`: Transform data before persistence
/// - `afterSave`: React to successful saves
/// - `beforeDelete`: Validate or prevent deletion
/// - `afterPublish`: Handle post-publish operations
/// - Custom hooks for module-specific events
///
/// ## Usage Example
/// ```swift
/// // Register a hook
/// app.cms.hooks.register("beforeSave") { (entry: ContentEntry) in
///     entry.updatedAt = Date()
///     return entry
/// }
///
/// // Invoke a hook
/// let modifiedEntry = try await app.cms.hooks.invoke("beforeSave", args: entry)
///
/// // Notify without return value
/// try await app.cms.hooks.notify("afterPublish", args: entry.id)
/// ```
public final class HookRegistry: Sendable {
    private let _handlers: NIOLockedValueBox<[String: [AnyHookHandler]]>

    /// 🔧 **Initialize Hook Registry**
    ///
    /// Creates an empty hook registry with thread-safe handler storage.
    public init() {
        self._handlers = NIOLockedValueBox([:])
    }

    /// ➕ **Register Hook Handler**
    ///
    /// Registers a typed handler for a named hook. Multiple handlers per hook
    /// are executed in registration order (sequential processing).
    ///
    /// - Parameters:
    ///   - hookName: The hook identifier (e.g., "beforeSave", "afterPublish")
    ///   - handler: Async closure that receives and returns data of type T
    public func register<T: Sendable>(hookName: String, handler: @escaping HookHandler<T>) {
        let wrapper = TypedHookHandler(handler: handler)
        _handlers.withLockedValue { handlers in
            var list = handlers[hookName] ?? []
            list.append(wrapper)
            handlers[hookName] = list
        }
    }

    /// 🔄 **Invoke Hook Chain**
    ///
    /// Executes all handlers for a named hook, passing data sequentially through each.
    /// Returns the final transformed value after all handlers have processed it.
    ///
    /// - Parameters:
    ///   - hookName: The hook identifier
    ///   - args: Initial value to pass through handlers
    /// - Returns: Final transformed value after all handlers execute
    /// - Throws: Error if any handler throws
    public func invoke<T: Sendable>(hookName: String, args: T) async throws -> T {
        let handlers = _handlers.withLockedValue { $0[hookName] ?? [] }
        var result = args
        for handler in handlers {
            guard let typed = handler as? TypedHookHandler<T> else { continue }
            result = try await typed.handler(result)
        }
        return result
    }

    /// 📢 **Notify Handlers**
    ///
    /// Invokes all handlers for a named hook without expecting a return value.
    /// Use for events where handlers perform side effects without transforming data.
    ///
    /// - Parameters:
    ///   - hookName: The hook identifier
    ///   - args: Data to pass to handlers
    /// - Throws: Error if any handler throws
    public func notify<T: Sendable>(hookName: String, args: T) async throws {
        let handlers = _handlers.withLockedValue { $0[hookName] ?? [] }
        for handler in handlers {
            if let typed = handler as? TypedHookHandler<T> {
                _ = try await typed.handler(args)
            }
        }
    }

    /// 📊 **Get Handler Count**
    ///
    /// Returns the number of handlers registered for a specific hook.
    /// Useful for introspection and debugging hook registrations.
    ///
    /// - Parameter hookName: The hook identifier
    /// - Returns: Number of handlers registered for this hook (0 if none)
    public func handlerCount(for hookName: String) -> Int {
        _handlers.withLockedValue { $0[hookName]?.count ?? 0 }
    }
}

// MARK: - Internal Types

/// 🎣 **Type-Erased Hook Handler**
///
/// Internal protocol for type-erased hook handlers stored in the registry.
/// Enables storing handlers of different types in a single collection.
protocol AnyHookHandler: Sendable {}

/// 🎣 **Concrete Hook Handler Wrapper**
///
/// Type-safe wrapper for typed hook handlers.
/// Preserves the generic type information while allowing storage alongside other types.
struct TypedHookHandler<T: Sendable>: AnyHookHandler, Sendable {
    let handler: HookHandler<T>
}
