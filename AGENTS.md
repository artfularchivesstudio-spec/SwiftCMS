# AGENTS.md — SwiftCMS Multi-Agent Development Strategy

8 parallel agents x 4 waves. Each agent has strict directory ownership. Cross-module requests go in `HANDOFF.md`.

---

## Directory Ownership Map

- `Sources/App/`: Agent 1 (W1)
- `Sources/CMSCore/`: Agent 2 (W1)
- `Sources/CMSSchema/Models/`: Agent 3 (W1)
- `Sources/CMSSchema/Migrations/`: Agent 3 (W1)
- `Sources/CMSSchema/Engine/`: Agent 1 (W2)
- `Sources/CMSSchema/Relations/`: Agent 3 (W3)
- `Sources/CMSSchema/Workflow/`: Agent 2 (W3)
- `Sources/CMSSchema/I18n/`: Agent 4 (W3)
- `Sources/CMSSchema/Versioning/`: Agent 4 (W4)
- `Sources/CMSApi/REST/`: Agent 2 (W2)
- `Sources/CMSApi/GraphQL/`: Agent 1 (W3)
- `Sources/CMSApi/WebSocket/`: Agent 2 (W3)
- `Sources/CMSAdmin/`: Agent 3 (W2), Agent 6 (W3)
- `Sources/CMSAuth/`: Agent 4 (W1), Agent 5 (W2)
- `Sources/CMSMedia/`: Agent 4 (W2)
- `Sources/CMSSearch/`: Agent 6 (W2)
- `Sources/CMSEvents/`: Agent 6 (W1), Agent 7 (W2)
- `Sources/CMSJobs/`: Agent 7 (W2)
- `Sources/CMSObjects/`: Agent 5 (W1)
- `Sources/CMSCLI/`: Agent 6 (W1), Agent 1 (W4), Agent 3 (W4)
- `Modules/`: Agent 2 (W4)
- `Tests/`: Agent 8 (All Waves)
- `Dockerfile`, `k8s/`, `.github/`: Agent 7 (W1)

---

## Shared Type Contracts

Defined by Agent 5 (W1) and Agent 2 (W1). Every agent codes against these.

### Protocols
- [x] **CmsModule**: `name`, `priority`, `register(app:)`, `boot(app:)`, `shutdown(app:)`.
- [x] **AuthProvider**: `name`, `configure(app:)`, `verify(token:, on req:) -> AuthenticatedUser`, `middleware()`.
- [x] **AuthenticatedUser**: `userId`, `email`, `roles`, `tenantId`. Conforms to `Authenticatable`.
- [x] **EventBus**: `publish(event:, context:)`, `subscribe(type:, handler:) -> UUID`.
- [x] **CmsEvent**: `eventName`. Conforms to `Codable`, `Sendable`.
- [x] **FileStorageProvider**: `upload`, `download`, `delete`, `publicURL`.

### Key DTOs
- [x] **AnyCodableValue**: Enum for JSONB (string, int, double, bool, array, dictionary, null).
- [x] **PaginationWrapper<T>**: `data`, `meta` (page, perPage, total, totalPages).
- [x] **ApiError**: `error: true`, `statusCode`, `reason`, `details`.

---

## WAVE 1 — Foundation & Core Infrastructure (Weeks 1-3)

**Goal:** Server boots, connects PostgreSQL + Redis, authenticates Auth0 JWT, `/healthz` returns 200, module system + EventBus work.
**Status:** COMPLETE (45/45 tests passing)

### AGENT 1: PROJECT BOOTSTRAP
- [x] Create `Package.swift` with all dependencies (Vapor, Fluent, Soto v7, etc.).
- [x] Create `Sources/App/entrypoint.swift` with `@main`.
- [x] Create `Sources/App/configure.swift` (Fluent, Redis, Leaf, sessions).
- [x] Create `Sources/App/routes.swift` (/healthz, /ready, /startup).
- [x] Create `docker-compose.yml` (Postgres, Redis, Meilisearch).
- [x] Create `.env.example` with standard set of variables.
- [x] Create `Makefile` for developer workflow.

### AGENT 2: CORE MODULE SYSTEM
- [x] `CmsModule.swift` protocol definition.
- [x] `ModuleManager.swift` for registration and priority boot sequence.
- [x] `HookRegistry.swift` for generic typed hook system.
- [x] `Application+CMS.swift` extensions (app.cms).
- [x] `Request+CMS.swift` extensions (req.cms).
- [x] `CMSCoreTests` verifying boot order and hooks.

