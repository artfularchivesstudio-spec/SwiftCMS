# 🌐 SwiftCMS REST API Documentation

Comprehensive API documentation for SwiftCMS REST endpoints. All endpoints follow RESTful conventions and return JSON responses.

## 📋 Table of Contents

- [Authentication](#authentication)
- [Content Types](#content-types)
- [Content Entries](#content-entries)
- [Search](#search)
- [Versions](#versions)
- [Saved Filters](#saved-filters)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)

---

## 🔐 Authentication

Base URL: `https://api.swiftcms.io/api/v1`

### Overview

SwiftCMS uses JWT (JSON Web Tokens) for authentication. All protected endpoints require a valid access token in the `Authorization` header.

**Authentication Flow:**
1. Login with credentials to receive access and refresh tokens
2. Include access token in `Authorization: Bearer <token>` header for API requests
3. Refresh access token when expired using refresh token
4. Logout to invalidate tokens

### Endpoints

#### 🔑 Login

```http
POST /api/v1/auth/login
```

**Description:** Authenticate user and receive JWT tokens

**Authentication:** None (Public endpoint)

**Rate Limit:** 5 attempts/minute per IP

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "secure_password"
}
```

**Response (200 OK):**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "v2.local.eyJzdWIiOiIxMjM0NTY3ODkwIiw...",
  "tokenType": "Bearer",
  "expiresIn": 3600,
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "user@example.com",
    "displayName": "John Doe",
    "role": "editor"
  }
}
```

**Error Responses:**
- `401 Unauthorized`: Invalid credentials
- `422 Unprocessable Entity`: Invalid request format
- `429 Too Many Requests`: Rate limit exceeded

**Example using cURL:**
```bash
curl -X POST https://api.swiftcms.io/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "secure_password"}'
```

---

#### 🔄 Refresh Token

```http
POST /api/v1/auth/refresh
```

**Description:** Exchange refresh token for new access token

**Authentication:** Refresh token in request body

**Rate Limit:** 100 requests/minute per user

**Request Body:**
```json
{
  "refreshToken": "v2.local.eyJzdWIiOiIxMjM0NTY3ODkwIiw..."
}
```

**Response (200 OK):** Same structure as login response

**Error Responses:**
- `401 Unauthorized`: Invalid or expired refresh token
- `400 Bad Request`: Invalid token format

---

#### 🚪 Logout

```http
POST /api/v1/auth/logout
```

**Description:** Invalidate current access token

**Authentication:** Required (Bearer token)

**Rate Limit:** 100 requests/minute per user

**Response:**
- `204 No Content`: Successfully logged out

**Example:**
```bash
curl -X POST https://api.swiftcms.io/api/v1/auth/logout \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

#### 📝 Register (Optional)

```http
POST /api/v1/auth/register
```

**Description:** Create new user account (only if registration is enabled)

**Authentication:** None

**Rate Limit:** 10 requests/minute per IP

**Request Body:**
```json
{
  "email": "newuser@example.com",
  "password": "SecurePass123!",
  "displayName": "Jane Smith"
}
```

**Response (201 Created):** Same structure as login response

**Password Requirements:**
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character

---

## 📦 Content Types

### Overview

Content types define the structure of your content. Each content type has:
- **Slug**: Unique identifier (e.g., `posts`, `products`)
- **Name**: Human-readable name
- **Description**: Optional description
- **JSON Schema**: Field definitions and validation rules
- **Permissions**: CRUD permissions per role

### Endpoints

#### 📋 List Content Types

```http
GET /api/v1/content-types
```

**Description:** Get paginated list of all content types

**Authentication:** Public (with optional authentication for personalized results)

**Query Parameters:**
- `page` (integer, optional): Page number, default 1
- `perPage` (integer, optional): Items per page, default 50, max 100

**Response (200 OK):**
```json
{
  "data": [
    {
      "id": "567e8901-f23c-45d4-a789-526716285001",
      "slug": "blog-posts",
      "name": "Blog Posts",
      "description": "Articles and blog posts",
      "jsonSchema": {
        "type": "object",
        "properties": {
          "title": {"type": "string"},
          "content": {"type": "string"},
          "tags": {"type": "array", "items": {"type": "string"}}
        },
        "required": ["title"]
      },
      "createdAt": "2024-01-15T10:30:00Z",
      "updatedAt": "2024-01-15T10:30:00Z"
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "perPage": 50,
      "total": 3,
      "totalPages": 1
    }
  }
}
```

**Rate Limit:** 60 requests/minute per IP

---

#### 🔍 Get Content Type

```http
GET /api/v1/content-types/{slug}
```

**Description:** Get single content type by slug

**Path Parameters:**
- `slug` (string, required): Content type slug

**Response (200 OK):** Single content type object

**Error Responses:**
- `404 Not Found`: Content type doesn't exist

---

#### ➕ Create Content Type

```http
POST /api/v1/content-types
```

**Description:** Create a new content type definition

**Authentication:** Required (Admin role)

**Request Body:**
```json
{
  "slug": "products",
  "name": "Products",
  "description": "Product catalog items",
  "jsonSchema": {
    "type": "object",
    "properties": {
      "name": {"type": "string"},
      "price": {"type": "number", "minimum": 0},
      "description": {"type": "string"},
      "inStock": {"type": "boolean"}
    },
    "required": ["name", "price"]
  }
}
```

**Response (201 Created):**
```json
{
  "slug": "products",
  "name": "Products",
  "description": "Product catalog items",
  "jsonSchema": {...},
  "createdAt": "2024-01-20T14:30:00Z",
  "updatedAt": "2024-01-20T14:30:00Z"
}
```

**Rate Limit:** 10 requests/minute per user

---

#### ✏️ Update Content Type

```http
PUT /api/v1/content-types/{slug}
```

**Description:** Update existing content type

**Authentication:** Required (Admin role)

**Path Parameters:**
- `slug` (string): Current content type slug

**Request Body:** Same as create

**Response (200 OK):** Updated content type object

**Notes:**
- Cannot change `slug` field (it's immutable)
- Updates trigger SDK regeneration for affected types

---

#### 🗑 Delete Content Type

```http
DELETE /api/v1/content-types/{slug}
```

**Description:** Delete content type (with optional cascade)

**Authentication:** Required (Admin role)

**Query Parameters:**
- `force` (boolean, optional): Hard delete (irreversible), default `false`

**Response:**
- `204 No Content`: Successfully deleted
- `403 Forbidden`: Has existing content entries (unless forced)

**Warning:** Deleting a content type with `force=true` will permanently delete all associated content entries.

---

## 📄 Content Entries

### Overview

Content entries are instances of content types. Each entry contains:
- **ID**: Unique identifier
- **Content Type**: References the type definition
- **Data**: JSONB object matching the type schema
- **Status**: draft, published, or archived
- **Locale**: Language/locale code
- **Timestamps**: createdAt, updatedAt, publishedAt
- **Version**: Current version number

### Dynamic Routes

All content entry endpoints use the pattern:
```
/api/v1/{contentType}/{entryId?}
```

Where:
- `contentType`: The content type slug (e.g., `posts`, `products`)
- `entryId`: UUID of specific entry (optional for list operations)

### Endpoints

#### 📊 List Content Entries

```http
GET /api/v1/{contentType}
```

**Description:** Get paginated list of content entries with filtering and sorting

**Authentication:** Public (published entries), JWT (all entries)

**Path Parameters:**
- `contentType` (string, required): Content type slug

**Query Parameters:**
- `page` (integer): Page number, default 1
- `perPage` (integer): Items per page, max 100, default 25
- `status` (string): Filter by status - `draft`, `published`, `archived`
- `locale` (string): Filter by locale code (e.g., `en-US`, `de-DE`)
- `sort` (string): Sort field with direction, format: `fieldName:asc` or `fieldName:desc`
- `filter[fieldName]` (string): Dynamic filter for JSONB fields
- `fields` (string): Comma-separated field list for sparse fieldsets
- `populate` (string): Comma-separated relation fields to populate

**Example Requests:**
```bash
# List published blog posts
curl https://api.swiftcms.io/api/v1/posts?status=published

# Filter products by category, sorted by price
curl https://api.swiftcms.io/api/v1/products?filter[category]=electronics&sort=price:asc

# Get specific fields with author population
curl https://api.swiftcms.io/api/v1/posts?fields=title,excerpt&populate=author
```

**Response (200 OK):**
```json
{
  "data": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "contentType": "posts",
      "data": {
        "title": "Getting Started with SwiftCMS",
        "content": "SwiftCMS is a powerful headless CMS...",
        "tags": ["swift", "cms", "api"]
      },
      "status": "published",
      "locale": "en-US",
      "createdBy": "user-123",
      "createdAt": "2024-01-20T10:30:00Z",
      "updatedAt": "2024-01-21T15:45:00Z",
      "publishedAt": "2024-01-20T10:30:00Z"
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "perPage": 25,
      "total": 150,
      "totalPages": 6
    }
  }
}
```

**Special Features:**
- **Population:** Use `populate=field1,field2` to resolve relation fields
- **Sparse Fieldsets:** Use `fields=title,content` to limit returned fields
- **Filtering:** Complex filters via `filter[field]=value` syntax
- **Scheduling:** Entries with `publishAt` in future return 404 until published

**Rate Limit:** 60 requests/minute per IP

---

#### 👁 Get Single Entry

```http
GET /api/v1/{contentType}/{entryId}
```

**Description:** Retrieve a specific content entry by ID

**Path Parameters:**
- `contentType` (string, required)
- `entryId` (UUID, required)

**Query Parameters:**
- `populate` (string): Comma-separated relation fields to populate

**Response (200 OK):** Single entry object

**Error Responses:**
- `404 Not Found`: Entry doesn't exist or not accessible

**Caching:**
- Includes ETag header for client-side caching
- Returns `304 Not Modified` if content unchanged

**Rate Limit:** 100 requests/minute per IP

---

#### ➕ Create Entry

```http
POST /api/v1/{contentType}
```

**Description:** Create new content entry

**Authentication:** Required (Create permission)

**Request Body:**
```json
{
  "data": {
    "title": "New Blog Post",
    "content": "Post content here...",
    "tags": ["swift", "cms"]
  },
  "status": "draft",
  "locale": "en-US",
  "publishAt": "2024-02-01T10:00:00Z",
  "unpublishAt": null
}
```

**Response (201 Created):** Created entry object

**Validation:**
- Data validated against content type JSON schema
- Required fields enforced
- Type checking for all fields

**Events:**
- Emits `ContentCreatedEvent` to event bus

**Rate Limit:** 30 requests/minute per user

---

#### ✏️ Update Entry

```http
PUT /api/v1/{contentType}/{entryId}
```

**Description:** Update existing content entry (full replacement)

**Authentication:** Required (Update permission)

**Request Body:** Same as create, all fields required

**Response (200 OK):** Updated entry object

**Features:**
- Updates create new version automatically
- Previous versions accessible via version endpoints
- Partial updates not supported (use full data object)

**Events:**
- Emits `ContentUpdatedEvent` to event bus

**Rate Limit:** 30 requests/minute per user

---

#### 🗑 Delete Entry

```http
DELETE /api/v1/{contentType}/{entryId}
```

**Description:** Delete a content entry

**Authentication:** Required (Delete permission)

**Query Parameters:**
- `force` (boolean): Hard delete, default `false` (soft delete)

**Response:**
- `204 No Content`: Successfully deleted

**Delete Types:**
- **Soft Delete** (default): Sets `deletedAt` timestamp
- **Hard Delete** (`force=true`): Permanently removes entry and versions

**Events:**
- Emits `ContentDeletedEvent` to event bus

**Rate Limit:** 30 requests/minute per user

---

## 🔍 Search

### Overview

Full-text search across all content types using Meilisearch integration. Features:
- Real-time indexing
- Relevance ranking
- Faceted search
- Query suggestions
- Multi-language support

### Configuration Requirements

Environment variables:
```bash
MEILI_URL=http://localhost:7700  # Meilisearch instance URL
MEILI_KEY=your_master_key        # Meilisearch API key
```

### Endpoints

#### 🔍 Search Content

```http
GET /api/v1/search
```

**Description:** Perform full-text search across content entries

**Query Parameters:**
- `q` (string, required): Search query (minimum 2 characters)
- `contentType` (string): Filter by specific content type
- `page` (integer): Page number, default 1
- `perPage` (integer): Results per page, max 100, default 20
- `sortBy` (string): Sort field with direction: `fieldName:asc` or `fieldName:desc`
- `filter[fieldName]` (string): Dynamic filters for faceted search

**Example Searches:**
```bash
# Basic full-text search
curl https://api.swiftcms.io/api/v1/search?q=swift+cms

# Filtered search within posts
curl https://api.swiftcms.io/api/v1/search?q=api&contentType=posts&filter[status]=published

# Search with sorting
curl https://api.swiftcms.io/api/v1/search?q=content&sortBy=createdAt:desc&perPage=50
```

**Response (200 OK):**
```json
{
  "hits": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "contentType": "posts",
      "data": {
        "title": "SwiftCMS API Guide",
        "content": "Complete guide to SwiftCMS APIs..."
      },
      "_formatted": {
        "title": "<em>SwiftCMS</em> API Guide",
        "content": "Complete guide to <em>SwiftCMS</em> APIs..."
      }
    }
  ],
  "estimatedTotalHits": 42,
  "limit": 20,
  "offset": 0,
  "processingTimeMs": 15,
  "query": "swift cms"
}
```

**Features:**
- **Highlighting:** Search terms highlighted in `_formatted` fields
- **Typo Tolerance:** Configurable typo tolerance
- **Faceting:** Filter results using `filter[field]=value` syntax
- **Pagination:** Standard pagination with page/perPage parameters
- **Sorting:** Sort by any indexed field

**Rate Limit:** 1000 requests/minute per API key

---

#### 📊 Get Search Settings

```http
GET /api/v1/search/settings/{contentType}
```

**Description:** Get Meilisearch settings for a content type

**Authentication:** Required

**Path Parameters:**
- `contentType` (string): Content type slug

**Response:** Meilisearch index settings

---

#### ✏️ Update Search Settings

```http
PUT /api/v1/search/settings/{contentType}
```

**Description:** Update search settings for a content type

**Authentication:** Required (Admin)

**Request Body:**
```json
{
  "searchableAttributes": ["title", "content", "tags"],
  "filterableAttributes": ["status", "category", "tags"],
  "sortableAttributes": ["createdAt", "price"],
  "rankingRules": [
    "words",
    "typo",
    "proximity",
    "attribute",
    "sort",
    "exactness"
  ]
}
```

---

#### 🔄 Reindex Content Type

```http
POST /api/v1/search/reindex/{contentType}
```

**Description:** Rebuild search index for a content type

**Authentication:** Required (Admin)

**Response:**
- `202 Accepted`: Reindexing started asynchronously

**Note:** This operation can take time for large datasets. Monitor progress via logs.

---

## 📚 Version Management

### Overview

Every content update automatically creates a new version. Version history allows:
- Viewing historical versions
- Comparing versions
- Restoring previous versions
- Auditing changes

### Endpoints

#### 📚 List Versions

```http
GET /api/v1/{contentType}/{entryId}/versions
```

**Description:** Get all versions of a content entry

**Path Parameters:**
- `contentType` (string)
- `entryId` (UUID)

**Response (200 OK):**
```json
[
  {
    "version": 3,
    "createdAt": "2024-01-20T15:30:00Z",
    "createdBy": "user-123",
    "data": { /* Full entry snapshot */ },
    "status": "published"
  },
  {
    "version": 2,
    "createdAt": "2024-01-19T10:15:00Z",
    "createdBy": "user-456",
    "data": { /* Previous version */ },
    "status": "draft"
  }
]
```

**Rate Limit:** 60 requests/minute per client

---

#### 📄 Get Version

```http
GET /api/v1/{contentType}/{entryId}/versions/{version}
```

**Description:** Get specific version of content entry

**Path Parameters:**
- `contentType` (string)
- `entryId` (UUID)
- `version` (integer): Version number (starts at 1)

**Response:** Single version object

---

#### 🔄 Restore Version

```http
POST /api/v1/{contentType}/{entryId}/versions/{version}/restore
```

**Description:** Restore content entry to previous version

**Authentication:** Required (Update permission)

**Path Parameters:**
- `contentType` (string)
- `entryId` (UUID)
- `version` (integer): Version to restore

**Response (200 OK):** Updated entry object (new version created)

**Events:**
- Emits `ContentUpdatedEvent` and `VersionRestoredEvent`

**Rate Limit:** 20 requests/minute per user

---

#### 📊 Compare Versions

```http
GET /api/v1/{contentType}/{entryId}/versions/{fromVersion}/{toVersion}/diff
```

**Description:** Get diff between two versions

**Path Parameters:**
- `contentType` (string)
- `entryId` (UUID)
- `fromVersion` (integer): Base version
- `toVersion` (integer): Comparison version

**Response (200 OK):**
```json
{
  "added": {
    "newField": "new value"
  },
  "removed": {
    "oldField": "old value"
  },
  "changed": {
    "title": {
      "from": "Old Title",
      "to": "New Title"
    }
  }
}
```

**Use Cases:**
- Content review processes
- Change auditing
- Revert analysis

---

## 💾 Saved Filters

### Overview

Saved filters allow users to save and reuse common query configurations. Features:
- Personal and public filters
- Cross-content-type support
- JSON-compatible filter definitions

### Endpoints

#### 📋 List Saved Filters

```http
GET /api/v1/saved-filters
```

**Description:** Get user's saved filters for a content type

**Authentication:** Required

**Query Parameters:**
- `contentType` (string, required): Filter by content type

**Response (200 OK):**
```json
[
  {
    "id": "789f0123-a34b-45c6-d789-638817396002",
    "name": "Published Posts",
    "contentType": "posts",
    "filterJSON": {"status": "published"},
    "sortJSON": {"createdAt": "desc"},
    "isPublic": true,
    "createdAt": "2024-01-15T09:30:00Z"
  }
]
```

**Rate Limit:** 100 requests/minute per user

---

#### ➕ Create Saved Filter

```http
POST /api/v1/saved-filters
```

**Description:** Save a new filter configuration

**Authentication:** Required

**Request Body:**
```json
{
  "name": "High Priority Tasks",
  "contentType": "tasks",
  "filterJSON": {
    "priority": "high",
    "status": "open"
  },
  "sortJSON": {
    "dueDate": "asc"
  },
  "isPublic": false
}
```

**Response (201 Created):** Created filter object

---

#### 🗑 Delete Saved Filter

```http
DELETE /api/v1/saved-filters/{filterId}
```

**Description:** Delete a saved filter

**Authentication:** Required (Owner or Admin)

**Path Parameters:**
- `filterId` (UUID): Filter identifier

**Response:**
- `204 No Content`: Successfully deleted

**Permissions:**
- Users can delete their own filters
- Admins can delete any filter

---

## ❌ Error Handling

SwiftCMS uses consistent error responses across all endpoints.

### Error Response Format

```json
{
  "error": "Bad Request",
  "statusCode": 400,
  "reason": "Invalid parameter format",
  "details": {
    "field": "email",
    "message": "Invalid email format"
  }
}
```

### Common Error Codes

| Code | Error | Description | Retry |
|------|-------|-------------|-------|
| `400` | Bad Request | Invalid request format | Fix request |
| `401` | Unauthorized | Missing or invalid token | Re-authenticate |
| `403` | Forbidden | Insufficient permissions | Check permissions |
| `404` | Not Found | Resource doesn't exist | Verify ID/path |
| `409` | Conflict | Resource already exists | Use different data |
| `422` | Unprocessable Entity | Validation failed | Fix validation errors |
| `429` | Too Many Requests | Rate limit exceeded | Wait and retry |
| `500` | Internal Server Error | Server error | Retry with backoff |
| `503` | Service Unavailable | Service unavailable | Retry later |

### Error Handling Best Practices

1. **Check Status Codes:** Always check the HTTP status code first
2. **Parse Error Body:** Error details are in the response body
3. **Retry Logic:** Implement exponential backoff for 5xx errors
4. **Token Refresh:** Re-authenticate on 401 errors
5. **User Feedback:** Show user-friendly messages based on error codes

### Example Error Handling (Swift)

```swift
do {
    let response = try await client.get("/api/v1/posts")
    // Process success
} catch let error as ApiError {
    switch error.statusCode {
    case 401:
        // Refresh token and retry
        try await refreshToken()
    case 429:
        // Wait and retry
        try await Task.sleep(nanoseconds: 1_000_000_000)
        // Retry request
    default:
        // Handle other errors
        print("Error: \(error.reason)")
    }
}
```

---

## ⚡ Rate Limiting

### Rate Limit Headers

All API responses include rate limit information:

```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 59
X-RateLimit-Reset: 1643723400
```

- **X-RateLimit-Limit:** Maximum requests allowed
- **X-RateLimit-Remaining:** Requests remaining in current window
- **X-RateLimit-Reset:** Unix timestamp when limit resets

### Rate Limit Tiers

| Endpoint | Limit | Window | Per |
|----------|-------|--------|-----|
| Authentication | 5 | 1 minute | IP |
| List Content | 60 | 1 minute | IP |
| Read Content | 100 | 1 minute | IP |
| Create/Update/Delete | 30 | 1 minute | User |
| Search | 1000 | 1 minute | API Key |
| Admin Operations | 10 | 1 minute | User |
| Version Operations | 20 | 1 minute | User |
| Filter Management | 100 | 1 minute | User |

### Exceeding Rate Limits

When rate limit is exceeded:

```http
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1643723400
Content-Type: application/json

{
  "error": "Too Many Requests",
  "statusCode": 429,
  "reason": "Rate limit exceeded. Try again in 45 seconds.",
  "details": {
    "retryAfter": 45
  }
}
```

### Best Practices

1. **Cache Responses:** Cache frequently accessed data
2. **Batch Operations:** Use bulk endpoints when available
3. **Backoff:** Implement exponential backoff on 429 errors
4. **Webhooks:** Use webhooks instead of polling
5. **Optimize Queries:** Request only needed data

---

## 📚 SDK Generation

SwiftCMS can generate type-safe client SDKs for your content types.

### Generate SDK

```bash
swift run CMSCLI generate-sdk --content-type posts --output ./SDK/PostsAPI.swift
```

This generates Swift code with:
- Type-safe models matching your JSON schema
- Async/await API client methods
- Full type inference and compile-time safety

---

## 🔗 WebHooks

### Overview

Webhooks notify external systems of CMS events in real-time.

### Configuration

```bash
# Set webhook URL via environment
CMS_WEBHOOK_URL=https://your-app.com/webhooks/swiftcms
CMS_WEBHOOK_SECRET=your_webhook_secret
```

### Event Types

- `content.created`
- `content.updated`
- `content.deleted`
- `content.published`
- `content_type.created`
- `content_type.updated`
- `user.login`

### Webhook Payload

```json
{
  "event": "content.created",
  "timestamp": "2024-01-20T15:30:00Z",
  "data": {
    "contentType": "posts",
    "entryId": "123e4567-e89b-12d3-a456-426614174000",
    "entry": {
      // Full entry data
    }
  },
  "signature": "sha256=..."
}
```

---

## 🛡 Security

### API Keys

Generate API keys for server-to-server authentication:

```bash
curl -X POST https://api.swiftcms.io/api/v1/api-keys \
  -H "Authorization: Bearer USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Production App", "permissions": ["read:content", "write:content"]}'
