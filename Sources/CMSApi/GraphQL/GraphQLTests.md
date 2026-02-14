# GraphQL Schema Generation Tests

## Test Cases for GraphQL Implementation

### 1. Schema Generation Tests

**Test: Generate schema from content type definitions**
```swift
func testGenerateSchemaFromContentTypes() async throws {
    // Given
    let app = Application(.testing)
    defer { app.shutdown() }

    // Create test content types
    let articleType = ContentTypeDefinition(
        name: "Article",
        slug: "article",
        displayName: "Article",
        jsonSchema: .dictionary([
            "type": .string("object"),
            "properties": .dictionary([
                "title": .dictionary(["type": .string("string"), "required": .bool(true)]),
                "content": .dictionary(["type": .string("string"), "required": .bool(true)]),
                "published": .dictionary(["type": .bool(false), "required": .bool(false)])
            ])
        ])
    )

    try await articleType.save(on: app.db)

    // When
    let generator = GraphQLSchemaGenerator(app: app)
    let schema = try await generator.generateSchema()

    // Then
    XCTAssertTrue(schema.contains("type Article"))
    XCTAssertTrue(schema.contains("title: String!"))
    XCTAssertTrue(schema.contains("content: String!"))
    XCTAssertTrue(schema.contains("published: Boolean"))
    XCTAssertTrue(schema.contains("article(id: ID!): Article"))
    XCTAssertTrue(schema.contains("createArticle(data: JSON!): Article!"))
}
```

**Test: Generate schema for specific content type**
```swift
func testGenerateSchemaForContentType() async throws {
    // Given
    let app = Application(.testing)
    defer { app.shutdown() }

    let pageType = ContentTypeDefinition(
        name: "Page",
        slug: "page",
        displayName: "Page",
        jsonSchema: .dictionary([
            "type": .string("object"),
            "properties": .dictionary([
                "slug": .dictionary(["type": .string("string"), "required": .bool(true)]),
                "title": .dictionary(["type": .string("string"), "required": .bool(true)])
            ])
        ])
    )

    try await pageType.save(on: app.db)

    // When
    let generator = GraphQLSchemaGenerator(app: app)
    let schema = try await generator.generateSchema(for: "page")

    // Then
    XCTAssertNotNil(schema)
    XCTAssertTrue(schema!.contains("type Page"))
    XCTAssertTrue(schema!.contains("slug: String!"))
    XCTAssertTrue(schema!.contains("page(id: ID!): Page"))
}
```

### 2. Type Mapping Tests

**Test: Map JSON schema string type to GraphQL**
```swift
func testMapStringType() {
    let generator = GraphQLSchemaGenerator(app: Application(.testing))
    let schema: [String: AnyCodableValue] = ["type": .string("string")]
    let result = mapToGraphQLType(schema, fieldType: "string")
    XCTAssertEqual(result, "String")
}

func testMapDateTimeType() {
    let generator = GraphQLSchemaGenerator(app: Application(.testing))
    let schema: [String: AnyCodableValue] = [
        "type": .string("string"),
        "format": .string("date-time")
    ]
    let result = mapToGraphQLType(schema, fieldType: "string")
    XCTAssertEqual(result, "DateTime")
}

func testMapIntegerType() {
    let generator = GraphQLSchemaGenerator(app: Application(.testing))
    let schema: [String: AnyCodableValue] = ["type": .string("integer")]
    let result = mapToGraphQLType(schema, fieldType: "integer")
    XCTAssertEqual(result, "Int")
}

func testMapArrayType() {
    let generator = GraphQLSchemaGenerator(app: Application(.testing))
    let schema: [String: AnyCodableValue] = [
        "type": .string("array"),
        "items": .dictionary(["type": .string("string")])
    ]
    let result = mapToGraphQLType(schema, fieldType: "array")
    XCTAssertEqual(result, "[String]")
}
```

### 3. Query Execution Tests

