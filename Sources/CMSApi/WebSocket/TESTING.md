# WebSocket Real-Time Content Broadcasting - Testing Guide

## Overview
This document provides testing guidelines and examples for the WebSocket real-time content broadcasting system in SwiftCMS.

## Test Coverage Requirements

### Unit Tests (Sources)
- **ContentBroadcastHandler**: Test all event handling logic
- **WebSocketClientManager**: Test client lifecycle and command handling
- **Presence Tracking**: Test conflict detection and active editor tracking
- **Message Serialization**: Test JSON encoding/decoding of all message types

### Integration Tests
- **End-to-end message flow**: WebSocket client → Server → Broadcast → Receiving client
- **Multi-client scenarios**: Multiple clients editing same content
- **Authentication**: JWT token validation on WebSocket connections
- **Tenant isolation**: Ensure content is properly scoped by tenant
- **Redis pub/sub**: Verify cross-instance broadcasting when using Redis

### Performance Tests
- Concurrent connection handling (100+ clients)
- Message throughput under load
- Memory cleanup when clients disconnect
- Presence tracking performance with many active editors

## Test Implementation Examples

### 1. Testing ContentBroadcastHandler Events

```swift
import XCTest
import Vapor
import XCTVapor
@testable import CMSApi
@testable import CMSEvents

class ContentBroadcastHandlerTests: XCTestCase {
    var eventBus: EventBus!
    var handler: ContentBroadcastHandler!

    override func setUp() async throws {
        eventBus = InProcessEventBus()
        handler = ContentBroadcastHandler(eventBus: eventBus)
    }

    func testContentCreatedBroadcast() async throws {
        // Given
        let clientId = UUID()
        let client = createMockClient(id: clientId, subscribedTo: "posts")
        await handler.addClient(client)

        // When
        let event = ContentCreatedEvent(
            entryId: UUID(),
            contentType: "posts",
            entry: createTestEntry()
        )
        let context = CmsContext(logger: app.logger, userId: "user123")

        // Then - Verify client receives broadcast
        var receivedMessage: ContentBroadcastHandler.ContentChangeMessage?
        await handler.handleContentCreated(event, context: context)

        // Assertions
        XCTAssertNotNil(receivedMessage)
        XCTAssertEqual(receivedMessage?.data.action, .created)
        XCTAssertEqual(receivedMessage?.data.contentType, "posts")
    }
}
```

### 2. Testing WebSocketClientManager Commands

```swift
class WebSocketClientManagerTests: XCTestCase {
    var manager: WebSocketClientManager!
    var eventBus: EventBus!

    func testSubscribeCommand() async throws {
        // Given
        let ws = MockWebSocket()
        let identity = ClientIdentity(
            id: UUID(),
            sessionId: "test-session",
            userId: "user123"
        )

        // When
        await manager.registerClient(ws, identity: identity)

        let command = ClientCommand(
            action: .subscribe,
            contentType: "posts"
        )
        await manager.handleCommand(clientId: identity.id, command: command)

        // Then
        let messages = ws.sentMessages
        XCTAssertEqual(messages.count, 2) // Connected + Subscribed
        XCTAssertTrue(messages.last?.contains("subscribed") ?? false)
    }

    func testHeartbeatHandling() async throws {
        // Given
        let identity = ClientIdentity(
            id: UUID(),
            sessionId: "test-session",
            userId: "user123"
        )

        // When
        await manager.registerClient(ws, identity: identity)
        let command = ClientCommand(action: .heartbeat)
        await manager.handleCommand(clientId: identity.id, command: command)

        // Then
        let heartbeatAck = ws.sentMessages.last
        XCTAssertTrue(heartbeatAck?.contains("heartbeatAck") ?? false)
    }
}
```

### 3. Testing Conflict Detection

```swift
func testConflictDetection() async throws {
    // Given - Two users editing same entry
    let entryId = UUID()
    let user1 = createMockClient(id: UUID(), userId: "user1")
    let user2 = createMockClient(id: UUID(), userId: "user2")

    await handler.addClient(user1)
    await handler.addClient(user2)

    // When - User1 starts editing
    await handler.startEditing(clientId: user1.clientId, entryId: entryId, contentType: "posts")

    // Then - User2 should receive conflict warning
    await handler.startEditing(clientId: user2.clientId, entryId: entryId, contentType: "posts")

    XCTAssertTrue(user2.receivedConflictWarning)
    XCTAssertEqual(user2.conflictDetails?.conflictingUser.userId, "user1")
}
```

### 4. Testing Multi-Tenant Isolation

```swift
func testMultiTenantBroadcasting() async throws {
    // Given
    let tenant1Client = createMockClient(
        id: UUID(),
        userId: "user1",
        tenantId: "tenant1"
    )
    let tenant2Client = createMockClient(
        id: UUID(),
        userId: "user2",
        tenantId: "tenant2"
    )

    await handler.addClient(tenant1Client)
    await handler.addClient(tenant2Client)

    // When - Create event for tenant1
    let event = ContentCreatedEvent(
        entryId: UUID(),
        contentType: "posts",
        userId: "user1"
    )
    let context = CmsContext(
        logger: app.logger,
        userId: "user1",
        tenantId: "tenant1"
    )

    await handler.handleContentCreated(event, context: context)

    // Then
    XCTAssertTrue(tenant1Client.receivedEvent)
    XCTAssertFalse(tenant2Client.receivedEvent) // Tenant2 should NOT receive
}
```

