import Vapor
import CMSAuth
import CMSEvents
import CMSObjects
import Redis

// MARK: - WebSocket Server

/// WebSocket server for real-time content events.
/// Endpoint: /ws?token=<jwt>
public struct WebSocketServer: Sendable {

    /// Enhanced WebSocket client with session and editing tracking.
    actor ConnectionManager {
        struct WebSocketClient {
            let id: UUID
            let sessionId: String
            let ws: WebSocket
            let userId: String
            let userEmail: String?
            var subscribedTypes: Set<String>
            var currentEditing: Set<UUID> // Set of entryIds being edited
        }

        struct EditingSession {
            let entryId: UUID
            let contentType: String
            let userId: String
            let userEmail: String?
            let startedAt: Date
        }

        var connections: [UUID: WebSocketClient] = [:]
        var editingSessions: [UUID: EditingSession] = [:] // Maps entryId to current editor
        var bufferedEvents: [String: [WebSocketEvent]] = [:] // sessionId -> events

        func add(_ client: WebSocketClient) {
            connections[client.id] = client
        }

        func remove(_ id: UUID) {
            // Clean up editing sessions
            if let client = connections[id] {
                for entryId in client.currentEditing {
                    editingSessions.removeValue(forKey: entryId)
                }
            }
            connections.removeValue(forKey: id)
        }

        func subscribe(_ id: UUID, to contentType: String) {
            connections[id]?.subscribedTypes.insert(contentType)
        }

        func startEditing(_ id: UUID, entryId: UUID, contentType: String) {
            guard var client = connections[id] else { return }

            // Check if someone else is editing
            if let existing = editingSessions[entryId] {
                if existing.userId != client.userId {
                    // Notify that editing is not possible
                    return
                }
            }

            // Update client state
            client.currentEditing.insert(entryId)
            connections[id] = client

            // Create editing session
            editingSessions[entryId] = EditingSession(
                entryId: entryId,
                contentType: contentType,
                userId: client.userId,
                userEmail: client.userEmail,
                startedAt: Date()
            )
        }

        func stopEditing(_ id: UUID, entryId: UUID) {
            guard var client = connections[id] else { return }
            client.currentEditing.remove(entryId)
            connections[id] = client
            editingSessions.removeValue(forKey: entryId)
        }

        func getClientBySession(_ sessionId: String) -> WebSocketClient? {
            return connections.values.first { $0.sessionId == sessionId }
        }

        func bufferEvent(for sessionId: String, _ event: WebSocketEvent) {
            bufferedEvents[sessionId, default: []].append(event)
        }

        func getBufferedEvents(for sessionId: String) -> [WebSocketEvent] {
            return bufferedEvents.removeValue(forKey: sessionId) ?? []
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

                // Verify token and get user info
                let authProvider = req.application.storage[AuthProviderKey.self]
                let authenticatedUser: AuthenticatedUser?
                do {
                    authenticatedUser = try await authProvider?.verify(token: token, on: req)
                } catch {
                    try? await ws.close(code: .policyViolation)
                    return
                }

                guard let user = authenticatedUser else {
                    try? await ws.close(code: .policyViolation)
                    return
                }

                // Generate session ID for reconnection support
                let sessionId = req.query[String.self, at: "sessionId"] ?? UUID().uuidString

                let clientId = UUID()
                let client = ConnectionManager.WebSocketClient(
                    id: clientId,
                    sessionId: sessionId,
                    ws: ws,
                    userId: user.userId,
                    userEmail: user.email,
                    subscribedTypes: [],
                    currentEditing: []
                )
                await manager.add(client)

                let count = await manager.count
                req.logger.info("WebSocket connected: \(clientId) (user: \(user.userId), session: \(sessionId), total: \(count))")

                // Send session info and buffered events
                let connectMessage: [String: Any] = [
                    "type": "connected",
                    "sessionId": sessionId,
                    "userId": user.userId,
                    "userEmail": user.email ?? NSNull(),
                    "serverTime": ISO8601DateFormatter().string(from: Date())
                ]

                if let jsonData = try? JSONSerialization.data(withJSONObject: connectMessage),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    try? await ws.send(jsonString)
                }

                // Send buffered events if reconnecting
                if req.query[String.self, at: "sessionId"] != nil {
                    let buffered = await manager.getBufferedEvents(for: sessionId)
                    for event in buffered {
                        if let jsonString = event.payloadJSON {
                            try? await ws.send(jsonString)
                        }
                    }
                }

                // Handle incoming messages
                ws.onText { _, text in
                    Task {
                        await self.handleMessage(clientId, text, req.logger)
                    }
                }

                ws.onClose.whenComplete { _ in
                    Task {
                        await manager.remove(clientId)
                        let remaining = await manager.count
                        req.logger.info("WebSocket disconnected: \(clientId) (user: \(user.userId), remaining: \(remaining))")
                    }
                }
            }
        }

        // Subscribe to content events and broadcast with enhanced payloads
        app.eventBus.subscribe(ContentCreatedEvent.self) { event, context in
            await broadcastContentEvent(event, context: context, app: app)
        }

        app.eventBus.subscribe(ContentUpdatedEvent.self) { event, context in
            await broadcastContentEvent(event, context: context, app: app)
        }

        app.eventBus.subscribe(ContentDeletedEvent.self) { event, context in
            await broadcastContentEvent(event, context: context, app: app)
        }

        app.eventBus.subscribe(ContentPublishedEvent.self) { event, context in
            await broadcastContentEvent(event, context: context, app: app)
        }

        app.eventBus.subscribe(UserEditingEvent.self) { event, context in
            await broadcastPresenceEvent(event, context: context, app: app)
        }

        app.eventBus.subscribe(UserStoppedEditingEvent.self) { event, context in
            await broadcastPresenceEvent(event, context: context, app: app)
        }

        app.logger.info("WebSocket server configured at /ws")
    }

    // MARK: - Message Handling

    private static func handleMessage(_ clientId: UUID, _ text: String, _ logger: Logger) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.warning("Invalid WebSocket message format")
            return
        }

        if let subscribe = json["subscribe"] as? String {
            await manager.subscribe(clientId, to: subscribe)
            logger.debug("Client \(clientId) subscribed to \(subscribe)")
        }

        if let type = json["type"] as? String {
            switch type {
            case "edit.start":
                if let entryIdString = json["entryId"] as? String,
                   let entryId = UUID(uuidString: entryIdString),
                   let contentType = json["contentType"] as? String {
                    await manager.startEditing(clientId, entryId: entryId, contentType: contentType)
                }
            case "edit.stop":
                if let entryIdString = json["entryId"] as? String,
                   let entryId = UUID(uuidString: entryIdString) {
                    await manager.stopEditing(clientId, entryId: entryId)
                }
            case "sync":
                // Client requesting full sync - could include current state info
                logger.debug("Client \(clientId) requested sync")
            default:
                break
            }
        }
    }

    // MARK: - Event Broadcasting

    private static func broadcastContentEvent<E: CmsEvent>(_ event: E, context: CmsContext, app: Application) async {
        let wsEvent: WebSocketEvent
        do {
            wsEvent = try WebSocketEvent(
                type: .content,
                name: E.eventName,
                data: event,
                userId: context.userId
            )
        } catch {
            context.logger.error("Failed to encode event: \(error)")
            return
        }

        // Buffer events for disconnected clients
        for (_, client) in await manager.connections {
            if client.subscribedTypes.isEmpty || client.subscribedTypes.contains(E.eventName) {
                await manager.bufferEvent(for: client.sessionId, wsEvent)
            }
        }

        // Broadcast to connected clients
        for (_, client) in await manager.connections {
            do {
                if let jsonString = wsEvent.payloadJSON {
                    try? await client.ws.send(jsonString)
                }
            } catch {
                context.logger.error("Failed to broadcast event: \(error)")
            }
        }
    }

    private static func broadcastPresenceEvent<E: CmsEvent>(_ event: E, context: CmsContext, app: Application) async {
        let wsEvent: WebSocketEvent
        do {
            wsEvent = try WebSocketEvent(
                type: .presence,
                name: E.eventName,
                data: event,
                userId: context.userId
            )
        } catch {
            context.logger.error("Failed to encode presence event: \(error)")
            return
        }

        for (_, client) in await manager.connections {
            do {
                if let jsonString = wsEvent.payloadJSON {
                    try? await client.ws.send(jsonString)
                }
            } catch {
                context.logger.error("Failed to broadcast presence event: \(error)")
            }
        }
    }
}

