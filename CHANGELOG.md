# Changelog

All notable changes to SwiftCMS will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.1] - 2026-02-14

### Fixed — Build Stabilization & Path Sanitization

- **Actor Isolation**: Fixed `RedisStreamsEventBus` actor isolation issues using `nonisolated` methods and detached `Task` blocks.
- **Dependency Visibility**: Moved `AuthenticatedUser`, `CmsUser`, and `ApiError` to `CMSObjects` to resolve circular dependencies and scope issues.
- **Swift Concurrency**: Updated `configure.swift` and `entrypoint.swift` to use `async/await` for `autoMigrate()` and app execution.
- **Soto 6.x SDK**: Updated `S3StorageProvider` to comply with Soto v6/v7 breaking changes (`AWSHTTPBody`, `signURL`).
- **Project Structure**:
    - Relocated `VersionPruningJob` to `CMSJobs`.
    - Consolidated `StrapiSchemaParser` into `CMSCLI/StrapiParser.swift`.
    - Cleaned up `Package.swift` by removing redundant `path:` arguments.
    - Removed nested `SwiftCMS/SwiftCMS` directory references.
- **Tests**: Resolved test redeclaration (`AnyCodableValueTests`) in `CMSObjectsTests`.

### Changed

- Updated `AGENTS.md` status to reflect 45 passing tests (adjusted due to test consolidation).
- Updated `README.md` and `docs/installation.md` with correct repository paths.

## [0.1.0] - 2026-02-14

### Added — Wave 1 Foundation Complete

**Project Bootstrap (Agent 1)**
- Package.swift with all dependencies (Vapor 4.x, Fluent, jwt-kit v5, Leaf, Redis, Queues, Graphiti, Pioneer, JSONSchema, Soto v7, ArgumentParser, VaporHX)
- `Sources/App/` entry point, configure.swift, routes.swift
- docker-compose.yml (PostgreSQL 16, Redis 7, Meilisearch)
- .env.example, Makefile, Dockerfile

**Core Module System (Agent 2)**
- `CmsModule` protocol with register/boot/shutdown lifecycle
- `ModuleManager` with priority-based boot ordering
- `HookRegistry` — generic typed hook invocation system
- `Application+CMS` and `Request+CMS` extensions for DI

**Database Models & Migrations (Agent 3)**
- Fluent models: User, Role, Permission, ApiKey, MediaFile, ContentTypeDefinition, ContentEntry, ContentVersion, Webhook, WebhookDelivery, DeadLetterEntry, AuditLog
- Migrations with prepare() and revert() for all tables
- Content state machine (Draft, Review, Published, Archived, Deleted)
- Version history and audit logging models

**Auth (Agent 4)**
- `AuthProvider` protocol (pluggable auth abstraction)
- `Auth0Provider` — JWKS + jwt-kit JWT verification
- FirebaseProvider and LocalJWTProvider stubs
- RBAC middleware, session auth, API key middleware

**Shared DTOs (Agent 5)**
- `AnyCodableValue` — JSONB enum with custom Codable
- `ContentTypeDefinitionDTO`, `ContentEntryDTO`, `UserDTO`, `MediaFileDTO`
- `PaginationWrapper<T>` with `PaginationMeta`
- `ApiError` with structured error codes

**EventBus (Agent 6)**
- `EventBus` protocol with publish/subscribe/unsubscribe
- `InProcessEventBus` (single-instance)
- `RedisStreamsEventBus` (multi-instance horizontal scaling)
- Core event types: content CRUD, schema changes, user events
- CLI foundation with ArgumentParser

**Infrastructure (Agent 7)**
- Multi-stage Dockerfile (~200MB runtime image)
- Kubernetes manifests (Deployment, Service, HPA, ConfigMap, Secret)
- GitHub Actions CI (Swift Linux build + test)
- Health check endpoints (/healthz, /ready, /startup)

**Tests (Agent 8)**
- 46 tests across 4 modules (CMSObjects, CMSCore, CMSEvents, CMSSchema)
- Test fixtures and factories
- Integration test infrastructure

### Fixed — Build Stabilization

- Added `import NIOConcurrencyHelpers` to HookRegistry.swift and ModuleManager.swift (NIOLockedValueBox errors)
- Removed circular imports from PluginDiscovery.swift and PreviewAndPruning.swift
- Updated Middleware.swift to use `request.redis` instead of `request.application.redis`
- Updated RedisStreamsEventBus.swift to use correct Redis accessors
- Updated S3StorageProvider to match Soto v7.x API (PutObjectRequest body, signURL)
- Fixed WebSocketServer.swift throwing closure with `try?`, restored AuthProviderKey
- Fixed Queues scheduling syntax (`.minutely()` instead of `.everyMinute()`)
- Corrected `CmsUser` to `CMSSchema.User` in routes.swift
- Fixed auth middleware chaining in routes.swift

### Verified

- `swift build` — Exit Code 0
- `swift test` — 46/46 passed
- `swift run App` — Server starts on http://127.0.0.1:8080
- SQLite database initialized, migrations applied
- SEO and Analytics plugins discovered and booted
- /healthz, /ready, /ws endpoints active
