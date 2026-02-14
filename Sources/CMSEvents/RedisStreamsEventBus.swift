import Vapor
@preconcurrency import Redis
import CMSObjects

/// Redis Streams-backed EventBus for multi-instance deployments.
/// Events are published to Redis streams (cms:{eventName}) and can be
/// consumed by any instance in the cluster.
public actor RedisStreamsEventBus: EventBus {
    private var handlers: [String: [(UUID, Any)]] = [:]
    private let redis: RedisClient?
    private let consumerGroup: String

    public init(redis: RedisClient?, consumerGroup: String = "swiftcms") {
        self.redis = redis
        self.consumerGroup = consumerGroup
    }

    public func publish<E: CmsEvent>(event: E, context: CmsContext) async throws {
        let eventName = E.eventName

        // Publish to Redis Stream if available
        if let redis = redis {
            let payload = try JSONEncoder().encode(event)
            let payloadString = String(data: payload, encoding: .utf8) ?? "{}"

            // XADD to Redis Stream
            do {
                _ = try await redis.send(
                    command: "XADD",
                    with: [
                        .init(from: "cms:\(eventName)"),
                        .init(from: "*"),
                        .init(from: "payload"),
                        .init(from: payloadString),
                    ]
                ).get()
                context.logger.debug("Redis Streams: published \(eventName)")
            } catch {
                context.logger.warning("Redis Streams publish failed: \(error), falling back to in-process")
            }
        }

        // Also dispatch in-process for local handlers
        guard let eventHandlers = handlers[eventName] else { return }
        for (_, handler) in eventHandlers {
            if let typedHandler = handler as? (E, CmsContext) async throws -> Void {
                do {
                    try await typedHandler(event, context)
                } catch {
                    context.logger.error("RedisStreamsEventBus handler error for \(eventName): \(error)")
                }
            }
        }
    }

    @discardableResult
    public nonisolated func subscribe<E: CmsEvent>(_ type: E.Type, handler: @escaping @Sendable (E, CmsContext) async throws -> Void) -> UUID {
        let id = UUID()
        Task {
            await self.addHandler(eventName: E.eventName, id: id, handler: handler)
        }
        return id
    }

    public nonisolated func unsubscribe(id: UUID) {
        Task {
            await self.removeHandler(id: id)
        }
    }

    // MARK: - Private

    private func addHandler(eventName: String, id: UUID, handler: Any) {
        if handlers[eventName] == nil {
            handlers[eventName] = []
        }
        handlers[eventName]?.append((id, handler))
    }

    private func removeHandler(id: UUID) {
        for (key, value) in handlers {
            handlers[key] = value.filter { $0.0 != id }
        }
    }
}

// MARK: - EventBus Factory

/// Creates the appropriate EventBus based on configuration.
public struct EventBusFactory {
    public static func create(app: Application) -> EventBus {
        if Environment.get("REDIS_URL") != nil && Environment.get("EVENT_BUS") == "redis" {
            app.logger.info("Using Redis Streams EventBus")
            return RedisStreamsEventBus(redis: app.redis, consumerGroup: "swiftcms")
        } else {
            app.logger.info("Using In-Process EventBus")
            return InProcessEventBus()
        }
    }
}