// MARK: - WebSocket Event Types

/// Enhanced WebSocket event with full data payloads
public struct WebSocketEvent: Codable, Sendable {
    public enum EventType: String, Codable, Sendable {
        case content
        case presence
        case system
    }

    public let type: EventType
    public let name: String
    public let data: AnyCodableValue
    public let userId: String?
    public let userEmail: String?
    public let timestamp: Date

    public init(type: EventType, name: String, data: AnyCodableValue, userId: String? = nil, userEmail: String? = nil) {
        self.type = type
        self.name = name
        self.data = data
        self.userId = userId
        self.userEmail = userEmail
        self.timestamp = Date()
    }

    public init<E: Encodable>(type: EventType, name: String, data: E, userId: String? = nil, userEmail: String? = nil) throws {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(data)
        let anyValue = try JSONDecoder().decode(AnyCodableValue.self, from: jsonData)

        self.type = type
        self.name = name
        self.data = anyValue
        self.userId = userId
        self.userEmail = userEmail
        self.timestamp = Date()
    }

    /// Convert to JSON string for WebSocket transmission
    public var payloadJSON: String? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]

            var payload: [String: Any] = [
                "type": type.rawValue,
                "name": name,
                "timestamp": ISO8601DateFormatter().string(from: timestamp),
                "data": try data.toJSONObject()
            ]

            if let userId = userId {
                payload["userId"] = userId
            }
            if let userEmail = userEmail {
                payload["userEmail"] = userEmail
            }

            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

// MARK: - ConnectionManager Extensions

extension WebSocketServer.ConnectionManager {
    func broadcastToClient(_ clientId: UUID, _ message: String) async {
        guard let client = connections[clientId] else { return }
        try? await client.ws.send(message)
    }
}

// MARK: - Helper Extensions

extension AnyCodableValue {
    func toJSONObject() throws -> Any {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return try JSONSerialization.jsonObject(with: data)
    }
}
