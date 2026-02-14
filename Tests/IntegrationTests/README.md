# 🧪 Integration Testing Guide

This directory contains integration tests that validate the complete request/response cycle and major application features.

## 🚀 Test Categories

### 1. Health & Readiness Tests (`HealthCheckTests.swift`)

Tests for Kubernetes health checks and application monitoring:

```swift
final class HealthCheckTests: XCTestCase {
    func testHealthEndpointContract() {
        // GET /healthz -> 200
        // Always returns 200 if app is running
    }

    func testReadyEndpointContract() {
        // GET /ready -> 200 (if DB + Redis available)
        // Returns 503 if dependencies unavailable
    }

    func testStartupEndpointContract() {
        // /startup always returns 200 after app boot
    }
}
```

### 2. Smoke Tests (`HealthCheckTests.swift`)

High-level contract tests for major features:

```swift
final class SmokeTests: XCTestCase {
    func testContentTypeCreateContract() {
        // POST /api/v1/content-types -> 201 (success)
        // POST duplicate slug -> 409 (conflict)
        // POST missing name -> 400 (bad request)
    }

    func testContentEntryCRUDContract() {
        // Create -> Get -> Update -> Delete flow
        // Validates JSON Schema enforcement
    }

    func testAuthLoginContract() {
        // POST /api/v1/auth/login -> token (valid creds)
        // POST invalid creds -> 401 (unauthorized)
    }

    func testAdminRequiresSession() {
        // GET /admin (no session) -> 302 to /admin/login
        // GET /admin (with session) -> 200
    }
}
```

### 3. Feature Integration Tests

Major user flow validations:

#### Content Workflow
```swift
func testCompleteContentWorkflow() async throws {
    // 1. Create content type
    // 2. Create content entry
    // 3. Update entry multiple times (creates versions)
    // 4. Restore previous version
    // 5. Delete entry
    // 6. Delete content type
}
```

#### Media Workflow
```swift
func testMediaUploadAndProcessing() async throws {
    // 1. Upload image
    // 2. Verify thumbnail generation job queued
    // 3. Check thumbnails created
    // 4. Delete media
    // 5. Verify cleanup
}
```

#### User Management Workflow
```swift
func testUserLifecycle() async throws {
    // 1. Register user
    // 2. Verify email (if enabled)
    // 3. Login and get token
    // 4. Update profile
    // 5. Change password
    // 6. Delete account
}
```

#### Webhook Delivery
```swift
func testWebhookDeliveryFlow() async throws {
    // 1. Create webhook for content.created
    // 2. Create content entry
    // 3. Verify WebhookDelivery record created
    // 4. Check webhook job queued
    // 5. Verify delivery with idempotency key
}
```

## 🏗️ Test Setup Patterns

### Full Application Testing

```swift
final class IntegrationTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)

        // Use test database
        app.databases.use(.sqlite(.memory), as: .sqlite)
        try await app.autoMigrate()

        // Configure test services
        app.fileStorage.use(MockFileStorage.self)
        app.search.use(MockSearchProvider.self)
    }

    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
        app = nil
    }
}
```

## 🎯 Test Contracts

### API Contracts

Each API endpoint should have contract tests:

#### Success Cases
- Valid request → Expected success response
- Edge cases → Handled gracefully
- Performance → Meets SLA requirements

#### Error Cases
- Invalid authentication → 401 Unauthorized
- Forbidden access → 403 Forbidden
- Invalid data → 400 Bad Request
- Not found → 404 Not Found
- Conflict → 409 Conflict

### Database Contracts

- Transaction isolation
- Migration integrity
- Connection pooling
- Query performance

## 📊 Coverage Goals

| Category | Target |
|----------|--------|
| Unit Tests | 80% |
| Integration Tests | 60% |
| API Contracts | 100% |
| Critical Paths | 100% |

## 🔧 Common Issues

### Race Conditions
Use proper async patterns and serial queues for concurrent access.

### Test Isolation
Use separate databases or transactions per test.

### Flaky Tests
Use proper async expectations with reasonable timeouts.

---

**Emoji Guide**: 🧪 Testing, 🚀 Performance, 🔧 Configuration, 📊 Metrics, 🏗️ Setup, 🎯 Contracts

## 🔗 Related Documentation

- [Test Utilities](../Helpers/README.md)
- [CMSAdmin Tests](../CMSAdminTests/README.md)
- [API Documentation](../../docs/API.md)
- [Architecture Guide](../../docs/Architecture.md)