## Testing Tools

### WebSocket Test Client (Node.js)

```javascript
// test-websocket.js
const WebSocket = require('ws');

const token = process.env.CMS_TOKEN;
const ws = new WebSocket(`ws://localhost:8080/ws?token=${token}`);

ws.on('open', () => {
  console.log('Connected to WebSocket');

  // Subscribe to content type
  ws.send(JSON.stringify({
    action: 'subscribe',
    contentType: 'posts'
  }));

  // Simulate editing
  setTimeout(() => {
    ws.send(JSON.stringify({
      action: 'editStart',
      contentType: 'posts',
      entryId: '123e4567-e89b-12d3-a456-426614174000'
    }));
  }, 1000);
});

ws.on('message', (data) => {
  const message = JSON.parse(data);
  console.log('Received:', message);

  switch(message.type) {
    case 'content_change':
      console.log(`Content changed: ${message.data.action}`);
      break;
    case 'conflict':
      console.log('Conflict detected!');
      break;
    case 'presence':
      console.log('Presence update:', message.data.activeEditors);
      break;
  }
});

// Test conflict detection
const ws2 = new WebSocket(`ws://localhost:8080/ws?token=${token}`);

ws2.on('open', () => {
  setTimeout(() => {
    ws2.send(JSON.stringify({
      action: 'editStart',
      contentType: 'posts',
      entryId: '123e4567-e89b-12d3-a456-426614174000' // Same entry!
    }));
  }, 3000); // Wait for first client to start editing
});

ws2.on('message', (data) => {
  const message = JSON.parse(data);
  if (message.type === 'conflict') {
    console.log('CONFLICT DETECTED:', message.data);
  }
});
```

### Load Test (Artillery)

```yaml
# websocket-load-test.yml
config:
  target: 'ws://localhost:8080'
  phases:
    - duration: 60
      arrivalRate: 10
  plugins:
    ensure: {}

scenarios:
  - name: 'WebSocket content editing'
    engine: ws
    flow:
      - send: '{{ $processEnvironment.CMS_TOKEN }}'

      - think: 1

      - send:
          action: 'subscribe'
          contentType: 'posts'

      - think: 2

      - send:
          action: 'editStart'
          contentType: 'posts'
          entryId: '123e4567-e89b-12d3-a456-426614174000'

      - think: 5

      - send:
          action: 'editStop'
          entryId: '123e4567-e89b-12d3-a456-426614174000'
```

## Manual Testing Checklist

### Basic Functionality
- [ ] Connect to WebSocket with valid JWT token
- [ ] Receive connection acknowledgment
- [ ] Subscribe to content type and receive confirmation
- [ ] Create content via REST API and receive broadcast
- [ ] Update content and receive broadcast
- [ ] Delete content and receive broadcast
- [ ] Unsubscribe and stop receiving broadcasts

### Presence & Conflict Detection
- [ ] Start editing content, notify other clients
- [ ] Multiple users editing shows conflict warning
- [ ] Stop editing removes from active editors
- [ ] Presence updates broadcast to all subscribers

### Advanced Scenarios
- [ ] Two browser tabs editing same content (same user)
- [ ] Disconnection cleanup (stale sessions removed)
- [ ] Heartbeat keeps connection alive
- [ ] Multi-tenant isolation (tenant1 changes not visible to tenant2)
- [ ] Redis pub/sub for multi-instance setup

### Error Handling
- [ ] Invalid JWT token rejected
- [ ] Malformed JSON handled gracefully
- [ ] Unknown commands return error
- [ ] Missing parameters return error
- [ ] Server errors logged appropriately

## Continuous Integration

Add to your CI pipeline:

```yaml
# .github/workflows/test.yml
- name: Run WebSocket Tests
  run: |
    swift test --filter CMSApiTests.WebSocket

- name: Start Test Server
  run: |
    swift run App &
    sleep 10

- name: Run Integration Tests
  env:
    CMS_TOKEN: ${{ secrets.TEST_JWT_TOKEN }}
  run: |
    npm run test:websocket
```

## Debugging

### Enable Debug Logging

```swift
// In configure.swift
app.logger.logLevel = .debug

// Or set environment variable
LOG_LEVEL=debug swift run App
```

### Common Issues

1. **Connection refused**: Check WebSocket endpoint is registered in routes.swift
2. **Authentication failed**: Verify JWT token is valid and includes required claims
3. **No broadcasts received**: Check client is subscribed to correct content type
4. **Conflict warnings not working**: Verify editStart/editStop commands are sent
5. **Memory leaks**: Ensure proper cleanup in onClose handlers

### Debug Messages

Enable WebSocket logging in Vapor to see all WebSocket events:

```swift
app.webSocket("ws", use: { req, ws in
    req.logger.debug("WebSocket upgrading connection")
    // ... existing code ...
})
```