### AGENT 3: DATABASE MODELS & MIGRATIONS
- [x] Models: `User`, `Role`, `Permission`, `ApiKey`, `MediaFile`, `Webhook`, `ContentTypeDefinition`, `ContentEntry`.
- [x] `ContentEntry.swift` using JSONB for data and status tracking.
- [x] `ContentVersion.swift` and `AuditLog.swift` models.
- [x] All migrations created and verified.
- [x] GIN indexes on `content_entries.data` for JSONB efficiency.
- [x] `SeedDefaultRoles.swift` migration.

### AGENT 4: AUTH0 PROVIDER
- [x] `AuthProvider.swift` shared protocol.
- [x] `Auth0Provider.swift` using `jwt-kit` v5 for JWKS verification.
- [x] Stubs for `FirebaseProvider` and `LocalJWTProvider`.
- [x] `RBACMiddleware.swift` (Resource:Action permission checking).
- [x] Integration tests for Auth0 token verification.

### AGENT 5: SHARED DTOs
- [x] `AnyCodableValue.swift` with custom `Codable` for JSONB.
- [x] `ContentTypeDefinitionDTO`, `ContentEntryDTO`, `UserDTO`.
- [x] `PaginationWrapper` generic DTO.
- [x] `ApiError` structured error responses.

### AGENT 6: EVENTBUS & CLI FOUNDATION
- [x] `EventBus.swift` protocol.
- [x] `InProcessEventBus.swift` implementation.
- [x] `RedisStreamsEventBus.swift` (Distributed EventBus).
- [x] `CmsCLI` foundation using `ArgumentParser`.
- [x] Core event types: `content.created/updated/deleted`, `schema.changed`.

### AGENT 7: DOCKER & CI/CD
- [x] Multi-stage `Dockerfile` (optimized Swift runner).
- [x] `ci.yml` for GitHub Actions (test, build, lint).
- [x] Kubernetes manifests (`k8s/`).
- [x] Health check endpoints verification in CI.

### AGENT 8: INTEGRATION & TESTS
- [x] `XCTVapor` test infrastructure setup.
- [x] Unit/Integration tests coverage.
- [x] `HANDOFF.md` resolution.

---

## WAVE 2 — Content Engine & API Layer (Weeks 4-6)

**Goal:** SwiftCMS becomes a functional headless CMS.
**Status:** PENDING

### AGENT 1: CONTENT TYPE ENGINE
- [ ] `JSONSchema.swift`: Generate JSON Schema from `ContentTypeDefinition`.
- [ ] `SchemaValidator.swift`: Validate `ContentEntry.data` vs `jsonSchema`.
- [ ] `FieldTypeRegistry.swift`: Support for 14 core field types.
- [ ] `SchemaChangedEvent` listener: Trigger re-indexers/cache clear.
- [ ] Relation resolver service: UUID -> Entry mapping.

### AGENT 2: REST API CONTROLLERS
- [ ] `DynamicContentController`: `/api/v1/:contentType` (List, Get, Create, Update, Delete).
- [ ] `ContentTypeController`: `/api/v1/content-types`.
- [ ] Query Parsing: Support `?page`, `?perPage`, `?sort=field:asc`, `?filter[field]=val`.
- [ ] `ContentResponseDTO`: Map Fluent model to DTO with conditional relation expansion.

### AGENT 3: ADMIN PANEL CORE
- [ ] `AdminController`: Dashboard view, content listings.
- [ ] HTMX + Leaf: Dynamic table rows, infinite scroll.
- [ ] Content Type Builder: Visual UI to add/drag fields (SortableJS).
- [ ] Content Editor: Form generator using Alpine.js and TipTap.

### AGENT 4: MEDIA SERVICE
- [ ] `LocalFileStorage`: Default local storage provider.
- [ ] `S3StorageProvider`: Using **Soto v7** for S3 uploads.
- [ ] `MediaController`: Multipart upload with dimensions/mime extraction.
- [ ] Thumbnail Job: Background worker for image resizing.

### AGENT 5: AUTH EXTENSION
- [ ] `FirebaseProvider`: Verify Firebase ID tokens.
- [ ] `LocalJWTProvider`: User DB lookup, password verify (Bcrypt), token issue.
- [ ] Admin Login Controller: POST `/admin/login` (Local or Social).
- [ ] User/Role Admin: Pages to manage users and permissions.

### AGENT 6: SEARCH INTEGRATION
- [ ] `MeilisearchService`: Wrap `meilisearch-swift` for indexing.
- [ ] Auto-sync Hooks: Index on entry Save, remove on entry Delete.
- [ ] `/api/v1/search` endpoint: Global indexed search.
- [ ] Admin Search Bar: HTMX search results dropdown in header.

