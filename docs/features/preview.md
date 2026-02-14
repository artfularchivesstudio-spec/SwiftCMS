# Content Preview System Guide

SwiftCMS provides a secure content preview system that allows you to share draft content with stakeholders before publishing.

## Overview

The preview system provides:

- **Secure token-based access** - Short-lived tokens for preview access
- **Draft content viewing** - Preview unpublished content
- **Version comparison** - Compare different versions
- **Expiration** - Automatic token expiration (1 hour)
- **Permission control** - Only authorized users can generate tokens
- **Audit logging** - All preview access is logged

## Token Generation

### Admin Panel Generation

Generate preview tokens from the admin panel:

1. Navigate to content entry
2. Click "Preview" button
3. Copy preview link

```
┌─────────────────────────────────────┐
│ Edit Blog Post                      │
├─────────────────────────────────────┤
│ [Save] [Publish] [Preview ▼]        │ ← Preview dropdown
├─────────────────────────────────────┤
│                                     │
│ Title: My First Post                │
│ Content: ...                        │
│                                     │
└─────────────────────────────────────┘
```

Preview dropdown:
```
┌──────────────────┐
│ 📋 Copy Link     │ ← Copy preview link
│ 🔑 New Token     │ ← Generate new token
└──────────────────┘
```

### API Generation

Generate preview tokens via API:

```http
POST /api/v1/blog-posts/{entryId}/preview-token
Authorization: Bearer YOUR_TOKEN
```

Response:

```json
{
  "token": "eyJzdWIiOiJwcmV2aWV3IiwiZW50cnlfaWQiOiI1NTBlODQwMC1lMjliLTQxZDQtYTcxNi00NDY2NTU0NDAwMDAiLCJjb250ZW50X3R5cGUiOiJibG9nLXBvc3RzIiwiZXhwIjoiMTcwNzkyMjQwMCJ9",
  "previewUrl": "https://your-cms.com/api/v1/blog-posts/550e8400-e29b-41d4-a716-446655440000/preview?token=eyJzdWIiOiJwcmV2aWV3IiwiZW50cnlfaWQiOiI1NTBlODQwMC1lMjliLTQxZDQtYTcxNi00NDY2NTU0NDAwMDAiLCJjb250ZW50X3R5cGUiOiJibG9nLXBvc3RzIiwiZXhwIjoiMTcwNzkyMjQwMCJ9",
  "expiresAt": "2024-02-14T11:00:00Z"
}
```

### CLI Generation

Generate preview tokens via CLI:

```bash
# Generate preview token
swift run App preview:generate --content-type=blog-posts --entry-id=550e8400-e29b-41d4-a716-446655440000

# Output
Preview token: eyJzdWIiOiJwcmV2aWV3IiwiZW50cnlfaWQ...
Preview URL: https://your-cms.com/api/v1/blog-posts/550e8400-e29b-41d4-a716-446655440000/preview?token=...
Expires in: 1 hour
```

## Preview Links

### URL Format

Preview URLs follow this format:

```
https://your-cms.com/api/v1/{contentType}/{entryId}/preview?token={token}
```

Example:

```
https://your-cms.com/api/v1/blog-posts/550e8400-e29b-41d4-a716-446655440000/preview?token=eyJzdWIiOiJwcmV2aWV3IiwiZW50cnlfaWQiOiI1NTBlODQwMC1lMjliLTQxZDQtYTcxNi00NDY2NTU0NDAwMDAiLCJjb250ZW50X3R5cGUiOiJibG9nLXBvc3RzIiwiZXhwIjoiMTcwNzkyMjQwMCJ9
```

### Accessing Preview

Anyone with the preview link can access the draft content:

```bash
curl "https://your-cms.com/api/v1/blog-posts/550e8400-e29b-41d4-a716-446655440000/preview?token=TOKEN"
```

