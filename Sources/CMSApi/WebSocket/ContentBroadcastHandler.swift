import Vapor
import CMSEvents
import CMSObjects

/// Main handler for broadcasting content changes to WebSocket clients.
/// Integrates with EventBus to listen for content events and broadcast them in real-time.
public actor ContentBroadcastHandler {

    /// Broadcast configuration for content type channels
    public struct BroadcastConfig {
        public let contentType: String
        public let channel: String
        public let includeEntryData: Bool
        public let broadcastScope: BroadcastScope

        public enum BroadcastScope {
            case allClients
            case subscribedOnly
            case tenantAware
        }

        public init(
            contentType: String,
            channel: String,
            includeEntryData: Bool = true,
            broadcastScope: BroadcastScope = .subscribedOnly
        ) {
            self.contentType = contentType
            self.channel = channel
            self.includeEntryData = includeEntryData
            self.broadcastScope = broadcastScope
        }
    }

    /// WebSocket content change message format
    public struct ContentChangeMessage: Content, Sendable {
        public let type: String
        public let timestamp: Date
        public let data: ContentChangeData

        public struct ContentChangeData: Content, Sendable {
            public let id: UUID
            public let contentType: String
            public let action: ContentAction
            public let entry: ContentEntryResponseDTO?
            public let editor: EditorInfo?
            public let conflict: ConflictInfo?

            public enum ContentAction: String, Codable, Sendable {
                case created
                case updated
                case deleted
                case published
                case unpublished
                case draft
                case versionCreated
                case versionRestored
            }

            public struct EditorInfo: Content, Sendable {
                public let userId: String
                public let userEmail: String?
                public let name: String?
                public let avatar: String?

                public init(userId: String, userEmail: String? = nil, name: String? = nil, avatar: String? = nil) {
                    self.userId = userId
                    self.userEmail = userEmail
                    self.name = name
                    self.avatar = avatar
                }
            }

            public struct ConflictInfo: Content, Sendable {
                public let warning: String
                public let lastModified: Date
                public let conflictingUser: EditorInfo
                public let suggestedAction: ConflictResolution

                public enum ConflictResolution: String, Codable, Sendable {
                    case overwrite
                    case merge
                    case discard
                    case cancel
                }
            }

            public init(
                id: UUID,
                contentType: String,
                action: ContentAction,
                entry: ContentEntryResponseDTO? = nil,
                editor: EditorInfo? = nil,
                conflict: ConflictInfo? = nil
            ) {
                self.id = id
                self.contentType = contentType
                self.action = action
                self.entry = entry
                self.editor = editor
                self.conflict = conflict
            }
        }

        public init(type: String, timestamp: Date, data: ContentChangeData) {
            self.type = type
            self.timestamp = timestamp
            self.data = data
        }
    }

    /// Client subscription management
    public struct ClientSubscription: Sendable {
        public let clientId: UUID
        public let sessionId: String
        public let userId: String
        public let userEmail: String?
        public let socket: WebSocket
        public var subscribedChannels: Set<String>
        public var currentContentType: String?
        public var editingEntryId: UUID?
        public var tenantId: String?

        public init(
            clientId: UUID,
            sessionId: String,
            userId: String,
            userEmail: String? = nil,
            socket: WebSocket,
            tenantId: String? = nil
        ) {
            self.clientId = clientId
            self.sessionId = sessionId
            self.userId = userId
            self.userEmail = userEmail
            self.socket = socket
            self.subscribedChannels = []
            self.currentContentType = nil
            self.editingEntryId = nil
            self.tenantId = tenantId
        }
    }

    /// Presence tracking for active editors
    public struct PresenceInfo: Sendable {
        public let entryId: UUID
        public let contentType: String
        public let activeEditors: Set<EditorPresence>
        public let lastActivity: Date

        public struct EditorPresence: Sendable, Hashable {
            public let userId: String
            public let userEmail: String?
            public let name: String?
            public let sessionId: String
            public let connectedAt: Date

            public init(userId: String, userEmail: String? = nil, name: String? = nil, sessionId: String) {
                self.userId = userId
                self.userEmail = userEmail
                self.name = name
                self.sessionId = sessionId
                self.connectedAt = Date()
            }
        }
    }

    // MARK: - Properties

    private var clients: [UUID: ClientSubscription] = [:]
    private var presence: [UUID: PresenceInfo] = [:] // entryId -> PresenceInfo
    private let eventBus: EventBus
    private var subscriptions: Set<UUID> = []

    // MARK: - Initialization

    public init(eventBus: EventBus) {
        self.eventBus = eventBus
        setupEventSubscriptions()
    }

    // MARK: - Client Management

    public func addClient(_ client: ClientSubscription) {
        clients[client.clientId] = client
    }

    public func removeClient(_ clientId: UUID) {
        // Clean up presence information
        if let client = clients[clientId] {
            if let editingId = client.editingEntryId {
                removeEditorFromPresence(entryId: editingId, userId: client.userId)
            }
        }
        clients.removeValue(forKey: clientId)
    }

    public func subscribeClient(_ clientId: UUID, to contentType: String) {
        guard var client = clients[clientId] else { return }

        let channel = "content/\(contentType)"
        client.subscribedChannels.insert(channel)
        client.currentContentType = contentType
        clients[clientId] = client
    }

    public func unsubscribeClient(_ clientId: UUID, from contentType: String) {
        guard var client = clients[clientId] else { return }

        let channel = "content/\(contentType)"
        client.subscribedChannels.remove(channel)

        if client.currentContentType == contentType {
            client.currentContentType = nil
        }

        clients[clientId] = client
    }

    public func startEditing(clientId: UUID, entryId: UUID, contentType: String) {
        guard let client = clients[clientId] else { return }

        // Check for conflicts
        if let existingPresence = presence[entryId],
           existingPresence.activeEditors.count > 0 {
            // Notify current editor about potential conflict
            Task {
                await notifyConflict(
                    entryId: entryId,
                    currentUserId: client.userId,
                    conflictingUsers: existingPresence.activeEditors
                )
            }
        }

        // Update client state
        clients[clientId]?.editingEntryId = entryId
        clients[clientId]?.currentContentType = contentType

        // Update presence
        let editorPresence = PresenceInfo.EditorPresence(
            userId: client.userId,
            userEmail: client.userEmail,
            sessionId: client.sessionId
        )
        updatePresence(entryId: entryId, contentType: contentType, editor: editorPresence)

        // Notify other subscribers
        broadcastPresenceUpdate(entryId: entryId, contentType: contentType)
    }

    public func stopEditing(clientId: UUID, entryId: UUID) {
        guard let client = clients[clientId] else { return }

        // Update client state
        if clients[clientId]?.editingEntryId == entryId {
            clients[clientId]?.editingEntryId = nil
        }

        // Update presence
        removeEditorFromPresence(entryId: entryId, userId: client.userId)

        // Notify other subscribers
        broadcastPresenceUpdate(entryId: entryId, contentType: client.currentContentType ?? "unknown")
    }

    // MARK: - Event Handling

    private func setupEventSubscriptions() {
        // Subscribe to content events
        subscribeToContentEvents()
        subscribeToPresenceEvents()
    }

    private func subscribeToContentEvents() {
        // Content Created
        let createdSub = eventBus.subscribe(ContentCreatedEvent.self) { [weak self] event, context in
            await self?.handleContentCreated(event, context: context)
        }
        subscriptions.insert(createdSub)

        // Content Updated
        let updatedSub = eventBus.subscribe(ContentUpdatedEvent.self) { [weak self] event, context in
            await self?.handleContentUpdated(event, context: context)
        }
        subscriptions.insert(updatedSub)

        // Content Deleted
        let deletedSub = eventBus.subscribe(ContentDeletedEvent.self) { [weak self] event, context in
            await self?.handleContentDeleted(event, context: context)
        }
        subscriptions.insert(deletedSub)

        // Content Published
        let publishedSub = eventBus.subscribe(ContentPublishedEvent.self) { [weak self] event, context in
            await self?.handleContentPublished(event, context: context)
        }
        subscriptions.insert(publishedSub)
    }

    private func subscribeToPresenceEvents() {
        // User Editing
        let editingSub = eventBus.subscribe(UserEditingEvent.self) { [weak self] event, context in
            await self?.handleUserEditing(event, context: context)
        }
        subscriptions.insert(editingSub)

        // User Stopped Editing
        let stoppedEditingSub = eventBus.subscribe(UserStoppedEditingEvent.self) { [weak self] event, context in
            await self?.handleUserStoppedEditing(event, context: context)
        }
        subscriptions.insert(stoppedEditingSub)
    }

    // MARK: - Event Handlers

    private func handleContentCreated(_ event: ContentCreatedEvent, context: CmsContext) async {
        let message = ContentChangeMessage(
            type: "content_change",
            timestamp: event.timestamp,
            data: .init(
                id: event.entryId,
                contentType: event.contentType,
                action: .created,
                entry: event.entry
            )
        )

        await broadcastMessage(message, for: event.contentType, context: context)
    }

    private func handleContentUpdated(_ event: ContentUpdatedEvent, context: CmsContext) async {
        let message = ContentChangeMessage(
            type: "content_change",
            timestamp: event.timestamp,
            data: .init(
                id: event.entryId,
                contentType: event.contentType,
                action: .updated,
                entry: event.entry
            )
        )

        await broadcastMessage(message, for: event.contentType, context: context)
    }

    private func handleContentDeleted(_ event: ContentDeletedEvent, context: CmsContext) async {
        let message = ContentChangeMessage(
            type: "content_change",
            timestamp: Date(),
            data: .init(
                id: event.entryId,
                contentType: event.contentType,
                action: .deleted,
                entry: nil // Entry is deleted so we don't include it
            )
        )

        await broadcastMessage(message, for: event.contentType, context: context)
    }

    private func handleContentPublished(_ event: ContentPublishedEvent, context: CmsContext) async {
        let message = ContentChangeMessage(
            type: "content_change",
            timestamp: event.timestamp,
            data: .init(
                id: event.entryId,
                contentType: event.contentType,
                action: .published,
                entry: event.entry
            )
        )

        await broadcastMessage(message, for: event.contentType, context: context)
    }

    private func handleUserEditing(_ event: UserEditingEvent, context: CmsContext) async {
        broadcastPresenceUpdate(entryId: event.entryId, contentType: event.contentType)
    }

    private func handleUserStoppedEditing(_ event: UserStoppedEditingEvent, context: CmsContext) async {
        broadcastPresenceUpdate(entryId: event.entryId, contentType: event.contentType)
    }

    // MARK: - Broadcasting

    private func broadcastMessage(_ message: ContentChangeMessage, for contentType: String, context: CmsContext) async {
        let channel = "content/\(contentType)"

        for (_, client) in clients {
            // Check subscription
            guard client.subscribedChannels.contains(channel) else { continue }

            // Check tenant isolation if needed
            if let eventTenantId = context.tenantId,
               let clientTenantId = client.tenantId,
               eventTenantId != clientTenantId {
                continue
            }

            // Send message
            do {
                let jsonData = try JSONEncoder().encode(message)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    try? await client.socket.send(jsonString)
                }
            } catch {
                context.logger.error("Failed to encode broadcast message: \(error)")
            }
        }
    }

    private func broadcastPresenceUpdate(entryId: UUID, contentType: String) {
        guard let info = presence[entryId] else { return }

        let presenceMessage: [String: Any] = [
            "type": "presence",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "data": [
                "entryId": entryId,
                "contentType": contentType,
                "activeEditors": info.activeEditors.map { editor in
                    return [
                        "userId": editor.userId,
                        "userEmail": editor.userEmail,
                        "name": editor.name
                    ]
                }
            ]
        ]

        // Send to all clients subscribed to this content type
        let channel = "content/\(contentType)"
        Task {
            for (_, client) in self.clients {
                if client.subscribedChannels.contains(channel) {
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: presenceMessage)
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            try? await client.socket.send(jsonString)
                        }
                    } catch {
                        // Log error
                    }
                }
            }
        }
    }

    private func notifyConflict(entryId: UUID, currentUserId: String, conflictingUsers: Set<PresenceInfo.EditorPresence>) async {
        guard let conflict = conflictingUsers.first else { return }

        for (_, client) in clients {
            if client.userId == currentUserId {
                let conflictMessage: [String: Any] = [
                    "type": "conflict",
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "data": [
                        "entryId": entryId,
                        "warning": "This content is being edited by another user",
                        "conflictingUser": [
                            "userId": conflict.userId,
                            "userEmail": conflict.userEmail
                        ],
                        "suggestedAction": "merge"
                    ]
                ]

                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: conflictMessage)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        try? await client.socket.send(jsonString)
                    }
                } catch {
                    // Log error
                }
            }
        }
    }

    // MARK: - Presence Management

    private func updatePresence(entryId: UUID, contentType: String, editor: PresenceInfo.EditorPresence) {
        if var info = presence[entryId] {
            info.activeEditors.insert(editor)
            info.lastActivity = Date()
            presence[entryId] = info
        } else {
            let info = PresenceInfo(
                entryId: entryId,
                contentType: contentType,
                activeEditors: [editor],
                lastActivity: Date()
            )
            presence[entryId] = info
        }
    }

    private func removeEditorFromPresence(entryId: UUID, userId: String) {
        guard var info = presence[entryId] else { return }

        info.activeEditors.removeAll { $0.userId == userId }

        if info.activeEditors.isEmpty {
            presence.removeValue(forKey: entryId)
        } else {
            info.lastActivity = Date()
            presence[entryId] = info
        }
    }

    // MARK: - Cleanup

    public func cleanup() {
        // Remove any event subscriptions
        for subscriptionId in subscriptions {
            eventBus.unsubscribe(id: subscriptionId)
        }
        subscriptions.removeAll()

        // Clear client and presence data
        clients.removeAll()
        presence.removeAll()
    }
}

// MARK: - Helpers

extension UUID: @retroactive Sendable {}
extension String: @retroactive Sendable {}
