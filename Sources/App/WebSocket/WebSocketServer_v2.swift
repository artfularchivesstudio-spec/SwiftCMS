import Vapor
import CMSAuth
import CMSEvents
import CMSObjects
import CMSApi
import Redis

/// Enhanced WebSocket server v2 that integrates with WebSocketClientManager and ContentBroadcastHandler
public struct WebSocketServer_v2: Sendable {

    /// Configure WebSocket routes on the application.
    public static func configure(app: Application) {
        // Initialize WebSocket client manager
        app.configureWebSocketClientManager(eventBus: app.eventBus, logger: app.logger)

        app.webSocket("ws") { req, ws in
            Task {
                do {
                    // Authenticate via ?token= query param
                    guard let clientIdentity = try await req.authenticateWebSocketToken() else {
                        try? await ws.close(code: .policyViolation, reason: "Authentication failed")
                        return
                    }

                    guard let manager = req.webSocketClientManager else {
                        try? await ws.close(code: .internalError, reason: "Server not ready")
                        return
                    }

                    // Register client with manager
                    await manager.registerClient(ws, identity: clientIdentity)

                    req.logger.info("WebSocket client connected", metadata: [
                        "clientId": "\(clientIdentity.id)",
                        "userId": "\(clientIdentity.userId)",
                        "sessionId": "\(clientIdentity.sessionId)"
                    ])

                } catch {
                    req.logger.error("WebSocket authentication failed", metadata: ["error": "\(error)"])
                    try? await ws.close(code: .policyViolation, reason: "Authentication failed")
                }
            }
        }

        // Subscribe to content events for enhanced broadcasting
        app.eventBus.subscribe(ContentCreatedEvent.self) { event, context in
            await handleContentEvent(event, context: context, app: app)
        }

        app.eventBus.subscribe(ContentUpdatedEvent.self) { event, context in
            await handleContentEvent(event, context: context, app: app)
        }

        app.eventBus.subscribe(ContentDeletedEvent.self) { event, context in
            await handleContentEvent(event, context: context, app: app)
        }

        app.eventBus.subscribe(ContentPublishedEvent.self) { event, context in
            await handleContentEvent(event, context: context, app: app)
        }

        // Subscribe to presence events
        app.eventBus.subscribe(UserEditingEvent.self) { event, context in
            await handlePresenceEvent(event, context: context)
        }

        app.eventBus.subscribe(UserStoppedEditingEvent.self) { event, context in
            await handlePresenceEvent(event, context: context)
        }

        app.logger.info("WebSocket server v2 configured at /ws")
    }

    private static func handleContentEvent<E: CmsEvent>(_ event: E, context: CmsContext, app: Application) async {
        // For now, let the ContentBroadcastHandler handle all broadcasting
        // This could be enhanced for multi-instance scaling with Redis pub/sub
    }

    private static func handlePresenceEvent<E: CmsEvent>(_ event: E, context: CmsContext) async {
        // Presence events are handled by the ContentBroadcastHandler
    }
}

// MARK: - WebSocket Event Message Types

/// Convenience struct for creating WebSocket event messages
public struct WebSocketEventMessage: Codable, Sendable {
    public let type: String
    public let timestamp: Date
    public let data: EventData

    public struct EventData: Codable, Sendable {
        public let entryId: UUID
        public let contentType: String
        public let action: String
        public let entry: ContentEntryResponseDTO?
        public let userId: String?
        public let userEmail: String?

        public init(
            entryId: UUID,
            contentType: String,
            action: String,
            entry: ContentEntryResponseDTO? = nil,
            userId: String? = nil,
            userEmail: String? = nil
        ) {
            self.entryId = entryId
            self.contentType = contentType
            self.action = action
            self.entry = entry
            self.userId = userId
            self.userEmail = userEmail
        }
    }

    public init(type: String, timestamp: Date, data: EventData) {
        self.type = type
        self.timestamp = timestamp
        self.data = data
    }
}

// MARK: - Redis Pub/Sub Extension for Multi-Instance Scaling

/// Redis-based pub/sub for WebSocket broadcasting across multiple server instances
public actor RedisWebSocketBridge {
    private let redis: Application.Redis
    private let manager: WebSocketClientManager
    private var subscribedChannels: Set<String> = []

    public init(redis: Application.Redis, manager: WebSocketClientManager) {
        self.redis = redis
        self.manager = manager
    }

    public func subscribeToContentType(_ contentType: String) async throws {
        let channel = "ws:content:\(contentType)"

        guard !subscribedChannels.contains(channel) else { return }

        try await redis.subscribe(to: RedisChannelName(stringLiteral: channel)) { [weak self] message in
            Task {
                await self?.handleRedisMessage(message, channel: channel)
            }
        }

        subscribedChannels.insert(channel)
    }

    public func unsubscribeFromContentType(_ contentType: String) async throws {
        let channel = "ws:content:\(contentType)"

        guard subscribedChannels.contains(channel) else { return }

        try await redis.unsubscribe(from: RedisChannelName(stringLiteral: channel))
        subscribedChannels.remove(channel)
    }

    public func broadcastMessage(_ message: ContentBroadcastHandler.ContentChangeMessage, to contentType: String) async throws {
        let channel = "ws:content:\(contentType)"

        let jsonData = try JSONEncoder().encode(message)
        try await redis.publish(jsonData, to: RedisChannelName(stringLiteral: channel))
    }

    private func handleRedisMessage(_ message: RedisMessage, channel: String) async {
        guard let messageData = message.string else { return }

        do {
            let contentMessage = try JSONDecoder().decode(ContentBroadcastHandler.ContentChangeMessage.self, from: Data(messageData.utf8))
            // Forward to local clients via manager
            await broadcastToLocalClients(message: contentMessage, channel: channel)
        } catch {
            // Log error
        }
    }

    private func broadcastToLocalClients(message: ContentBroadcastHandler.ContentChangeMessage, channel: String) async {
        // Implementation to send message to local clients
        // This would integrate with the WebSocketClientManager
    }
}

// MARK: - Configuration Extension

extension Application {
    /// Configure enhanced WebSocket server
    public func configureEnhancedWebSockets() {
        WebSocketServer_v2.configure(app: self)
    }
}