Response:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "contentType": "blog-posts",
  "status": "draft",
  "data": {
    "title": "My First Post",
    "slug": "my-first-post",
    "content": "This is the content...",
    "excerpt": "A brief excerpt"
  },
  "createdAt": "2024-02-14T10:00:00Z",
  "updatedAt": "2024-02-14T10:30:00Z",
  "createdBy": "admin@swiftcms.dev"
}
```

## Token Validation

### Validation Process

Tokens are validated using these steps:

1. **Decode Base64URL** - Decode the token
2. **Parse JSON** - Extract payload
3. **Verify Entry** - Check entry exists
4. **Check Expiration** - Verify token hasn't expired
5. **Return Content** - Serve draft content

### Token Payload

Token structure:

```json
{
  "sub": "preview",
  "entry_id": "550e8400-e29b-41d4-a716-446655440000",
  "content_type": "blog-posts",
  "exp": "1707922400"
}
```

- `sub`: Always "preview"
- `entry_id`: UUID of the content entry
- `content_type`: Content type slug
- `exp`: Unix timestamp when token expires

### Expiration

Tokens expire after **1 hour** by default:

```swift
let expiresAt = Date().addingTimeInterval(3600)  // 1 hour
```

## Security Considerations

### Token Security

**Characteristics**:
- Short-lived (1 hour default)
- Single-use (can be revoked)
- No authentication required
- URL-safe encoding

**Best Practices**:
1. Share only with trusted recipients
2. Don't post publicly
3. Regenerate tokens if leaked
4. Monitor preview access logs

### Access Control

#### Permission Required

Users must have `content:preview` permission to generate tokens:

```swift
// Check permission
guard user.permissions.contains("content:preview") else {
    throw Abort(.forbidden, reason: "Insufficient permissions")
}
```

#### Audit Logging

All preview access is logged:

```json
{
  "timestamp": "2024-02-14T10:30:45Z",
  "event": "preview_access",
  "entryId": "550e8400-e29b-41d4-a716-446655440000",
  "contentType": "blog-posts",
  "tokenHash": "a3f5b8c9d2e1f4a6b7c8d9e0f1a2b3c4",
  "ipAddress": "203.0.113.42",
  "userAgent": "Mozilla/5.0..."
}
```

### Token Revocation

#### Manual Revocation

Revoke preview tokens:

```http
DELETE /api/v1/admin/preview/tokens/{tokenId}
Authorization: Bearer ADMIN_TOKEN
```

#### Automatic Revocation

Tokens are automatically revoked when:
- Entry is published
- Entry is deleted
- Token expires
- Admin manually revokes

## Integration Examples

### Website Integration

Integrate preview into your website:

```javascript
// Check for preview parameter
const urlParams = new URLSearchParams(window.location.search);
const previewToken = urlParams.get('preview');

if (previewToken) {
    // Fetch preview content
    fetch(`/api/v1/blog-posts/${entryId}/preview?token=${previewToken}`)
        .then(response => response.json())
        .then(data => {
            // Render preview
            renderPreview(data);
        });
} else {
    // Fetch published content
    fetch(`/api/v1/blog-posts/${entryId}`)
        .then(response => response.json())
        .then(data => {
            // Render content
            renderContent(data);
        });
}
```

### Preview Bar

Add a preview bar to indicate preview mode:

```html
<!-- Preview Bar (shown only in preview mode) -->
<div id="preview-bar" class="preview-bar" style="display: none;">
    <div class="preview-bar-content">
        <span class="preview-indicator">👁️ Preview Mode</span>
        <span class="preview-expires" id="preview-expires"></span>
        <button onclick="exitPreview()">Exit Preview</button>
    </div>
</div>

<script>
// Show preview bar if preview token present
const previewToken = new URLSearchParams(window.location.search).get('preview');

if (previewToken) {
    document.getElementById('preview-bar').style.display = 'block';

    // Calculate expiration
    const expiresAt = parseJwt(previewToken).exp * 1000;
    const expires = new Date(expiresAt);
    document.getElementById('preview-expires').textContent = `Expires: ${expires.toLocaleString()}`;
}

