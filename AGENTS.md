# AGENTS.md — SwiftCMS Multi-Agent Development Strategy

8 parallel agents x 4 waves. Each agent has strict directory ownership. Cross-module requests go in `HANDOFF.md`.

---

## Wave 1 — Foundation & Core Infrastructure (Weeks 1-3)

**Goal:** Server boots, connects PostgreSQL + Redis, authenticates Auth0 JWT, `/healthz` returns 200, module system + EventBus work. **Minimum Swift Version: 6.1+**.

**Exit Criteria:** Server boots -> connects PostgreSQL + Redis -> authenticates Auth0 JWT -> 200 on /healthz -> module system registers test module -> EventBus publishes + receives test event -> Docker build passes -> CI green -> Swift 6 strict concurrency verified.

### Agent 1: Project Bootstrap
- **Owns:** `Sources/App/`, `Package.swift`, `docker-compose.yml`, `.env.example`, `Makefile`
- **Deliverables:**
  - Package.swift with ALL deps (Vapor, Fluent, jwt-kit v5, Leaf, Redis, Queues, Graphiti, Pioneer, JSONSchema, Soto, ArgumentParser, VaporHX)
  - `entrypoint.swift` — @main entry point
  - `configure.swift` — .env loading, Fluent (PostgreSQL + SQLite fallback), Redis, Leaf, sessions, migrations, routes
  - `routes.swift` — `/healthz`, `/ready`, `/startup`, `/api/v1/`, `/admin/`
  - `docker-compose.yml` — postgres:16, redis:7, meilisearch:latest
  - `.env.example` and `Makefile`
- **Status:** COMPLETE

### Agent 2: Core Module System
- **Owns:** `Sources/CMSCore/`
- **Deliverables:**
  - `CmsModule.swift` — Protocol with name, priority, register/boot/shutdown lifecycle
  - `ModuleManager.swift` — Module registration, priority boot ordering
  - `HookRegistry.swift` — Generic typed hook system
  - `Application+CMS.swift` — `app.cms.modules`, `app.cms.hooks`, `app.cms.eventBus`
  - `Request+CMS.swift` — Request-level CMS extensions
  - Tests in `Tests/CMSCoreTests/`
- **Status:** COMPLETE

### Agent 3: Database Models & Migrations
- **Owns:** `Sources/CMSSchema/Models/`, `Sources/CMSSchema/Migrations/`
- **Deliverables:**
  - Models: User, Role, Permission, ApiKey, MediaFile, ContentTypeDefinition, ContentEntry, ContentVersion, Webhook, WebhookDelivery, DeadLetterEntry, AuditLog
  - Migrations with `prepare()` and `revert()` for all tables
  - GIN + B-tree indexes on content_entries
  - Seed migration for default roles + admin user
- **Status:** COMPLETE

### Agent 4: Auth0 Provider
- **Owns:** `Sources/CMSAuth/`
- **Deliverables:**
  - `AuthProvider` protocol
  - `Auth0Provider` — JWKS + jwt-kit JWT verification
  - `FirebaseProvider` stub
  - `LocalJWTProvider` stub
  - RBAC middleware, session auth middleware, API key middleware
- **Status:** COMPLETE

### Agent 5: Shared DTOs
- **Owns:** `Sources/CMSObjects/`
- **Deliverables:**
  - `AnyCodableValue` — JSONB representation enum with custom Codable
  - `ContentTypeDefinitionDTO`, `ContentEntryDTO`, `UserDTO`, `MediaFileDTO`
  - `PaginationWrapper<T>` with `PaginationMeta`
  - `ApiError` with structured error codes
- **Status:** COMPLETE

### Agent 6: EventBus + CLI Foundation
- **Owns:** `Sources/CMSEvents/`, `Sources/CMSCLI/`
- **Deliverables:**
  - `EventBus` protocol
  - `InProcessEventBus` implementation
  - `RedisStreamsEventBus` implementation
  - Core event types (content.created/updated/deleted/published, schema.changed, user.login)
  - `CmsContext` type
  - CLI foundation with ArgumentParser
