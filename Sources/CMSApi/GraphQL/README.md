# SwiftCMS GraphQL API

## Overview

SwiftCMS now includes a complete GraphQL API implementation using Graphiti v1.15.1 and Pioneer server, providing a flexible and type-safe way to query and mutate content.

## Features

- **Dynamic Schema Generation**: GraphQL schema is automatically generated from ContentTypeDefinition models
- **Full CRUD Operations**: Create, read, update, and delete content entries via GraphQL
- **Content Type Introspection**: Query available content types and their schemas
- **Pagination**: Built-in pagination support for listing entries
- **Filtering**: Filter entries by field values
- **GraphiQL IDE**: Interactive GraphQL IDE at `/graphiql`
- **Caching**: Schema caching for improved performance
- **WebSocket Support**: Real-time subscriptions (future enhancement)

## Endpoints

- `POST /graphql` - Main GraphQL endpoint
- `GET /graphql?query={...}` - GraphQL endpoint via GET (for simple queries)
- `GET /graphiql` - GraphiQL IDE for interactive queries
- `GET /graphql/schema` - SDL introspection endpoint
- `GET /playground` - Alternative GraphQL Playground IDE

## Queries

### Get Content Type
```graphql
query {
  contentType(slug: "article") {
    id
    name
    slug
    jsonSchema
  }
}
```

### List Content Types
```graphql
query {
  contentTypes {
    id
    name
    slug
    displayName
  }
}
```

### Get Single Content Entry
```graphql
query {
  contentEntry(id: "123e4567-e89b-12d3-a456-426614174000") {
    id
    contentType
    data
    status
    createdAt
    updatedAt
  }
}
```

### List Content Entries
```graphql
query {
  contentEntries(
    contentType: "article",
    page: 1,
    perPage: 10,
    filter: { status: "published" }
  ) {
    data {
      id
      contentType
      data
      createdAt
    }
    pageInfo {
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

### Type-Specific Queries
For each content type, dynamic queries are generated:

```graphql
# Assuming 'article' is a content type
query {
  article(id: "123e4567-e89b-12d3-a456-426614174000") {
    id
    title
    content
    author
    publishedAt
  }

  articleList(page: 1, perPage: 20, filter: { status: "published" }) {
    data {
      id
      title
      content
      author
    }
    pageInfo {
      total
      hasNextPage
    }
  }
}
```

## Mutations

### Create Content Entry
```graphql
mutation {
  createContentEntry(
    contentType: "article",
    data: {
      title: "My Article",
      content: "Article content...",
      author: "John Doe"
    }
  ) {
    id
    contentType
    data
    status
    createdAt
  }
}
```

### Update Content Entry
```graphql
mutation {
  updateContentEntry(
    id: "123e4567-e89b-12d3-a456-426614174000",
    data: {
      title: "Updated Title",
      content: "Updated content..."
    }
  ) {
    id
    data
    updatedAt
  }
}
```

### Delete Content Entry
```graphql
mutation {
  deleteContentEntry(id: "123e4567-e89b-12d3-a456-426614174000")
}
```

### Type-Specific Mutations
For each content type, dynamic mutations are generated:

```graphql
# Assuming 'article' is a content type
mutation {
  createArticle(data: { title: "New Article", content: "..." }) {
    id
    title
    content
  }

  updateArticle(id: "123...", data: { title: "Updated" }) {
    id
    title
  }

  deleteArticle(id: "123...")
}
```

## Type Mappings

SwiftCMS JSON Schema fields are mapped to GraphQL types:

| JSON Schema Type | GraphQL Type |
|-----------------|--------------|
| `string` | `String` |
| `string` (format: date-time) | `DateTime` |
| `string` (format: uuid) | `ID` |
| `integer` | `Int` |
| `number` | `Float` |
| `boolean` | `Boolean` |
| `array` | `[Type]` |
| `object` | `JSON` |

## Schema Caching

The GraphQL schema is cached for performance:
- Schema is generated on first request after startup
- Schema is cached by content type slug
- Cache is cleared when content type definitions change

## Authentication

GraphQL endpoints respect the same authentication rules as the REST API:
- Public queries can be performed without authentication (if configured)
- Mutations require authentication
- Field-level permissions are enforced

## Examples

### Query with Nested Fields
```graphql
query {
  articleList(page: 1, perPage: 5) {
    data {
      id
      title
      author {
        name
        email
      }
      tags
      publishedAt
    }
    pageInfo {
      total
      hasNextPage
    }
  }
}
```

### Mutation with Relations
```graphql
mutation {
  createArticle(data: {
    title: "My Article",
    author: "author-id-123",
    tags: ["swift", "cms", "graphql"],
    meta: {
      seoTitle: "My SEO Title",
      description: "Article description"
    }
  }) {
    id
    title
    publishedAt
  }
}
```

## WebSocket Subscriptions

WebSocket support is configured via Pioneer. To enable subscriptions:

1. Connect to `ws://localhost:8080/graphql` (or your server URL)
2. Use GraphQL subscription syntax:

```graphql
subscription {
  contentEntryCreated(contentType: "article") {
    id
    title
    createdAt
  }
}
```

## Performance Considerations

1. **Schema Generation**: Schema is generated once and cached
2. **Field Selection**: Only requested fields are resolved (GraphQL default)
3. **Pagination**: Use pagination for large result sets
4. **Filtering**: Apply filters at the database level when possible
5. **N+1 Queries**: Use DataLoader pattern for resolving relations (future enhancement)

## Future Enhancements

- [ ] DataLoader integration for efficient relation resolution
- [ ] Field-level permissions in GraphQL
- [ ] Custom directives for authorization
- [ ] Subscriptions for real-time updates
- [ ] Query complexity analysis and limits
- [ ] Query persistence and whitelisting
- [ ] Federation support for microservices

## Implementation Details

The GraphQL implementation consists of:

- `GraphQLSchemaGenerator`: Generates GraphQL SDL from content types
- `GraphQLExecutor`: Executes GraphQL queries
- `GraphQLController`: HTTP endpoint handlers
- `GraphQLContext`: Context for resolvers with auth
- `GraphQLTypes`: GraphQL type definitions

## Testing

Use GraphiQL or GraphQL Playground to test queries:

1. Open `http://localhost:8080/graphiql`
2. Write your query in the left pane
3. Press the play button or Ctrl+Enter
4. View results in the right pane

## API Version

GraphQL API version: `v1`

For more information, see the [SwiftCMS Documentation](https://github.com/artfularchivesstudio-spec/SwiftCMS).
