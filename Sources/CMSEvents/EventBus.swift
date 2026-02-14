import Vapor

/// Protocol defining the EventBus contract.
public protocol EventBus: Sendable {
    /// Publish an event to all registered handlers.
    func publish<E: CmsEvent>(event: E, context: CmsContext) async throws

    /// Subscribe a handler for a specific event type.
    /// - Returns: Subscription ID for later unsubscription.
    @discardableResult
    func subscribe<E: CmsEvent>(
        _ eventType: E.Type,
        handler: @escaping @Sendable (E, CmsContext) async throws -> Void
    ) -> UUID

    /// Remove a subscription by ID.
    func unsubscribe(id: UUID)
}

/// Actor-based in-process EventBus implementation.
/// Suitable for single-instance deployments.
public actor InProcessEventBus: EventBus {
    private var handlers: [String: [(id: UUID, handler: AnyEventHandler)]] = [:]

    public init() {}

    public func publish<E: CmsEvent>(event: E, context: CmsContext) async throws {
        let eventName = E.eventName
        guard let eventHandlers = handlers[eventName] else { return }

        for (_, handler) in eventHandlers {
            guard let typed = handler as? TypedEventHandler<E> else { continue }
            do {
                try await typed.handle(event: event, context: context)
            } catch {
                context.logger.error("Event handler error for \(eventName): \(error)")
            }
        }
    }

    @discardableResult
    public nonisolated func subscribe<E: CmsEvent>(
        _ eventType: E.Type,
        handler: @escaping @Sendable (E, CmsContext) async throws -> Void
    ) -> UUID {
        let id = UUID()
        let typed = TypedEventHandler(handler: handler)
        // We need to use a detached task to interact with the actor
        Task {
            await self.addHandler(eventName: E.eventName, id: id, handler: typed)
        }
        return id
    }

    public nonisolated func unsubscribe(id: UUID) {
        Task {
            await self.removeHandler(id: id)
        }
    }

    // MARK: - Private

    private func addHandler(eventName: String, id: UUID, handler: AnyEventHandler) {
        var list = handlers[eventName] ?? []
        list.append((id: id, handler: handler))
        handlers[eventName] = list
    }

    private func removeHandler(id: UUID) {
        for (key, var list) in handlers {
            list.removeAll { $0.id == id }
            handlers[key] = list
        }
    }
}

// MARK: - Handler Types

protocol AnyEventHandler: Sendable {}

struct TypedEventHandler<E: CmsEvent>: AnyEventHandler, Sendable {
    let handler: @Sendable (E, CmsContext) async throws -> Void

    func handle(event: E, context: CmsContext) async throws {
        try await handler(event, context)
    }
}

// MARK: - Application Extension

extension Application {
    private struct EventBusKey: StorageKey {
        typealias Value = EventBus
    }

    /// The application's EventBus instance.
    public var eventBus: EventBus {
        get {
            if let existing = storage[EventBusKey.self] {
                return existing
            }
            let bus = InProcessEventBus()
            storage[EventBusKey.self] = bus
            return bus
        }
        set {
            storage[EventBusKey.self] = newValue
        }
    }
}

extension Request {
    /// Access the EventBus from a request.
    public var eventBus: EventBus {
        application.eventBus
    }
}
