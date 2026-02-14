# REST API Documentation

SwiftCMS provides a comprehensive REST API for managing content, users, media, and more. This guide covers all available endpoints, authentication, and usage examples.

## Base URL

All API endpoints are prefixed with:
```
/api/v1
```

## Authentication

### Bearer Token Authentication

Most endpoints require authentication using a JWT token:

```bash
curl https://yourapp.com/api/v1/content \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

#### Obtaining a Token (Local Auth)

```bash
curl -X POST https://yourapp.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "your-password"
  }'
```

Response:
```json
{
  "token": "eyJhbGc..."
}
```

#### Using Auth0

```bash
# Get token from Auth0
curl -X POST https://your-tenant.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "audience": "https://api.yourapp.com",
    "grant_type": "client_credentials"
  }'

# Use token with SwiftCMS
curl https://yourapp.com/api/v1/content \
  -H "Authorization: Bearer AUTH0_TOKEN"
```

### API Key Authentication

For machine-to-machine access:

```bash
curl https://yourapp.com/api/v1/content \
  -H "X-API-Key: your-api-key"
```

Create API keys in the admin panel under **Settings → API Keys**.

## Content CRUD Operations

### Create Content Entry

```bash
POST /api/v1/content/{contentType}
```

Example:
```bash
curl -X POST https://yourapp.com/api/v1/content/posts \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My First Post",
    "content": "This is the post content",
    "author": "John Doe",
    "tags": ["swift", "cms"],
    "status": "draft"
  }'
```

Response:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "contentType": "posts",
  "data": {
    "title": "My First Post",
    "content": "This is the post content",
    "author": "John Doe",
    "tags": ["swift", "cms"],
    "status": "draft",
    "createdAt": "2024-01-15T10:30:00Z",
    "updatedAt": "2024-01-15T10:30:00Z"
  },
  "status": "draft",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

### Get Content Entries

```bash
GET /api/v1/content/{contentType}
```

Query Parameters:
- `status` - Filter by status (draft, review, published, archived)
- `populate` - Comma-separated list of fields to populate
- `page` - Page number for pagination (default: 1)
- `limit` - Items per page (default: 20, max: 100)
- `sort` - Sort field (e.g., "createdAt", "-createdAt" for descending)
- `filter[field][operator]` - Filter by field values

Example:
```bash
curl https://yourapp.com/api/v1/content/posts?status=published&page=1&limit=10&sort=-createdAt \
  -H "Authorization: Bearer YOUR_TOKEN"
```

Response:
```json
{
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "contentType": "posts",
      "data": {
        "title": "My First Post",
        "content": "This is the post content",
        "author": "John Doe",
        "tags": ["swift", "cms"],
        "status": "published",
        "createdAt": "2024-01-15T10:30:00Z",
        "updatedAt": "2024-01-15T10:30:00Z"
      },
      "status": "published",
      "createdAt": "2024-01-15T10:30:00Z",
      "updatedAt": "2024-01-15T10:30:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 10,
    "total": 45,
    "totalPages": 5
  }
}
```

### Get Single Content Entry

```bash
GET /api/v1/content/{contentType}/{id}
```

Example:
```bash
curl https://yourapp.com/api/v1/content/posts/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Update Content Entry

```bash
PUT /api/v1/content/{contentType}/{id}
```

Example:
```bash
curl -X PUT https://yourapp.com/api/v1/content/posts/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Title",
    "content": "Updated content",
    "status": "published"
  }'
```

### Delete Content Entry

```bash
DELETE /api/v1/content/{contentType}/{id}
```

Example:
```bash
curl -X DELETE https://yourapp.com/api/v1/content/posts/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Bulk Operations

#### Create Multiple Entries

```bash
POST /api/v1/content/{contentType}/bulk
```

Example:
```bash
curl -X POST https://yourapp.com/api/v1/content/posts/bulk \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "entries": [
      {
        "title": "Post 1",
        "content": "Content 1"
      },
      {
        "title": "Post 2",
        "content": "Content 2"
      }
    ]
  }'
```

Response:
```json
{
  "created": 2,
  "failed": 0,
  "errors": []
}
```

#### Update Multiple Entries

```bash
PUT /api/v1/content/{contentType}/bulk
```

Example:
```bash
curl -X PUT https://yourapp.com/api/v1/content/posts/bulk \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": ["uuid1", "uuid2"],
    "data": {
      "status": "published"
    }
  }'
```

#### Delete Multiple Entries

```bash
DELETE /api/v1/content/{contentType}/bulk
```

Example:
```bash
curl -X DELETE https://yourapp.com/api/v1/content/posts/bulk \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": ["uuid1", "uuid2"]
  }'
```

## Advanced Filtering

### Basic Filtering

```bash
curl https://yourapp.com/api/v1/content/posts?filter[published]=true
```

### Operators

- `[eq]` - Equal (default)
- `[ne]` - Not equal
- `[lt]` - Less than
- `[lte]` - Less than or equal
- `[gt]` - Greater than
- `[gte]` - Greater than or equal
- `[in]` - In array
- `[nin]` - Not in array
- `[like]` - Like (SQL LIKE)
- `[nlike]` - Not like

Examples:
```bash
# Price between 10 and 100
/api/v1/content/products?filter[price][gte]=10&filter[price][lte]=100

# Tags containing "swift" OR "vapor"
/api/v1/content/posts?filter[tags][in]=swift,vapor

# Title contains "SwiftCMS"
/api/v1/content/posts?filter[title][like]=*SwiftCMS*

# Published after date
/api/v1/content/posts?filter[publishedAt][gte]=2024-01-01T00:00:00Z
```

## Content Type Management

### Create Content Type

```bash
POST /api/v1/content-types
```

Example:
```bash
curl -X POST https://yourapp.com/api/v1/content-types \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "products",
    "displayName": "Products",
    "description": "Product catalog",
    "kind": "collection",
    "jsonSchema": {
      "type": "object",
      "properties": {
        "name": { "type": "string", "minLength": 1 },
        "price": { "type": "number", "minimum": 0 },
        "description": { "type": "string" },
        "inStock": { "type": "boolean" },
        "category": { "type": "string" }
      },
      "required": ["name", "price"]
    },
    "fieldOrder": [
      { "name": "name", "type": "text" },
      { "name": "price", "type": "number" },
      { "name": "description", "type": "richtext" },
      { "name": "inStock", "type": "boolean" },
      { "name": "category", "type": "select" }
    ],
    "settings": {
      "draftAndPublish": true,
      "timestamps": true
    }
  }'
```

### Example