**Test: Execute content types query**
```swift
func testExecuteContentTypesQuery() async throws {
    // Given
    let app = Application(.testing)
    defer { app.shutdown() }

    // Create test data
    let type1 = ContentTypeDefinition(name: "Article", slug: "article", displayName: "Article")
    let type2 = ContentTypeDefinition(name: "Page", slug: "page", displayName: "Page")
    try await [type1, type2].create(on: app.db)

    let generator = GraphQLSchemaGenerator(app: app)
    let executor = GraphQLExecutor(app: app, generator: generator)
    let context = GraphQLContext(request: Request(application: app, on: app.eventLoopGroup.next()))

    // When
    let response = try await executor.execute(
        query: "{ contentTypes { name slug } }",
        context: context
    )

    // Then
    XCTAssertNotNil(response.data)
    XCTAssertNil(response.errors)
    // Verify response contains both content types
}

**Test: Execute content entries query**
```swift
func testExecuteContentEntriesQuery() async throws {
    // Given
    let app = Application(.testing)
    defer { app.shutdown() }

    // Create content type and entries
    let articleType = ContentTypeDefinition(name: "Article", slug: "article", displayName: "Article")
    try await articleType.save(on: app.db)

    let entry1 = ContentEntry(
        contentType: "article",
        data: .dictionary(["title": .string("Article 1"), "content": .string("Content 1")]),
        status: .published
    )
    let entry2 = ContentEntry(
        contentType: "article",
        data: .dictionary(["title": .string("Article 2"), "content": .string("Content 2")]),
        status: .published
    )
    try await [entry1, entry2].create(on: app.db)

    let generator = GraphQLSchemaGenerator(app: app)
    let executor = GraphQLExecutor(app: app, generator: generator)
    let context = GraphQLContext(request: Request(application: app, on: app.eventLoopGroup.next()))

    // When
    let response = try await executor.execute(
        query: """
        {
            contentEntries(contentType: "article", page: 1, perPage: 10) {
                data {
                    id
                    data
                }
                pageInfo {
                    total
                    hasNextPage
                }
            }
        }
        """,
        context: context
    )

    // Then
    XCTAssertNotNil(response.data)
    XCTAssertNil(response.errors)
    // Verify pagination info and data
}
```

### 4. Mutation Execution Tests

**Test: Execute create content entry mutation**
```swift
func testExecuteCreateContentEntryMutation() async throws {
    // Given
    let app = Application(.testing)
    defer { app.shutdown() }

    let generator = GraphQLSchemaGenerator(app: app)
    let executor = GraphQLExecutor(app: app, generator: generator)
    let context = GraphQLContext(request: Request(application: app, on: app.eventLoopGroup.next()))

    // When
    let response = try await executor.execute(
        query: """
        mutation {
            createContentEntry(
                contentType: "article",
                data: { title: "New Article", content: "Article content" }
            ) {
                id
                contentType
                data
                status
            }
        }
        """,
        context: context
    )

    // Then
    XCTAssertNotNil(response.data)
    XCTAssertNil(response.errors)
    // Verify entry was created
    let entries = try await ContentEntry.query(on: app.db).all()
    XCTAssertEqual(entries.count, 1)
}

**Test: Execute update content entry mutation**
```swift
func testExecuteUpdateContentEntryMutation() async throws {
    // Given
    let app = Application(.testing)
    defer { app.shutdown() }

    let entry = ContentEntry(
        contentType: "article",
        data: .dictionary(["title": .string("Original Title"), "content": .string("Original Content")]),
        status: .draft
    )
    try await entry.save(on: app.db)

    let generator = GraphQLSchemaGenerator(app: app)
    let executor = GraphQLExecutor(app: app, generator: generator)
    let context = GraphQLContext(request: Request(application: app, on: app.eventLoopGroup.next()))

    // When
    let response = try await executor.execute(
        query: """
        mutation {
            updateContentEntry(
                id: "\(entry.id!)",
                data: { title: "Updated Title" }
            ) {
                id
                data
                updatedAt
            }
        }
        """,
        context: context
    )

    // Then
    XCTAssertNotNil(response.data)
    XCTAssertNil(response.errors)
    // Verify entry was updated
    let updated = try await ContentEntry.find(entry.id, on: app.db)
    XCTAssertNotNil(updated)
}
```

### 5. Schema Caching Tests

