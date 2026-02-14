# WebSocket API Documentation

SwiftCMS provides a WebSocket API for real-time communication, enabling live updates, collaborative editing, and instant notifications.

## Connecting to WebSocket

### Connection URL

```
ws://localhost:8080/ws
```

For production with SSL:
```
wss://yourapp.com/ws
```

### JavaScript Client Example

```javascript
const ws = new WebSocket('ws://localhost:8080/ws');

// Connection opened
ws.onopen = (event) => {
  console.log('Connected to SwiftCMS WebSocket');

  // Subscribe to events
  ws.send(JSON.stringify({
    action: 'subscribe',
    type: 'content.created',
    contentType: 'posts'
  }));
};

// Listen for messages
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Received:', data);

  // Handle different event types
  switch(data.type) {
    case 'content.created':
      handleContentCreated(data.payload);
      break;
    case 'content.updated':
      handleContentUpdated(data.payload);
      break;
    case 'system.heartbeat':
      // Keep connection alive
      break;
  }
};

// Connection closed
ws.onclose = (event) => {
  console.log('Disconnected from SwiftCMS');
  // Implement reconnection logic
};

// Handle errors
ws.onerror = (error) => {
  console.error('WebSocket error:', error);
};
```

### Swift Client Example

```swift
import Foundation

class SwiftCMSWebSocket: NSObject, URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private let url: URL

    init(url: URL) {
        self.url = url
        super.init()
    }

    func connect() {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        // Start receiving messages
        receiveMessage()

        // Send authentication
        authenticate()

        // Subscribe to events
        subscribeToEvents()
    }

    private func authenticate() {
        let message: [String: Any] = [
            "action": "authenticate",
            "token": "YOUR_JWT_TOKEN"
        ]
        send(message)
    }

    private func subscribeToEvents() {
        let subscribeMessage: [String: Any] = [
            "action": "subscribe",
            "type": "content.*",
            "contentType": "posts"
        ]
        send(subscribeMessage)
    }

    private func send(_ message: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Send error: \(error)")
            }
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // Continue receiving
            case .failure(let error):
                print("Receive error: \(error)")
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            print("Received: \(json)")

            // Handle based on type
            if let type = json["type"] as? String {
                DispatchQueue.main.async {
                    self.handleEvent(type: type, payload: json["payload"] as? [String: Any] ?? [:])
                }
            }

        case .data(let data):
            // Handle binary data if needed
            break

        @unknown default:
            break
        }
    }

    private func handleEvent(type: String, payload: [String: Any]) {
        switch type {
        case "content.created":
            // Handle content created
            break
        case "content.updated":
            // Handle content updated
            break
        case "system.heartbeat":
            // Respond to heartbeat
            send(["action": "pong"])
        default:
            break
        }
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
}

// Usage
let wsUrl = URL(string: "ws://localhost:8080/ws")!
let websocket = SwiftCMSWebSocket(url: wsUrl)
websocket.connect()
```

## Message Format

### Client to Server Messages

```json
{
  "action": "subscribe|unsubscribe|authenticate",
  "type": "event.type",
  "contentType": "posts",
  "token": "jwt_token"
}
```

### Server to Client Messages

```json
{
  "type": "content.created|content.updated|...",