- **Status:** COMPLETE

### Agent 7: Docker & CI/CD
- **Owns:** `Dockerfile`, `k8s/`, `.github/workflows/`
- **Deliverables:**
  - Multi-stage Dockerfile (~200MB runtime image)
  - Kubernetes manifests (Deployment, Service, HPA, ConfigMap, Secret)
  - GitHub Actions CI (Swift Linux build + test)
  - Health check endpoints
- **Status:** COMPLETE

### Agent 8: Integration + Tests
- **Owns:** `Tests/`
- **Deliverables:**
  - XCTest infrastructure, test DB config
  - Unit tests per module
  - Integration tests (boot + health + auth)
  - Test fixtures/factories
  - Merge all branches, validate full build
- **Status:** COMPLETE (45/45 tests passing)

---

## Wave 2 — Content Engine & API Layer (Weeks 4-6)

**Goal:** SwiftCMS becomes a functional headless CMS. Content type engine, REST API, admin panel, media, search, webhooks, and jobs.

**Exit Criteria:** Content types created via admin -> entries CRUD via REST -> search returns results -> webhooks fire on content changes -> media uploads to S3 -> admin panel functional -> all auth providers working.

### Agent 1: Content Type Engine
- **Owns:** `Sources/CMSSchema/Engine/`
- **Deliverables:**
  - `JSONSchema.swift` — Schema generation from field definitions (14 field types).
  - `SchemaValidator.swift` — Core validation logic (using kylef/JSONSchema.swift).
  - `FieldTypeRegistry.swift` — Registration system for dynamic field types.
  - `RelationResolver.swift` — Service to resolve UUIDs to nested objects.
  - `PreviewController.swift` — Content API preview routes.
- **Status:** PENDING

### Agent 2: REST API Controllers
- **Owns:** `Sources/CMSApi/REST/`
- **Deliverables:**
  - `DynamicContentController` — `/:contentType` CRUD with validation.
  - `ContentTypeController` — Meta-API for type definitions.
  - Query parsing: `?page`, `?perPage`, `?status`, `?locale`, `?sort`, `?filter[field]=val`.
  - Content versioning endpoints: `/:id/versions`, `/:id/versions/:v/restore`.
- **Status:** PENDING

### Agent 3: Admin Panel Core
- **Owns:** `Sources/CMSAdmin/`, `Resources/Views/admin/`
- **Deliverables:**
  - Leaf base layout: Sidebar, Tailwind, DaisyUI, HTMX, Alpine.js.
  - Content type builder: Visual UI for defining fields and validation.
  - Content editor: Dynamic forms generated from JSON Schema.
  - Media library integration: Visual browser and uploader.
- **Status:** PENDING

### Agent 4: Media Service
- **Owns:** `Sources/CMSMedia/`
- **Deliverables:**
  - `S3StorageProvider` — Full Soto v7 implementation.
  - `MediaController` — Upload/List/Delete API.
  - Multipart handling with file size/type validation.
  - Metadata extraction (dimensions, MIME, hash).
- **Status:** PENDING

### Agent 5: Auth Extension
- **Owns:** `Sources/CMSAuth/Firebase/`, `Sources/CMSAuth/Local/`
- **Deliverables:**
  - `FirebaseProvider` — Full certificate-based verification.
  - `LocalJWTProvider` — Password-based login and token issuance.
  - Admin login pages and user profile management.
  - Seed scripts for default roles/permissions.
- **Status:** PENDING

### Agent 6: Search Integration
- **Owns:** `Sources/CMSSearch/`
- **Deliverables:**
  - Meilisearch client integration.
  - Auto-sync hooks: Update index on content save/delete.
  - `/api/v1/search` endpoint.
  - Admin global search interface.
- **Status:** PENDING

### Agent 7: Webhooks & Jobs
- **Owns:** `Sources/CMSEvents/`, `Sources/CMSJobs/`
- **Deliverables:**
  - `WebhookDispatcher` — HMAC-SHA256 signing and idempotency checks.
  - `WebhookDeliveryJob` — Queue-based retries with exponential backoff.
  - `ScheduledPublishJob` — Publish content at specific timestamps.
  - `DeadLetterEntry` management UI.