**Test: Schema is cached after first generation**
```swift
func testSchemaCaching() async throws {
    // Given
    let app = Application(.testing)
    defer { app.shutdown() }

    let generator = GraphQLSchemaGenerator(app: app)

    // When - Generate schema twice
    let schema1 = try await generator.generateSchema()
    let schema2 = try await generator.generateSchema()

    // Then - Should be the same (cached)
    XCTAssertEqual(schema1, schema2)
    // In a real implementation, verify that database query was not repeated
}

fun testClearCache() async throws {
    // Given
    let app = Application(.testing)
    defer { app.shutdown() }

    let generator = GraphQLSchemaGenerator(app: app)
    let schema1 = try await generator.generateSchema()

    // When - Add new content type and clear cache
    let newType = ContentTypeDefinition(name: "New Type", slug: "new-type", displayName: "New Type")
    try await newType.save(on: app.db)
    await generator.clearCache()

    // Then - New schema should include new type
    let schema2 = try await generator.generateSchema()
    XCTAssertTrue(schema2.contains("type NewType"))
    XCTAssertNotEqual(schema1, schema2)
}
```

### 6. Error Handling Tests

**Test: Handle invalid query**
```swift
func testInvalidQueryReturnsError() async throws {
    // Given
    let app = Application(.testing)
    defer { app.shutdown() }

    let generator = GraphQLSchemaGenerator(app: app)
    let executor = GraphQLExecutor(app: app, generator: generator)
    let context = GraphQLContext(request: Request(application: app, on: app.eventLoopGroup.next()))

    // When
    let response = try await executor.execute(
        query: "{ invalidField }",
        context: context
    )

    // Then
    XCTAssertNotNil(response.errors)
    XCTAssertGreaterThan(response.errors?.count ?? 0, 0)
}

**Test: Handle database error gracefully**
```swift
func testDatabaseErrorHandling() async throws {
    // Given
    let app = Application(.testing)
    defer { app.shutdown() }

    // Simulate database error by not setting up migrations
    let generator = GraphQLSchemaGenerator(app: app)
    let executor = GraphQLExecutor(app: app, generator: generator)
    let context = GraphQLContext(request: Request(application: app, on: app.eventLoopGroup.next()))

    // When/Then
    do {
        _ = try await executor.execute(
            query: "{ contentTypes { name } }",
            context: context
        )
        XCTFail("Should have thrown an error")
    } catch {
        XCTAssertNotNil(error)
    }
}
```

### 7. Integration Tests

**Test: Full GraphQL endpoint flow**
```swift
func testGraphQLControllerEndpoints() async throws {
    // Given
    let app = Application(.testing)
    defer { app.shutdown() }

    // Configure app with routes
    try routes(app)
    try await app.autoMigrate()

    // Create test data
    let articleType = ContentTypeDefinition(
        name: "Article",
        slug: "article",
        displayName: "Article",
        jsonSchema: .dictionary([
            "type": .string("object"),
            "properties": .dictionary([
                "title": .dictionary(["type": .string("string"), "required": .bool(true)])
            ])
        ])
    )
    try await articleType.save(on: app.db)

    // Test schema endpoint
    let schemaResponse = try await app.sendRequest(.GET, "graphql/schema")
    XCTAssertEqual(schemaResponse.status, .ok)
    let schema = try schemaResponse.content.decode(String.self)
    XCTAssertTrue(schema.contains("type Article"))

    // Test POST query endpoint
    let queryResponse = try await app.sendRequest(
        .POST, "graphql",
        headers: ["Content-Type": "application/json"],
        body: ByteBuffer(string: "{\"query\": \"{ contentTypes { name } }\"}")
    )
    XCTAssertEqual(queryResponse.status, .ok)
    let result = try queryResponse.content.decode(GraphQLResponse.self)
    XCTAssertNil(result.errors)

    // Test GraphiQL endpoint
    let graphiqlResponse = try await app.sendRequest(.GET, "graphiql")
    XCTAssertEqual(graphiqlResponse.status, .ok)
    XCTAssertTrue(graphiqlResponse.headers.contentType?.description.contains("text/html") ?? false)
}
```

## Running the Tests

```bash
# Run all GraphQL tests
swift test --filter GraphQLTests

# Run specific test
swift test --filter testGenerateSchemaFromContentTypes
```

## Notes

1. These tests assume the testing environment is properly configured
2. Use in-memory SQLite for faster test execution
3. Mock external services (like Redis) when testing in isolation
4. Clean up test data between tests to ensure isolation
5. Consider using Docker for integration tests with PostgreSQL
