import Vapor
import CMSAuth
import CMSEvents

// MARK: - WebSocket Server

/// WebSocket server for real-time content events.
/// Endpoint: /ws?token=<jwt>
public struct WebSocketServer: Sendable {

    /// Active WebSocket connections tracked by an actor.
    actor ConnectionManager {
        var connections: [UUID: WebSocketClient] = [:]

        struct WebSocketClient {
            let id: UUID
            let ws: WebSocket
            var subscribedTypes: Set<String>
        }

        func add(_ client: WebSocketClient) {
            connections[client.id] = client
        }

        func remove(_ id: UUID) {
            connections.removeValue(forKey: id)
        }

        func subscribe(_ id: UUID, to contentType: String) {
            connections[id]?.subscribedTypes.insert(contentType)
        }

        func broadcast(event: String, contentType: String, data: String) async {
            for (_, client) in connections {
                // Send to clients subscribed to this content type, or all if no subscriptions
                if client.subscribedTypes.isEmpty || client.subscribedTypes.contains(contentType) {
                    try? await client.ws.send(data)
                }
            }
        }

        var count: Int { connections.count }
    }

    static let manager = ConnectionManager()

    /// Configure WebSocket routes on the application.
    public static func configure(app: Application) {
        app.webSocket("ws") { req, ws in
            Task {
                // Authenticate via ?token= query param
                guard let token = req.query[String.self, at: "token"] else {
                    try? await ws.close(code: .policyViolation)
                    return
                }

                // Verify token
                let authProvider = req.application.storage[AuthProviderKey.self]
                do {
                    _ = try await authProvider?.verify(token: token, on: req)
                } catch {
                    try? await ws.close(code: .policyViolation)
                    return
                }

                let clientId = UUID()
                let client = ConnectionManager.WebSocketClient(
                    id: clientId, ws: ws, subscribedTypes: []
                )
                await manager.add(client)

                let count = await manager.count
                req.logger.info("WebSocket connected: \(clientId) (total: \(count))")

                // Handle incoming messages (subscription requests)
                ws.onText { ws, text in
                    Task {
                        // Expected: {"subscribe": "contentType"}
                        if let data = text.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                           let contentType = json["subscribe"] {
                            await manager.subscribe(clientId, to: contentType)
                        }
                    }
                }

                ws.onClose.whenComplete { _ in
                    Task {
                        await manager.remove(clientId)
                        let remaining = await manager.count
                        req.logger.info("WebSocket disconnected: \(clientId) (remaining: \(remaining))")
                    }
                }
            }
        }

        // Subscribe to content events and broadcast
        app.eventBus.subscribe(ContentCreatedEvent.self) { event, context in
            let json = """
            {"event":"content.created","contentType":"\(event.contentType)","entryId":"\(event.entryId)"}
            """
            await manager.broadcast(event: "content.created", contentType: event.contentType, data: json)
        }

        app.eventBus.subscribe(ContentUpdatedEvent.self) { event, context in
            let json = """
            {"event":"content.updated","contentType":"\(event.contentType)","entryId":"\(event.entryId)"}
            """
            await manager.broadcast(event: "content.updated", contentType: event.contentType, data: json)
        }

        app.eventBus.subscribe(ContentDeletedEvent.self) { event, context in
            let json = """
            {"event":"content.deleted","contentType":"\(event.contentType)","entryId":"\(event.entryId)"}
            """
            await manager.broadcast(event: "content.deleted", contentType: event.contentType, data: json)
        }

        app.eventBus.subscribe(ContentPublishedEvent.self) { event, context in
            let json = """
            {"event":"content.published","contentType":"\(event.contentType)","entryId":"\(event.entryId)"}
            """
            await manager.broadcast(event: "content.published", contentType: event.contentType, data: json)
        }

        app.logger.info("WebSocket server configured at /ws")
    }
}