### AGENT 7: WEBHOOKS & JOBS
- [ ] `WebhookDispatcher`: HMAC-SHA256 signature, idempotency check.
- [ ] `WebhookDeliveryJob`: Exponential backoff retries (Redis Queue).
- [ ] `ScheduledPublishJob`: Hourly/Minutely check for `publish_at` timestamps.
- [ ] DLQ Management: UI to view and retry failed background jobs.

### AGENT 8: INTEGRATION & TESTS
- [ ] End-to-end CRUD tests (Type -> Entry -> Index -> Search).
- [ ] Docker Full Stack Test: Postgres+Redis+Meili+Search.
- [ ] Performance Baseline: 10K entry list benchmark.

---

## WAVE 3 — Production Readiness (Weeks 7-10)

### AGENT 1: GRAPHQL API
- [ ] Schema auto-generation (Graphiti Types from JSON Schema).
- [ ] Pioneer integration (HTTP + WebSocket subscriptions).
- [ ] Respect RBAC permissions in resolvers.
- [ ] Mutation resolvers (create/update/delete).

### AGENT 2: CONTENT LIFECYCLE
- [ ] `ContentStateMachine`: Draft -> Review -> Published -> Archived.
- [ ] Status transitions enforcement in Service layer.
- [ ] Preview endpoint: GET preview with short-lived JWT token.
- [ ] Admin status controls (Publish/Unpublish buttons).

### AGENT 3: CONTENT RELATIONS
- [ ] `hasOne` / `hasMany` resolution in API.
- [ ] Circular dependency detection (Max depth 2).
- [ ] Admin relation picker (HTMX modal).

### AGENT 4: INTERNATIONALIZATION
- [ ] Locale support in API (`?locale=en-US`).
- [ ] Fallback chain (`en-GB` -> `en-US` -> `en`).
- [ ] Translation Admin UI: Side-by-side editing.

### AGENT 5: CACHING & PERFORMANCE
- [ ] `ResponseCacheMiddleware`: Redis caching of GET responses.
- [ ] Invalidation hooks: Clear cache on content update.
- [ ] ETag support (304 Not Modified).

### AGENT 6: SECURITY & OBSERVABILITY
- [ ] CORS middleware & Rate limiting (Gatekeeper).
- [ ] `swift-otel`: OpenTelemetry integration (OTLP/gRPC).
- [ ] Audit log subscriber: Write before/after diffs to DB.

### AGENT 7: ADMIN PANEL POLISH
- [ ] Dark mode (DaisyUI).
- [ ] Responsive sidebar/hamburger on mobile.
- [ ] Bulk operations (Delete/Publish selected).

---

## WAVE 4 — Ecosystem & Developer Experience (Weeks 11-14)

### AGENT 1: CLIENT SDK GENERATOR
- [ ] `SwiftSDKGenerator`: Codable models + client class generation.
- [ ] `TypeScriptGenerator`: `.d.ts` interface generation.
- [ ] Schema hash versioning: Detect staleness.

### AGENT 2: PLUGIN MARKETPLACE
- [ ] Plugin manifest (`plugin.json`) support.
- [ ] Plugin discovery & dependency ordering on boot.
- [ ] Example Plugins: SEO (sitemap), Analytics (dashboard).

### AGENT 3: STRAPI MIGRATION TOOL
- [ ] `StrapiSchemaParser`: Convert Strapi `schema.json` to SwiftCMS.
- [ ] `StrapiDataImporter`: Map entries and preserve IDs.

### AGENT 4: CONTENT VERSIONING
- [ ] `VersionService`: Content snapshots on every update.
- [ ] Admin version page: Visual diff (green/red highlighting).
- [ ] Retention & Pruning job.

### AGENT 5: WEBSOCKET & STATIC EXPORT
- [ ] WebSocket server for content event streams.
- [ ] Static export CLI: Generate JSON bundles for offline apps.

### AGENT 6: ADVANCED ADMIN FEATURES
- [ ] Content type duplication.
- [ ] Field-level permissions UI.
- [ ] Saved filter/sort presets.

### AGENT 7: DOCUMENTATION
- [ ] Comprehensive guides (Install, Config, Plugins).
- [ ] Example projects (Blog, E-commerce).
- [ ] Contributing guide.

### AGENT 8: FINAL INTEGRATION & RELEASE
- [x] Verify all doc links resolve.
- [ ] Tag v1.0.0.
- [ ] Release automation script.