```

Use API key in requests:
```bash
curl -H "X-API-Key: sk_live_..." https://api.swiftcms.io/api/v1/posts
```

### Best Practices

- Use HTTPS for all API calls
- Store tokens securely (Keychain on iOS, SecureStore on Android)
- Rotate API keys regularly
- Use least-privilege permissions
- Implement webhook signature verification
- Never commit tokens to version control

---

## 📖 Additional Resources

- [SwiftCMS Client SDK](https://github.com/artfularchivesstudio-spec/swiftcms-swift-sdk)
- [Postman Collection](https://documenter.getpostman.com/view/YOUR_ID)
- [OpenAPI Specification](https://api.swiftcms.io/openapi.yaml)
- [GraphQL API](API_GRAPHQL.md)
- [Admin Panel](https://github.com/artfularchivesstudio-spec/SwiftCMS/tree/main/Sources/CMSAdmin)

---

## 🆘 Support

- 📧 Email: support@swiftcms.io
- 💬 Discord: [Join our community](https://discord.gg/swiftcms)
- 🐛 GitHub Issues: [Report bugs](https://github.com/artfularchivesstudio-spec/SwiftCMS/issues)
- 📖 Documentation: [docs.swiftcms.io](https://docs.swiftcms.io)

---

*Last Updated: 2024-01-20 | Version: 1.0.0*