function exitPreview() {
    // Remove preview parameter from URL
    const url = new URL(window.location);
    url.searchParams.delete('preview');
    window.location.href = url.toString();
}
</script>
```

### WordPress-style Preview

WordPress-style preview URL:

```
https://your-website.com/blog/my-first-post?preview=true&token=TOKEN
```

Implementation:

```swift
// In your website middleware
if let previewToken = req.query["preview"] {
    // Fetch preview content
    let previewUrl = "\(cmsURL)/api/v1/blog-posts/\(entryId)/preview?token=\(previewToken)"
    let content = try await client.get(previewUrl)

    // Render preview with preview bar
    return renderPreview(content.data)
} else {
    // Fetch published content
    let content = try await client.get("\(cmsURL)/api/v1/blog-posts/\(entryId)")

    // Render normally
    return renderContent(content.data)
}
```

## Workflow Examples

### Content Review Workflow

1. **Author**: Creates draft content
2. **Author**: Generates preview token
3. **Author**: Shares preview link with reviewer
4. **Reviewer**: Opens preview link
5. **Reviewer**: Reviews content in preview mode
6. **Reviewer**: Provides feedback
7. **Author**: Makes revisions
8. **Repeat until approved**
9. **Author**: Publishes content

### Client Approval Workflow

1. **Content Team**: Creates draft content
2. **Content Team**: Generates preview token
3. **Content Team**: Sends preview link to client
4. **Client**: Reviews content
5. **Client**: Requests changes or approves
6. **Content Team**: Makes changes if needed
7. **Content Team**: Generates new preview token
8. **Repeat until approved**
9. **Content Team**: Publishes content

### Social Media Preview

Preview content before sharing:

1. **Marketer**: Creates social media post
2. **Marketer**: Generates preview token
3. **Marketer**: Views preview on mobile
4. **Marketer**: Adjusts formatting if needed
5. **Marketer**: Publishes when satisfied

## API Reference

### Generate Preview Token

```http
POST /api/v1/{contentType}/{entryId}/preview-token
```

**Authentication**: Required

**Permissions**: `content:preview`

**Request**:
```json
{
  "ttl": 3600
}
```

**Response**:
```json
{
  "token": "eyJzdWIiOiJwcmV2aWV3Ii...",
  "previewUrl": "https://...",
  "expiresAt": "2024-02-14T11:00:00Z"
}
```

### Access Preview

```http
GET /api/v1/{contentType}/{entryId}/preview?token={token}
```

**Authentication**: Not required

**Response**: Content entry (same as regular GET)

### Revoke Preview Token

```http
DELETE /api/v1/admin/preview/tokens/{tokenId}
```

**Authentication**: Required

**Permissions**: `content:admin`

**Response**:
```json
{
  "revoked": true
}
```

## Best Practices

### 1. Set Appropriate TTL

Adjust token lifetime based on use case:

```bash
# Short-lived for sensitive content
ttl: 300  # 5 minutes

# Standard for reviews
ttl: 3600  # 1 hour

# Extended for client approvals
ttl: 86400  # 24 hours
```

### 2. Monitor Preview Usage

Track preview token usage:

```swift
req.logger.info("Preview accessed", metadata: [
    "entryId": entryId,
    "contentType": contentType,
    "ipAddress": req.remoteAddress?.description ?? "unknown"
])
```

### 3. Use HTTPS Only

Preview links should use HTTPS:

```
✅ Good: https://your-cms.com/api/v1/.../preview?token=...
❌ Bad:  http://your-cms.com/api/v1/.../preview?token=...
```

### 4. Limit Token Scope

Tokens are scoped to specific entries:

```json
{
  "entry_id": "550e8400-e29b-41d4-a716-446655440000",
  "content_type": "blog-posts"
}
```

### 5. Communicate Expiration

Inform recipients of token expiration:

```
Hi [Name],

Here's the preview link for review:
https://your-cms.com/api/v1/blog-posts/.../preview?token=...

Note: This link expires in 1 hour.
```

## Troubleshooting

### Token Not Working

**Symptoms**: "Invalid or expired preview token" error

**Solutions**:
1. Check if token has expired
2. Verify token is complete (not truncated)
3. Check if entry still exists
4. Generate new token

### Preview Shows Published Version

**Symptoms**: Preview shows published content, not draft

**Solutions**:
1. Verify entry status is "draft"
2. Check for cache issues
3. Try generating new token
4. Verify preview endpoint is correct

### Permission Denied

**Symptoms**: Cannot generate preview token

**Solutions**:
1. Verify user has `content:preview` permission
2. Check authentication token
3. Contact administrator

## Additional Resources

- [Content Versioning Guide](/docs/features/versioning.md)
- [Permissions Guide](/docs/admin/permissions.md)
- [API Reference](/docs/api/rest.md)
