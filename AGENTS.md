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
  - JSON Schema generation from field definitions
  - Validation service (kylef/JSONSchema.swift)
  - Content type CRUD service
  - Field type registry (14 field types)
  - Relation resolution service
  - Schema change event dispatch
- **Status:** PENDING

### Agent 2: REST API Controllers
- **Owns:** `Sources/CMSApi/REST/`
- **Deliverables:**
  - `DynamicContentController` (`/:contentType` with full CRUD)
  - `ContentTypeController`
  - Query params: pagination, filtering, sorting, field selection, populate
  - API versioning (`/api/v1/`)
- **Status:** PENDING

### Agent 3: Admin Panel Core
- **Owns:** `Sources/CMSAdmin/`, `Resources/Views/`
- **Deliverables:**
  - Leaf base layout (sidebar, Tailwind + DaisyUI, HTMX)
  - Dashboard, content type builder (Alpine.js + SortableJS)
  - Content listing + edit forms (dynamic from JSON Schema)
  - Session auth for admin
- **Status:** PENDING

### Agent 4: Media Library
- **Owns:** `Sources/CMSMedia/`
- **Deliverables:**
  - `FileStorageProvider` protocol (local + S3 via Soto)
  - Multipart upload, metadata extraction
  - Thumbnail job (Vapor Queues)
  - Media browser admin page
  - Signed URLs
- **Status:** PENDING

### Agent 5: Firebase + Local Auth
- **Owns:** `Sources/CMSAuth/Firebase/`, `Sources/CMSAuth/Local/`
- **Deliverables:**
  - FirebaseProvider full impl (X.509 cert, JWT verify, custom claims)
  - LocalJWTProvider impl (self-issued tokens, bcrypt passwords)
  - Admin login page with provider selection
  - User management admin pages
- **Status:** PENDING

### Agent 6: Search Integration
- **Owns:** `Sources/CMSSearch/`
- **Deliverables:**
  - Meilisearch wrapper
  - Auto-index on schema create via hooks
  - Content sync on CRUD via hooks
  - Search endpoint (`/api/v1/search`)
  - Admin global search (HTMX)
- **Status:** PENDING

### Agent 7: Webhooks + Background Jobs
- **Owns:** `Sources/CMSEvents/` (webhook dispatcher), `Sources/CMSJobs/`
- **Deliverables:**
  - WebhookDispatcher (HMAC-SHA256 signed)
  - Exponential backoff retry (5 attempts over ~30 min)
  - Dead Letter Queue processing
  - Scheduled publishing job (every 60s)
  - Content version pruning job
  - Audit log cleanup job
- **Status:** PENDING

### Agent 8: Integration + Tests
- **Owns:** `Tests/`
- **Deliverables:**
  - Content CRUD integration tests
  - Auth flow integration tests
  - Media upload tests
  - Search sync tests
  - Webhook delivery tests
  - Merge all branches, full test suite green
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