- **Status:** PENDING

### Agent 8: Integration & Tests
- **Owns:** `Tests/`, final merge coordination.
- **Deliverables:**
  - End-to-end Content CRUD tests.
  - Full stack Docker verification (Postgres+Redis+Search).
  - Performance baseline benchmarks (<200ms list target).
  - Wave 2 tag and merge.
- **Status:** PENDING

---

## Wave 3 — Advanced Features & Polish (Weeks 7-9)

**Goal:** GraphQL, real-time, i18n, content lifecycle, SDK generation, advanced admin, load testing.

### Agent 1: GraphQL API
- **Owns:** `Sources/CMSApi/GraphQL/`
- **Deliverables:** Graphiti schema, Pioneer server, subscriptions, GraphiQL IDE

### Agent 2: Real-Time & WebSocket
- **Owns:** `Sources/CMSApi/WebSocket/`
- **Deliverables:** WebSocket endpoint, content change broadcasts, presence, auth

### Agent 3: Content Lifecycle
- **Owns:** `Sources/CMSSchema/Workflow/`
- **Deliverables:** State machine (Draft->Review->Published->Archived->Deleted), scheduled publish/unpublish, version history with diff

### Agent 4: Internationalization
- **Owns:** `Sources/CMSSchema/I18n/`
- **Deliverables:** Locale service, per-locale content entries, locale-aware API, admin locale switcher

### Agent 5: Client SDK Generator
- **Owns:** `ClientSDK/`, `Sources/CMSCLI/` (codegen commands)
- **Deliverables:** `cms generate-sdk swift`, typed Codable structs, async API client, schema hash versioning

### Agent 6: Advanced Admin
- **Owns:** `Sources/CMSAdmin/` (extended)
- **Deliverables:** TipTap rich text, media picker, relation picker, version diff viewer, DLQ management, activity feed

### Agent 7: Observability
- **Owns:** Infrastructure layer
- **Deliverables:** swift-otel integration, structured logging (swift-log + Loki), Gatekeeper rate limiting, metrics endpoints

### Agent 8: Load Testing + Integration
- **Owns:** `Tests/`
- **Deliverables:** Load test suite (1K+ req/sec target), comparative benchmarks vs Strapi, full regression suite

---

## Wave 4 — Production Hardening & Ecosystem (Weeks 10-12)

**Goal:** Production-ready v1.0.0. Multi-tenancy, plugin ecosystem, static export, Strapi import, security hardening.

### Agent 1: CLI Codegen & Static Export
- **Owns:** `Sources/CMSCLI/`
- **Deliverables:** `cms export` static JSON bundles, incremental export, ExportManifest.json

### Agent 2: Plugin Ecosystem
- **Owns:** `Modules/`
- **Deliverables:** Plugin discovery, example plugins (SEO, Analytics), plugin documentation

### Agent 3: Migration Tools
- **Owns:** `Sources/CMSCLI/` (import commands)
- **Deliverables:** Strapi JSON import, WordPress XML import, CSV import

### Agent 4: Multi-Tenancy
- **Owns:** Cross-cutting
- **Deliverables:** TenantContext middleware, row-level isolation, tenant-scoped queries

### Agent 5: Security Hardening
- **Owns:** Cross-cutting
- **Deliverables:** OWASP top 10 audit, CSP headers, input sanitization, dependency audit

### Agent 6: Performance Optimization
- **Owns:** Cross-cutting
- **Deliverables:** Redis caching layer, ETag support, query optimization, connection pooling tuning

### Agent 7: Production Docker & K8s
- **Owns:** `Dockerfile`, `k8s/`
- **Deliverables:** Production-optimized image, HPA tuning, health probe config, secrets management

### Agent 8: Final Integration + Release
- **Owns:** `Tests/`, release
- **Deliverables:** Full regression, release notes, v1.0.0 tag, documentation review
