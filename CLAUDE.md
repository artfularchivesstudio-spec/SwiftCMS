# CLAUDE.md — SwiftCMS Project Configuration

This file is automatically loaded by Claude Code. It contains the global rules, conventions, and architecture context for the SwiftCMS project.

## Project Overview

SwiftCMS is an open-source, headless CMS built entirely in Swift using Vapor 4.x. It targets Apple-centric teams with runtime-defined content types, JSONB-first storage, and type-safe Swift client SDK generation.

**Repo root:** `/Users/gurindersingh/Documents/Developer/Swift-CMS/`
**Remote:** `https://github.com/artfularchivesstudio-spec/SwiftCMS.git`

## Swift & Toolchain

- **Swift version:** 6.1+ — use async/await and Sendable. NO callback patterns.
- **Vapor version:** 4.x (latest) — `from: "4.89.0"`
- **Platform:** Code MUST compile on macOS AND Linux (Ubuntu 24.04). NO macOS-only Foundation APIs.
- **Package manager:** SPM only. No CocoaPods, Carthage, or .xcodeproj files.
- **Minimum deployment:** `.macOS(.v13)` in Package.swift platforms array.

## Coding Standards

### Naming
- **Types:** UpperCamelCase — `ContentTypeDefinition`, `AuthProvider`, `CmsEvent`
- **Properties & functions:** lowerCamelCase — `contentType`, `jsonSchema`, `validateEntry()`
- **Files:** Match the primary type — `ContentTypeDefinition.swift`
- **Protocols:** Descriptive nouns/adjectives. NO `Protocol` suffix.
- **DTOs:** Suffix with `DTO` — `CreateContentEntryDTO`. ALL DTOs live in `Sources/CMSObjects/` only.

### Rules
- **Access control:** `public` for protocols, DTOs, API types. `internal` for implementation. `private` for helpers.
- **Async/await:** Use for ALL async ops. NEVER use `EventLoopFuture` or callbacks.
- **Error handling:** Throw `Abort(.notFound)`, `Abort(.badRequest, reason: "...")`. Use `AbortError` for HTTP errors.
- **Sendable:** ALL types shared across concurrency boundaries MUST be `Sendable`.
- **Doc comments:** `///` on ALL public types, properties, methods.
- **No force unwrap:** NEVER use `!` to unwrap. Use `guard let`, `if let`, or `??`.
- **No print():** Use `req.logger.info()` / `.warning()` / `.error()`. NEVER `print()` in production code.
- **Imports:** One per line, sorted alphabetically. Import only what you need.

## Vapor & Fluent Patterns

- **Routes:** Use `RouteCollection` protocol. Group related routes. Register in `routes.swift`.
- **Fluent models:** `@ID(key: .id) var id: UUID?` for all PKs. Use `@Field`, `@OptionalField`, `@Timestamp`, `@Parent`.
- **Migrations:** One per file. Name: `Create{Table}.swift`. Always implement `prepare()` AND `revert()`.
- **JSONB columns:** Use `.custom("JSONB")` for PostgreSQL. Type as `[String: AnyCodableValue]` in models.
- **Database access:** Use `req.db` in handlers. Use `app.db` ONLY in migrations, seeds, and `boot()`.
- **Content conformance:** Models/DTOs returned in responses MUST conform to `Content`.
- **Validation:** Use `Validatable` protocol on request DTOs. Validate BEFORE database operations.
- **Middleware order:** ErrorMiddleware > Sessions > CORS > RateLimit > Auth > Custom.

## Git & Collaboration Rules

- **Branch naming:** `wave-{N}/agent-{N}-{short-desc}` — e.g., `wave-1/agent-3-database-models`
- **Commit messages:** `[Agent-N] Module: Description` — e.g., `[Agent-3] CMSSchema: Add content_entries migration`
- **STAY IN YOUR LANE:** ONLY create/edit files in your assigned directories. Cross-module requests go in `HANDOFF.md`.
- **Package.swift:** Agent 1 (W1) owns this. New dependency? Add request to `HANDOFF.md`.
- **Tests:** Write unit tests in `Tests/{Module}Tests/`. Minimum: 1 test per public function.

## Directory Ownership Map

