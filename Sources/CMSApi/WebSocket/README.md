# WebSocket Real-Time Content Broadcasting

This directory contains the WebSocket implementation for SwiftCMS, providing real-time content change broadcasts to connected clients.

## Architecture

The WebSocket implementation consists of three main components:

1. **ContentBroadcastHandler** (`ContentBroadcastHandler.swift`)
   - Listens to content events via EventBus
   - Manages client subscriptions to content type channels
   - Handles presence tracking for active editors
   - Broadcasts content changes to subscribed clients

2. **WebSocketClientManager** (`WebSocketClientManager.swift`)
   - Manages WebSocket client connections
   - Handles client commands (subscribe/unsubscribe/edit notifications)
   - Provides heartbeat mechanism for connection health
   - Manages conflict detection and resolution

3. **WebSocketServer** (`/Users/gurindersingh/Documents/Developer/Swift-CMS/Sources/App/WebSocket/`)
   - Main WebSocket endpoint configuration
   - Integrates with the client manager and broadcast handler
   - Handles WebSocket lifecycle and authentication

## Features

### Real-Time Content Updates
- Automatic broadcasting of content changes (create, update, delete, publish)
- Channel-based subscriptions per content type
- Multi-tenant isolation support
- Redis pub/sub integration for multi-instance scaling

### Presence Tracking
- Real-time visibility of active editors per content entry
- Conflict detection when multiple users edit the same content
- Automatic cleanup when users stop editing or disconnect

### Client Commands
Clients can send commands via JSON messages:

```json
// Subscribe to content type
{
  "action": "subscribe",
  "contentType": "posts"
}

// Unsubscribe
{
  "action": "unsubscribe",
  "contentType": "posts"
}

// Start editing (triggers presence tracking)
{
  "action": "editStart",
  "contentType": "posts",
  "entryId": "123e4567-e89b-12d3-a456-426614174000"
}

// Stop editing
{
  "action": "editStop",
  "entryId": "123e4567-e89b-12d3-a456-426614174000"
}

// Keep-alive heartbeat
{
  "action": "heartbeat"
}
```

### Server Messages
The server broadcasts messages in this format:

```json
// Content change notification
{
  "type": "content_change",
  "timestamp": "2026-01-15T10:30:00Z",
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "contentType": "posts",
    "action": "updated",
    "entry": { /* full entry data */ },
    "editor": {
      "userId": "user123",
      "userEmail": "user@example.com"
    }
  }
}

// Presence update
{
  "type": "presence",
  "timestamp": "2026-01-15T10:30:00Z",
  "data": {
    "entryId": "123e4567-e89b-12d3-a456-426614174000",
    "contentType": "posts",
    "activeEditors": [
      {
        "userId": "user123",
        "userEmail": "user@example.com"
      }
    ]
  }
}

// Conflict warning
{
  "type": "conflict",
  "timestamp": "2026-01-15T10:30:00Z",
  "data": {
    "entryId": "123e4567-e89b-12d3-a456-426614174000",
    "warning": "This content is being edited by another user",
    "conflictingUser": {
      "userId": "user456",
      "userEmail": "other@example.com"
    },
    "suggestedAction": "merge"
  }
}
```

## Usage

### Client Connection
```javascript
// Connect with authentication token
const ws = new WebSocket('ws://localhost:8080/ws?token=YOUR_JWT_TOKEN');

ws.onopen = () => {
  // Connection established
  ws.send(JSON.stringify({
    action: 'subscribe',
    contentType: 'posts'
  }));
};

ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  console.log('Received:', message);

  switch(message.type) {
    case 'content_change':
      handleContentChange(message.data);
      break;
    case 'presence':
      updateActiveEditors(message.data);
      break;
    case 'conflict':
      showConflictWarning(message.data);
      break;
  }
};
```

### Server-Side Events
Content changes are automatically broadcast from REST API actions:

```swift
// In DynamicContentController.swift
// REST API calls automatically trigger WebSocket broadcasts

// POST /api/v1/posts - Creates content and broadcasts to "content/posts" channel
// PUT /api/v1/posts/:id - Updates content and broadcasts
// DELETE /api/v1/posts/:id - Deletes content and broadcasts
```

## Multi-Instance Scaling

For deployments with multiple server instances, enable Redis pub/sub:

```swift
// In configure.swift
app.configureEnhancedWebSockets()

// The RedisWebSocketBridge will automatically handle cross-instance broadcasting
```

## Integration with ContentEntryService

The WebSocket system integrates with `ContentEntryService` which automatically publishes events:
- `ContentCreatedEvent` - when entries are created
- `ContentUpdatedEvent` - when entries are updated
- `ContentDeletedEvent` - when entries are deleted
- `ContentPublishedEvent` - when entries are published

These events flow through the EventBus to the ContentBroadcastHandler, which then broadcasts to connected WebSocket clients based on their subscriptions.

## Performance Considerations

- Client connections are actor-isolated for thread safety
- Presence tracking uses efficient Set operations
- Message buffering prevents overwhelming slow clients
- Automatic cleanup of stale connections after 5 minutes of no heartbeat
- Redis pub/sub allows horizontal scaling

## Security

- WebSocket connections require JWT authentication
- Tenant isolation ensures multi-tenant data security
- Rate limiting on WebSocket endpoint (via global middleware)
- Message validation prevents malformed data injection

## Testing

```bash
# Run all tests
swift test --filter CMSApi.WebSocket

# Test WebSocket connections
wscat -c "ws://localhost:8080/ws?token=YOUR_TOKEN"
```

## Future Enhancements

- [ ] Message acknowledgment system
- [ ] Offline message queuing
- [ ] Binary message support for large payloads
- [ ] Advanced presence features (typing indicators, read receipts)
- [ ] Message persistence for chat-like features