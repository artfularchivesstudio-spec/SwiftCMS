# 🧪 Test Utilities & Helpers

This directory contains shared test utilities, fixtures, and helpers used across the SwiftCMS test suite.

## 📁 Directory Structure

```
Helpers/
├── TestFixtures.swift      # Factory methods for creating test data
└── README.md               # This file
```

## 🛠️ Available Test Fixtures

### TestFixtures.swift

Factory methods providing sensible defaults for common test objects:

#### Content Type DTO Fixtures
```swift
// Creates a basic article content type
let articleType = TestFixtures.makeContentTypeDTO(
    name: "Articles",
    slug: "articles"
)

// Creates with custom parameters
let productType = TestFixtures.makeContentTypeDTO(
    name: "Products",
    slug: "products",
    displayName: "Product Catalog"
)
```

#### Content Entry DTO Fixtures
```swift
// Creates a default article entry
let entry = TestFixtures.makeContentEntryDTO()

// Creates with custom content
let publishedEntry = TestFixtures.makeContentEntryDTO(
    title: "My Published Article",
    body: "Article content here",
    published: true
)
```

#### User DTO Fixtures
```swift
// Creates a test user
let user = TestFixtures.makeUserDTO()

// Creates with custom email
let adminUser = TestFixtures.makeUserDTO(email: "admin@example.com")
```

#### Webhook DTO Fixtures
```swift
// Creates a test webhook
let webhook = TestFixtures.makeWebhookDTO()

// Creates with custom URL
let customWebhook = TestFixtures.makeWebhookDTO(
    name: "Production Webhook",
    url: "https://api.production.com/webhook"
)
```

#### Sample JSON Schemas
```swift
// Gets a sample article schema for testing
let schema = TestFixtures.sampleArticleSchema()
```

## 🎯 Best Practices

1. **Use Fixtures for Test Data**
   - Always use `TestFixtures` to create test data
   - Avoid hardcoding test data in individual tests
   - Fixtures ensure consistent test data across the suite

2. **Customize When Needed**
   - Override default values as needed for specific test cases
   - Keep defaults sensible for most common scenarios

3. **Domain-Specific Fixtures**
   - Create module-specific fixtures in their respective test directories
   - Example: `CMSAdminTests/Fixtures/AdminTestFixtures.swift`

4. **Factory Pattern**
   - Use static factory methods for creating test objects
   - Provide sensible defaults with optional customization parameters

## 📊 Testing Guidelines

### 🧪 Test Organization

1. **Unit Tests**: Test individual components in isolation
2. **Integration Tests**: Test component interactions
3. **Snapshot Tests**: Test UI output consistency
4. **Contract Tests**: Test API contracts and behaviors

### 🎭 Mock Objects

```swift
// Example mock pattern for testing
private final class MockWebSocket: WebSocket {
    var onSendText: ((String) -> Void)?
    var onSendBinary: ((ByteBuffer) -> Void)?

    override func send(_ text: String) async throws {
        onSendText?(text)
    }
}
```

### 🏗️ Test Setup Patterns

```swift
final class MyModuleTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        // Configure app for testing
    }

    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
        app = nil
    }
}
```

## 🔧 Available Testing Tools

### XCTest + XCTVapor
- Standard Swift testing framework
- Vapor-specific testing utilities
- Async/await support

### SnapshotTesting
- HTML snapshot testing for admin UI
- Visual regression testing
- Configurable precision levels

### Fluent SQLite Driver
- In-memory database for fast tests
- Automatic migration handling
- Clean test isolation

## 📈 Coverage Goals

- **Minimum Coverage**: 80% across all modules
- **Critical Paths**: 100% coverage for authentication and authorization
- **Integration Tests**: Cover major user flows
- **Snapshot Tests**: Cover all admin UI templates

## 🚀 Running Tests

```bash
# Run all tests
swift test

# Run specific test module
swift test --filter CMSCoreTests

# Run with coverage
swift test --enable-code-coverage

# Run specific test
swift test --filter testLoginSnapshot
```

## 🤝 Contributing

When adding new features:

1. Create corresponding test fixtures
2. Write unit tests for new functions
3. Add integration tests for new features
4. Update snapshot tests for UI changes
5. Ensure tests pass on both macOS and Linux

## 📚 Related Documentation

- [Snapshot Testing Guide](../CMSAdminTests/README.md#snapshot-testing)
- [Integration Tests](../IntegrationTests/README.md)
- [Module READMEs](../../Sources/)

---

**Emoji Guide**: 🧪 Tests, 🎯 Testing, 📊 Coverage, 🛠️ Utilities, 📸 Snapshots, 🤖 Automation, 🚀 Performance, 🎭 Mocking
