# Webhook Delivery with DLQ Implementation Summary

## Overview
This implementation provides reliable webhook delivery with exponential backoff retry and Dead Letter Queue (DLQ) support for SwiftCMS.

## Features Implemented

### 1. WebhookDispatcher (CMSJobs/WebhookDispatcher.swift)
- Listens to all CmsEvents (content.created, content.updated, content.deleted, content.published, content.stateChanged, schema.changed, media.uploaded, media.deleted)
- Filters webhooks based on event subscriptions
- Implements idempotency with 60-second deduplication window
- Creates WebhookDelivery records with full event payloads
- Enqueues WebhookDeliveryJob for background processing

### 2. WebhookDeliveryJob (CMSJobs/WebhookDeliveryJob.swift)
- Performs actual HTTP POST delivery to webhook URLs
- Signs payload with HMAC-SHA256 signature (X-SwiftCMS-Signature header)
- Implements exponential backoff retry schedule: 1s, 2s, 4s, 8s, 16s (5 attempts)
- Tracks delivery attempts in webhook_deliveries table
- Moves failed deliveries to DLQ after exhausting retries

### 3. WebhookDLQController (CMSApi/Admin/WebhookDLQController.swift)
- Provides admin UI at `/admin/webhooks/dlq`
- Supports filtering DLQ entries by event type, retry count, etc.
- Implements retry operations:
  - Single entry retry: `/admin/webhooks/dlq/:entryId/retry`
  - Bulk retry all: `/admin/webhooks/dlq/retry-all`
- Implements delete operation: `/admin/webhooks/dlq/:entryId` (DELETE)
- Supports both HTML and JSON responses for AJAX operations

### 4. Admin UI (Resources/Views/admin/webhooks/dlq.leaf)
- Displays failed webhook deliveries with event type, webhook URL, failure reason
- Shows retry count and last failed timestamp
- Provides Retry and Delete actions with HTMX support
- Auto-refreshes every 30 seconds when page is visible
- Responsive design with tooltips for failure reasons

### 5. Webhook Models (CMSSchema/SystemModels.swift)

#### Webhook model fields:
- `id`, `name`, `url` - basic webhook configuration
- `events` - Array of subscribed event names
- `headers` - Custom headers to include in deliveries
- `secret` - For HMAC-SHA256 signature generation
- `enabled` - Toggle webhook on/off
- `retryCount` - Maximum retry attempts (default 5)

#### WebhookDelivery model fields:
- `id`, `webhookId` - Delivery identification
- `event` - Event name that triggered the delivery
- `payload` - Full event payload as JSON
- `idempotencyKey` - For deduplication
- `responseStatus` - HTTP response code from webhook endpoint
- `attempts` - Number of delivery attempts made
- `deliveredAt` - Timestamp of successful delivery
- `createdAt` - When the delivery was created

#### DeadLetterEntry model fields:
- `id`, `jobType` - Job identification ("webhook_delivery")
- `payload` - The original webhook payload
- `failureReason` - Error message from final failure
- `retryCount` - Total attempts made before DLQ
- `firstFailedAt`, `lastFailedAt` - Failure tracking

## Configuration

### In configure.swift:
1. Initialize WebhookDispatcher: `let webhookDispatcher = WebhookDispatcher()`
2. Configure it: `webhookDispatcher.configure(app: app)`
3. Register WebhookDeliveryJob: `app.queues.add(WebhookDeliveryJob())`

### Middleware and Routes:
1. WebhookDLQController registered in routes.swift
2. Admin navigation updated to include DLQ link
3. Session authentication required for admin access

## Security Features

### HMAC-SHA256 Signature
```swift
private func computeHMAC(data: Data, secret: String) -> String {
    let key = SymmetricKey(data: Data(secret.utf8))
    let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
    return Data(signature).map { String(format: "%02x", $0) }.joined()
}
```

Signature format: `X-SwiftCMS-Signature: sha256=<hex_signature>`

### Idempotency
- 60-second deduplication window
- Prevents duplicate deliveries for same event/webhook combination
- Idempotency key format: `{webhookId}:{eventName}:{entityId}:contentType:{contentType}`

## Exponential Backoff Implementation

Retry delays follow the sequence: 1s, 2s, 4s, 8s, 16s

```swift
// In WebhookDeliveryJob.dequeue():
let backoffDelays = [1.0, 2.0, 4.0, 8.0, 16.0]
let delayIndex = min(delivery.attempts - 1, backoffDelays.count - 1)
let delay = backoffDelays[delayIndex]
let nextAttempt = Date().addingTimeInterval(delay)

try await context.queue.dispatch(
    WebhookDeliveryJob.self, payload,
    delayUntil: nextAttempt
)
```

## Admin UI Features

### Webhook DLQ View (`/admin/webhooks/dlq`)
- Tabular display of failed deliveries
- Event type badges
- Truncated webhook URLs with tooltips
- Failure reason tooltips
- Retry count badges (warning/error states)
- Last failed timestamps (relative format)
- Action buttons (Retry, Delete)
- Auto-refresh capability

### Webhook List View (`/admin/webhooks`)
- Added "Dead Letter Queue" button
- Maintains existing webhook management UI
- Quick access to DLQ from webhook management

## API Endpoints

### DLQ Management
| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/admin/webhooks/dlq` | View DLQ entries | Session |
| POST | `/admin/webhooks/dlq` | Filter DLQ entries | Session |
| POST | `/admin/webhooks/dlq/:id/retry` | Retry single entry | Session |
| POST | `/admin/webhooks/dlq/retry-all` | Retry all entries | Session |
| DELETE | `/admin/webhooks/dlq/:id` | Delete DLQ entry | Session |

### JSON API
| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/api/v1/webhooks/dlq/:id/retry` | Retry entry (AJAX) | Session |
| DELETE | `/api/v1/webhooks/dlq/:id` | Delete entry (AJAX) | Session |

## Testing Recommendations

1. **Unit Tests**:
   - Test HMAC signature generation
   - Test exponential backoff calculation
   - Test idempotency key generation
   - Test event filtering logic

2. **Integration Tests**:
   - Test full webhook delivery flow
   - Test retry behavior with mock HTTP server
   - Test DLQ entry creation on failure
   - Test admin UI operations

3. **Manual Testing**:
   - Configure webhook pointing to webhook.site
   - Create content to trigger events
   - Verify signature and payload format
   - Force failures (invalid URL, timeout)
   - Check DLQ population and retry functionality

## Future Enhancements

1. Add webhook delivery statistics dashboard
2. Implement webhook endpoint health checks
3. Add configurable retry policies per webhook
4. Support for custom retry delays
5. Webhook delivery analytics
6. Webhook endpoint SSL certificate validation options
7. Support for additional signature algorithms
8. Webhook batching for high-volume scenarios

## Files Created/Modified

### Created:
- `Sources/CMSJobs/WebhookDispatcher.swift`
- `Sources/CMSJobs/WebhookDeliveryJob.swift`
- `Sources/CMSApi/Admin/WebhookDLQController.swift`
- `Resources/Views/admin/webhooks/dlq.leaf`

### Modified:
- `Sources/App/configure.swift` - Added webhook dispatcher configuration
- `Sources/App/routes.swift` - Added webhook DLQ controller registration
- `Sources/CMSJobs/Jobs.swift` - Cleaned up duplicate code
- `Resources/Views/admin/webhooks/list.leaf` - Added DLQ link
- `Sources/CMSEvents/CmsEvent.swift` - Enhanced with more event types for webhooks