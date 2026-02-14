# Contributing to SwiftCMS

Thank you for your interest in contributing to SwiftCMS! This guide will help you get started with development, testing, and submitting contributions.

## Development Setup

### 1. Prerequisites

- Swift 6.1+ installed from [swift.org](https://swift.org/download/)
- Docker for running dependencies
- Git for version control

### 2. Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/SwiftCMS.git
cd Swift-CMS

# Add upstream remote
git remote add upstream https://github.com/artfularchivesstudio-spec/SwiftCMS.git
```

### 3. Install Dependencies

```bash
# Start PostgreSQL, Redis, Meilisearch
docker compose up -d postgres redis meilisearch

# Build the project
swift build

# Run migrations
swift run App migrate --yes
```

### 4. Run Tests

```bash
# Run all tests
swift test

# Run specific module tests
swift test --filter CMSCoreTests
swift test --filter CMSApiTests
```

### 5. Start Development Server

```bash
swift run App serve --hostname 0.0.0.0 --port 8080 --env development
```

## Branch Naming Convention

Use the format: `wave-{N}/agent-{N}-{short-description}`

Examples:
- `wave-1/agent-3-content-migration`
- `wave-2/agent-5-webhook-system`
- `wave-3/agent-7-documentation`

## Commit Message Format

Use the format: `[Agent-N] Module: Description`

Examples:
```bash
git commit -m "[Agent-3] CMSSchema: Add content_entries migration"
git commit -m "[Agent-5] CMSAuth: Implement Firebase authentication"
git commit -m "[Agent-7] Docs: Add WebSocket API documentation"
```

## Code Style Guidelines

### General Rules

1. **Swift Version**: Use Swift 6.1+ features only
2. **Async/Await**: Always use async/await, never callbacks or EventLoopFuture
3. **Sendable**: Mark all types crossing concurrency boundaries as `Sendable`
4. **Access Control**:
   - `public` for protocols, DTOs, and API types
   - `internal` for implementation
   - `private` for helpers

### Naming Conventions

```swift
// Types: UpperCamelCase
struct ContentTypeDefinition
typealias AuthProvider
protocol CmsEvent

// Properties/Functions: lowerCamelCase
var contentType: String
func validateEntry()

// Files: Match primary type
// ContentTypeDefinition.swift contains struct ContentTypeDefinition

// Protocols: Descriptive nouns/adjectives
protocol Authenticatable
protocol Validatable // No "Protocol" suffix

// DTOs: Suffix with DTO
struct CreateContentEntryDTO
struct UpdateContentEntryDTO
```

### Documentation

```swift
/// Public types, properties, and methods MUST have doc comments
/// - Parameter name: Description of parameter
/// - Returns: Description of return value
/// - Throws: Description of errors thrown
public func createContent(
    _ entry: CreateContentDTO,
    on database: Database
) async throws -> ContentEntry
```

### Error Handling

```swift
// Always handle errors gracefully
func processEntry(_ entry: ContentEntry) async throws {
    do {
        try await entry.save(on: db)
    } catch let error as ValidationError {
        // Handle specific error
        logger.error("Validation failed: \(error)")
        throw Abort(.badRequest, reason: error.reason)
    } catch {
        // Handle unexpected errors
        logger.error("Unexpected error: \(error)")
        throw Abort(.internalServerError, reason: "Something went wrong")
    }
}

// Create custom error types for your module
enum CMSAuthError: Error {
    case invalidToken
    case userNotFound
    case insufficientPermissions
}

extension CMSAuthError: AbortError {
    var status: HTTPResponseStatus {
        switch self {
        case .invalidToken: return .unauthorized
        case .userNotFound: return .notFound
        case .insufficientPermissions: return .forbidden
        }
    }

    var reason: String {
        switch self {
        case .invalidToken: return "Invalid authentication token"
        case .userNotFound: return "User not found"
        case .insufficientPermissions: return "Insufficient permissions"
        }
    }
}
```

## Testing Requirements

Write tests for all public methods. Aim for:
- **Minimum**: 1 test per public method
- **Target**: 80% code coverage
- **Focus**: Happy paths, error conditions, edge cases

### Test Structure

```swift
// Tests/SomeModuleTests/SomeServiceTests.swift
import XCTest
import XCTVapor
@testable import SomeModule

final class SomeServiceTests: XCTestCase {

    var app: Application!

    override func setUp() async throws {
        app = Application(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
        app = nil
    }

    func testCreateContent() async throws {
        // Arrange
        let dto = CreateContentDTO(title: "Test", content: "Test content")
        let service = ContentService()

        // Act
        let result = try await service.create(dto, on: app.db)

        // Assert
        XCTAssertEqual(result.title, "Test")
        XCTAssertEqual(result.status, .draft)
        XCTAssertNotNil(result.id)
    }

    func testCreateContentWithEmptyTitleFails() async throws {
        // Arrange
        let dto = CreateContentDTO(title: "", content: "Test")
        let service = ContentService()

        // Act & Assert
        await XCTAssertThrowsError(
            try await service.create(dto, on: app.db)
        ) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }

    // MARK: - Helper Methods

    private func configure(_ app: Application) async throws {
        // Setup test configuration
        try app.databases.use(.sqlite(.memory), as: .psql)
        app.http.server.configuration.port = 0 // Random port
        try await app.autoMigrate()
    }
}
```

### Common Test Patterns

```swift
// Test with database
func testWithDatabase() async throws {
    let entry = try await ContentEntry.create(
        contentType: "posts",
        data: ["title": "Test"]
    )
    _ = try await entry.save(on: app.db)

    let fetched = try await ContentEntry.find(entry.id!, on: app.db)
    XCTAssertEqual(fetched?.data.title, "Test")
}

// Test API endpoints
func testCreateUserEndpoint() async throws {
    try await app.test(.POST, "api/v1/users") { req in
try req.content.encode(CreateUserDTO(email: "test@test.com", password: "password"))
    } afterResponse: { res in
XCTAssertEqual(res.status, .created)
        let user = try res.content.decode(UserDTO.self)
XCTAssertEqual(user.email, "test@test.com")
    }
}

// Test event handlers
func testEventHandler() async throws {
    let event = ContentCreatedEvent(entryId: UUID(), contentType: "posts")
    let handler = MyContentHandler()

    await handler.handle(event, context: testContext)

    XCTAssertEqual(handler.callCount, 1)
}
```

## Pull Request Process

### 1. Create Feature Branch

```bash
git checkout -b wave-2/agent-5-new-feature
```

### 2. Make Changes

- Follow code style guidelines
- Add tests for new functionality
- Update documentation if needed

### 3. Run Quality Checks

```bash
# Run tests
swift test

# Format code (if using swift-format)
swift format -i -r Sources/

# Lint code (if using swiftlint)
swiftlint lint --fix

# Build for release
swift build -c release
```

### 4. Update Documentation

- Update README.md if needed
- Add API documentation for new endpoints
- Update CHANGELOG.md with changes

### 5. Submit Pull Request

1. Push your branch to your fork
2. Create PR against `main` branch
3. Fill out PR template:
   - Description of changes
   - Testing performed
   - Screenshots (for UI changes)
   - Breaking changes (if any)

### 6. Code Review

- Address reviewer feedback
- Update PR based on comments
- Ensure CI passes all checks

## Directory Ownership

Each source directory is "owned" by specific agents to coordinate work:

```
Sources/App/         - Agent 1 (Entry point, routes)
Sources/CMSCore/     - Agent 2 (Module system, utilities)
Sources/CMSSchema/   - Agent 3 (Database models, migrations)
Sources/CMSObjects/  - Agent 5 (Shared DTOs only)
Sources/CMSAuth/     - Agent 4 (Authentication, authorization)
Sources/CMSMedia/    - Agent 4 (Media management)
Sources/CMSApi/      - Agent 2 (REST API endpoints)
Sources/CMSSearch/   - Agent 6 (Search functionality)
Sources/CMSEvents/   - Agent 6, 7 (Event system, webhooks)
Sources/CMSJobs/     - Agent 7 (Background jobs)
Sources/CMSAdmin/    - Agent 3 (Admin panel UI)
Tests/               - Agent 8 (Test coverage)
```

**Rule**: Only modify files in your assigned directories. For changes elsewhere:
1. Create an issue describing the needed change
2. Discuss with the owning agent
3. Use `HANDOFF.md` for cross-module requests

## Common Workflows

### Adding a New Feature

1. Create feature branch from `main`
2. Implement changes with tests
3. Update relevant documentation
4. Ensure CI passes
5. Submit PR with detailed description

### Bug Fixes

1. Create branch: `wave-{N}/agent-{M}-fix-description`
2. Reproduce issue with test
3. Implement fix
4. Verify test passes
5. Submit PR referencing issue

### Documentation Updates

1. Use `docs/` directory for new guides
2. Update existing docs for API changes
3. Add examples in `examples/`
4. Update README.md if needed

## Release Process

### For Maintainers

1. Update version in `Package.swift`
2. Update `CHANGELOG.md`
3. Create and push tag:
   ```bash
   git tag -a v2.0.0 -m "Release version 2.0.0"
   git push origin v2.0.0
   ```
4. GitHub Actions will create release
5. Deploy to staging first, then production

## Questions or Need Help?

- Check existing [issues on GitHub](https://github.com/artfularchivesstudio-spec/SwiftCMS/issues)
- Join [discussions](https://github.com/artfularchivesstudio-spec/SwiftCMS/discussions)
- Review [documentation](./docs/)

Thank you for contributing to SwiftCMS!
