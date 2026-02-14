# GraphQL API Documentation

SwiftCMS provides a powerful GraphQL API for querying and manipulating content with type safety and efficient data fetching.

## Endpoint

```
POST /graphql
```

The GraphQL endpoint accepts POST requests with JSON bodies containing your queries, mutations, and optional variables.

## Authentication

Include your authentication token in the request headers:

```bash
curl -X POST https://your-cms.com/graphql \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ health }"}'
```

### Authentication Methods

1. **Bearer Token** (JWT)
   ```http
   Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

2. **API Key**
   ```http
   X-API-Key: your-api-key-here
   ```

3. **Auth0 Bearer Token**
   ```http
   Authorization: Bearer auth0|user-token...
   ```

## Schema Introspection

Query the GraphQL schema to explore available types and operations:

```graphql
{
  __schema {
    types {
      name
      description
      fields {
        name
        type {
          name
        }
      }
    }
  }
}
```

Get all available queries:

```graphql
{
  __schema {
    queryType {
      fields {
        name
        description
      }
    }
  }
}
```

## Query Operations

### Health Check

Simple health check query:

```graphql
query {
  health
}
```

Response:
```json
{
  "data": {
    "health": "ok"
  }
}
```

### Content Entry Queries

The GraphQL schema automatically generates queries based on your content type definitions.

#### Single Entry

```graphql
query GetBlogPost($id: ID!) {
  blogPost(id: $id) {
    id
    status
    createdAt
    updatedAt
    data {
      title
      slug
      excerpt
      content
      author
      tags
      featuredImage
    }
  }
}
```

Variables:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### Entry List with Pagination

```graphql
query GetBlogPosts($page: Int, $perPage: Int) {
  blogPostList(page: $page, perPage: $perPage) {
    data {
      id
      status
      data {
        title
        slug
        excerpt
      }
    }
    meta {
      page
      perPage
      total
      totalPages
      hasNextPage
      hasPreviousPage
    }
  }
}
```

Variables:
```json
{
  "page": 1,
  "perPage": 20
}
```

#### Content Type Query

```graphql
query GetContentType {
  contentType(slug: "blog-posts") {
    id
    name
    slug
    displayName
    description
    kind
    jsonSchema
    createdAt
    updatedAt
  }
}
```

## Mutation Operations

### Create Content Entry

```graphql
mutation CreateBlogPost($input: CreateBlogPostInput!) {
  createBlogPost(input: $input) {
    id
    status
    data {
      title
      slug
      content
    }
    createdAt
  }
}
```

Variables:
```json
{
  "input": {
    "contentType": "blog-posts",
    "data": {
      "title": "My First Post",
      "slug": "my-first-post",
      "content": "This is the content...",
      "excerpt": "A brief excerpt",
      "author": "John Doe",
      "tags": ["tech", "swift"]
    },
    "status": "draft"
  }
}
```

### Update Content Entry

```graphql
mutation UpdateBlogPost($input: UpdateBlogPostInput!) {
  updateBlogPost(input: $input) {
    id
    status
    data {
      title
      content
    }
    updatedAt
  }
}
```

Variables:
```json
{
  "input": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "data": {
      "title": "Updated Title",
      "content": "Updated content..."
    },
    "status": "published"
  }
}
```

### Delete Content Entry

```graphql
mutation DeleteBlogPost($id: ID!) {
  deleteBlogPost(id: $id)
}
```

## Type System

### Scalars

```graphql
scalar JSON      # Arbitrary JSON data
scalar DateTime  # ISO-8601 datetime string
scalar ID        # UUID identifier
```

### Pagination Types

```graphql
type PageInfo {
  page: Int!
  perPage: Int!
  total: Int!
  totalPages: Int!
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
}

interface Connection {
  data: [Node!]!
  pageInfo: PageInfo!
}
```

### Content Status

```graphql
enum ContentStatus {
  DRAFT
  PUBLISHED
  ARCHIVED
}
```

## Field Type Mapping

SwiftCMS field types map to GraphQL types as follows:

| SwiftCMS Type | GraphQL Type | Description |
|---------------|--------------|-------------|
| `shortText` | `String` | Short text field |
| `longText` | `String` | Long text field |
| `richText` | `String` | Rich text (HTML/Markdown) |
| `integer` | `Int` | Integer number |
| `decimal` | `Float` | Decimal number |
| `boolean` | `Boolean` | True/false |
| `dateTime` | `DateTime` | ISO-8601 datetime |
| `email` | `String` | Email address |
| `enumeration` | `String` | Enum value |
| `json` | `JSON` | JSON object |
| `media` | `ID` | Media file reference |
| `relationHasOne` | `ID` | One-to-one relation |
| `relationHasMany` | `[ID]` | One-to-many relation |
| `component` | `JSON` | Component data |

## Error Handling

GraphQL errors follow the GraphQL specification:

```json
{
  "data": {
    "blogPost": null
  },
  "errors": [
    {
      "message": "Entry not found",
      "locations": [
        {
          "line": 2,
          "column": 3
        }
      ],
      "path": ["blogPost"],
      "extensions": {
        "code": "NOT_FOUND",
        "timestamp": "2024-02-14T10:30:00Z"
      }
    }
  ]
}
```

### Error Codes

| Code | Description |
|------|-------------|
| `AUTHENTICATION_REQUIRED` | Missing or invalid authentication |
| `AUTHORIZATION_FAILED` | Insufficient permissions |
| `VALIDATION_ERROR` | Input validation failed |
| `NOT_FOUND` | Resource not found |
| `INTERNAL_ERROR` | Server error |

## Real-time Subscriptions

SwiftCMS supports GraphQL subscriptions over WebSocket for real-time updates:

```graphql
subscription OnContentChange {
  contentUpdated {
    id
    contentType
    status
    updatedAt
  }
}
```

WebSocket endpoint: `wss://your-cms.com/ws`