| Directory | Owner | Wave |
|---|---|---|
| `Sources/App/` | Agent 1 | W1 (entry point), W2+ (routes) |
| `Sources/CMSCore/` | Agent 2 | W1 |
| `Sources/CMSSchema/` | Agent 3 (W1 models), Agent 1 (W2 engine) | W1-W2 |
| `Sources/CMSApi/REST/` | Agent 2 | W2 |
| `Sources/CMSApi/GraphQL/` | Agent 1 | W3 |
| `Sources/CMSAdmin/` | Agent 3 | W2 |
| `Sources/CMSAuth/` | Agent 4 (W1), Agent 5 (W2) | W1-W2 |
| `Sources/CMSMedia/` | Agent 4 | W2 |
| `Sources/CMSSearch/` | Agent 6 | W2 |
| `Sources/CMSEvents/` | Agent 6 (W1), Agent 7 (W2) | W1-W2 |
| `Sources/CMSJobs/` | Agent 7 | W2 |
| `Sources/CMSObjects/` | Agent 5 | W1 (others import, NEVER modify) |
| `Sources/CMSCLI/` | Agent 6 (W1), Agent 1 (W4), Agent 3 (W4) | W1-W4 |
| `Modules/` | Agent 2 | W4 |
| `Tests/` | Agent 8 (all waves) | All |
| `Docker/CI files` | Agent 7 | W1 |

## Shared Type Contracts

### Protocols (defined by Agent 2 W1, Agent 5 W1)

- **CmsModule:** `name`, `priority`, `register(app:)`, `boot(app:)`, `shutdown(app:)`
- **AuthProvider:** `name`, `configure(app:)`, `verify(token:on:)`, `middleware()`
- **AuthenticatedUser:** `userId`, `email?`, `roles`, `tenantId?` — conforms to `Authenticatable`, `Sendable`
- **EventBus:** `publish(event:context:)`, `subscribe(type:handler:)`, `unsubscribe(id:)`
- **CmsEvent:** `static var eventName: String` — conforms to `Codable`, `Sendable`
- **FileStorageProvider:** `upload(key:data:contentType:)`, `download(key:)`, `delete(key:)`, `publicURL(key:)`

### Key DTOs (Sources/CMSObjects/)

- **AnyCodableValue:** Enum: `.string`, `.int`, `.double`, `.bool`, `.array`, `.dictionary`, `.null`
- **PaginationWrapper<T: Content>:** `data: [T]`, `meta: PaginationMeta`
- **ApiError:** `error`, `statusCode`, `reason`, `details` — conforms to `AbortError` + `Content`

## Technology Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.10+ |
| HTTP Server | Vapor 4.x |
| ORM | Fluent 4.x (PostgreSQL + SQLite) |
| Database | PostgreSQL 16+ (prod), SQLite (dev) |
| Cache/Queues/Sessions | Redis 7+ |
| Auth | Auth0 (primary), Firebase Auth, Local JWT |
| GraphQL | Graphiti v3 + Pioneer |
| Admin | Leaf + HTMX + Alpine.js + Tailwind/DaisyUI |
| JSON Validation | kylef/JSONSchema.swift |
| File Storage | Soto v7 (S3) + local |
| Search | Meilisearch |
| Background Jobs | Vapor Queues (Redis driver) |
| Event Bus | Redis Streams / In-process |
| CLI | swift-argument-parser |
| Deployment | Docker + Kubernetes |

## Build & Test Commands

```bash
swift build          # Build all targets
swift test           # Run all tests (46 tests across 4 modules)
swift run App        # Run the server (http://127.0.0.1:8080)
make docker-up       # Start PostgreSQL + Redis + Meilisearch
make docker-down     # Stop containers
make test            # Run tests
make build           # Build
```

## Key Endpoints

- `GET /healthz` — Health check (200 OK)
- `GET /ready` — Readiness (checks DB + Redis)
- `WS /ws` — WebSocket endpoint

## Reference Documents

- `SwiftCMS Master Plan V2.docx` — Full architecture & implementation plan
- `SwiftCMS Agent Checklist.docx` — Step-by-step agent task checklist
- `AGENTS.md` — Agent definitions & wave assignments
- `FEATURES.md` — Complete feature inventory with status
- `CHANGELOG.md` — Version history
- `HANDOFF.md` — Cross-module requests between agents