## Query Complexity

SwiftCMS implements query complexity analysis to prevent abusive queries:

- Maximum query depth: 10 levels
- Maximum query complexity: 1000 points
- Query timeout: 30 seconds

Complexity costs:
- Scalar field: 1 point
- Object field: 10 points
- List field: 20 points + item cost

## Best Practices

### 1. Use Specific Fields

Only request fields you need:

```graphql
# Good
query {
  blogPost(id: "123") {
    id
    data {
      title
    }
  }
}

# Avoid
query {
  blogPost(id: "123") {
    id
    status
    createdAt
    updatedAt
    data {
      title
      slug
      excerpt
      content
      # ... all fields
    }
  }
}
```

### 2. Use Fragments for Reusability

```graphql
fragment PostSummary on BlogPost {
  id
  data {
    title
    slug
    excerpt
  }
}

query GetPosts {
  blogPostList {
    data {
      ...PostSummary
    }
  }
}
```

### 3. Batch Queries

Request multiple resources in a single query:

```graphql
query GetDashboardData {
  blogPostList(perPage: 5) {
    data {
      id
      data {
        title
      }
    }
  }
  productList(perPage: 5) {
    data {
      id
      data {
        name
      }
    }
  }
}
```

### 4. Use Variables

Don't hardcode values in queries:

```graphql
query SearchPosts($query: String!, $limit: Int) {
  blogPostList(filter: { title: { contains: $query } }, perPage: $limit) {
    data {
      id
      data {
        title
      }
    }
  }
}
```

## Playground

Access the GraphQL Playground at:

```
https://your-cms.com/graphql
```

The playground provides:
- Interactive query explorer
- Schema documentation browser
- Query history
- Real-time query validation

## Rate Limiting

GraphQL queries are rate limited:

- **Authenticated requests**: 1000 requests/hour
- **Public queries** (if enabled): 100 requests/hour

Rate limit headers are included in responses:

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 950
X-RateLimit-Reset: 1676428800
```

## SDL Generation

You can generate the GraphQL SDL (Schema Definition Language) for your content types:

```bash
curl https://your-cms.com/graphql/schema \
  -H "Authorization: Bearer YOUR_TOKEN"
```

This returns the complete GraphQL schema as SDL, which you can use for:
- Code generation
- Documentation
- Client-side type safety
- Schema validation

## Advanced Features

### DataLoader

SwiftCMS uses DataLoader patterns to prevent the N+1 query problem:

```graphql
query {
  blogPostList {
    data {
      id
      data {
        author  # Automatically batched
        tags    # Automatically batched
      }
    }
  }
}
```

### Query Caching

GraphQL queries are cached based on the query hash:

```http
Cache-Control: max-age=300
X-Cache-Key: sha256:abc123...
```

### Persisted Queries

Support for persisted queries (APQ):

```graphql
query GetPost($id: ID!) @persisted {
  blogPost(id: $id) {
    id
    data {
      title
    }
  }
}
```

## Client Libraries

### JavaScript/TypeScript

```typescript
import { GraphQLClient } from 'graphql-request'

const client = new GraphQLClient('https://your-cms.com/graphql', {
  headers: {
    Authorization: `Bearer ${token}`
  }
})

const query = `
  query GetPost($id: ID!) {
    blogPost(id: $id) {
      id
      data {
        title
      }
    }
  }
`

const data = await client.request(query, { id: '123' })
```

### Swift

```swift
import GraphQL

let client = GraphQLClient(endpoint: URL(string: "https://your-cms.com/graphql")!)
client.authorisationHeader = "Bearer \(token)"

let query = """
  query GetPost($id: ID!) {
    blogPost(id: $id) {
      id
      data {
        title
      }
    }
  }
"""

let result = try await client.query(
  query,
  variables: ["id": "123"]
)
```

## Further Reading

- [GraphQL Specification](https://spec.graphql.org/)
- [GraphQL Best Practices](https://graphql.best practices/)
- [SwiftCMS REST API](./rest.md)
- [WebSocket API](./websocket.md)
