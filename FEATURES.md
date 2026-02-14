# FEATURES.md — SwiftCMS Feature Inventory

Status key: DONE | IN PROGRESS | PENDING

---

## 1. Core Architecture (6-Layer)

| Feature | Status | Module | Wave |
|---|---|---|---|
| Client Layer (iOS/macOS/web) | PENDING | — | W3-W4 |
| Admin Panel Layer (HTMX/Leaf) | IN PROGRESS | CMSAdmin | W1-W2 |
| API Layer (REST + GraphQL + WebSocket) | IN PROGRESS | CMSApi | W2-W3 |
| Service Layer (Content, Media, Auth, Search) | IN PROGRESS | Multiple | W2-W3 |
| Event & Job Layer (Webhooks, Tasks) | IN PROGRESS | CMSEvents, CMSJobs | W2-W3 |
| Core Engine (Schema, Logic, Hooks) | DONE | CMSCore, CMSSchema | W1 |
| Data Layer (DB, Cache, Search, S3) | DONE | CMSSchema, App | W1 |
| Infrastructure (Docker, K8s, CI/CD) | DONE | App, Docker | W1 |

## 2. Content Engine

| Feature | Status | Module | Wave |
|---|---|---|---|
| Runtime content type definitions (JSONB + JSON Schema) | DONE (models) | CMSSchema | W1 |
| JSON Schema validation (kylef/JSONSchema.swift) | PENDING (engine) | CMSSchema/Engine | W2 |
| 14 field types (text, richtext, number, boolean, date, media, relation, json, enum, email, password, uid, component, dynamiczone) | PENDING | CMSSchema/Engine | W2 |
| Field type registry | PENDING | CMSSchema/Engine | W2 |
| Relation resolution (oneToOne, oneToMany, manyToMany) | PENDING | CMSSchema/Relations | W2 |
| Content lifecycle state machine (Draft -> Review -> Published -> Archived -> Deleted) | DONE (model) | CMSSchema/Workflow | W1 |
| Scheduled publishing (publish_at / unpublish_at) | PENDING | CMSSchema/Workflow, CMSJobs | W2-W3 |
| Version history with diff | DONE (model) | CMSSchema/Versioning | W1 |
| Version restore | PENDING | CMSSchema/Versioning | W3 |
| Version retention & pruning | PENDING | CMSJobs | W2 |
| Audit logging (append-only, before/after diff) | DONE (model) | CMSSchema | W1 |
| Audit log CSV export | PENDING | CMSAdmin | W3 |

## 3. REST API

| Feature | Status | Module | Wave |
|---|---|---|---|
| Dynamic content CRUD (`/api/v1/:contentType`) | PENDING | CMSApi/REST | W2 |
| Content type management API | PENDING | CMSApi/REST | W2 |
| Pagination (page, perPage, total) | PENDING | CMSApi/REST | W2 |
| Filtering (field-level query params) | PENDING | CMSApi/REST | W2 |
| Sorting | PENDING | CMSApi/REST | W2 |
| Field selection (sparse fieldsets) | PENDING | CMSApi/REST | W2 |
| Relation population (populate param) | PENDING | CMSApi/REST | W2 |
| API versioning (/api/v1/) | DONE (route group) | App | W1 |

## 4. GraphQL API

| Feature | Status | Module | Wave |
|---|---|---|---|
| Graphiti schema generation | PENDING | CMSApi/GraphQL | W3 |
| Pioneer server integration | PENDING | CMSApi/GraphQL | W3 |
| GraphQL subscriptions (real-time) | PENDING | CMSApi/GraphQL | W3 |
| GraphiQL IDE endpoint | PENDING | CMSApi/GraphQL | W3 |

## 5. Real-Time

| Feature | Status | Module | Wave |
|---|---|---|---|
| WebSocket endpoint (`/ws`) | DONE (basic) | App/WebSocket | W1 |
| Content change broadcasts | PENDING | CMSApi/WebSocket | W3 |
| Presence tracking | PENDING | CMSApi/WebSocket | W3 |
| WebSocket authentication | DONE (AuthProviderKey) | App/WebSocket | W1 |

## 6. Authentication & Authorization

| Feature | Status | Module | Wave |
|---|---|---|---|
| AuthProvider protocol (pluggable) | DONE | CMSAuth | W1 |
| Auth0Provider (JWKS + jwt-kit) | DONE | CMSAuth | W1 |
| FirebaseProvider (X.509 cert, JWT verify) | PENDING (stub exists) | CMSAuth | W2 |
| LocalJWTProvider (self-issued, bcrypt) | PENDING (stub exists) | CMSAuth | W2 |
| JWT bearer token auth (API) | DONE | CMSAuth | W1 |
| Session-based auth (admin panel) | DONE (configured) | App | W1 |
| API key auth (machine-to-machine) | DONE (model) | CMSAuth, CMSSchema | W1 |
| RBAC middleware | DONE | CMSAuth | W1 |
| 4 default roles (Super Admin, Editor, Author, Public) | DONE (model) | CMSSchema | W1 |
| Permission model (resource:action per content type) | DONE (model) | CMSSchema | W1 |

## 7. Admin Panel

| Feature | Status | Module | Wave |
|---|---|---|---|
| Leaf + HTMX base layout | DONE (templates) | CMSAdmin, Resources/Views | W1 |
| Tailwind CSS + DaisyUI styling | DONE (templates) | Resources/Views | W1 |
| Dashboard | DONE (template) | CMSAdmin | W1 |
| Content type builder (Alpine.js + SortableJS) | DONE | CMSAdmin | W2 |
| Dynamic content edit forms | DONE | CMSAdmin | W2 |
| Content listing with search | PENDING | CMSAdmin | W2 |
| Media browser (grid/list/upload) | PENDING | CMSAdmin | W2 |
| User management pages | PENDING | CMSAdmin | W2 |
| Role & permission management | PENDING | CMSAdmin | W2 |
| Plugin admin pages | DONE (templates for SEO, Analytics) | Resources/Views | W1 |
| TipTap rich text editor | DONE | CMSAdmin | W3 |
| Version diff viewer | PENDING | CMSAdmin | W3 |
| DLQ management page | DONE (template) | Resources/Views | W1 |
| Activity feed | PENDING | CMSAdmin | W3 |
| Webhook management | DONE (template) | Resources/Views | W1 |
| Settings pages | DONE (templates) | Resources/Views | W1 |

## 8. Media Library

| Feature | Status | Module | Wave |
|---|---|---|---|
| FileStorageProvider protocol | DONE | CMSMedia | W1 |
| Local filesystem driver | DONE | CMSMedia | W1 |
| S3 driver (Soto v7) | DONE | CMSMedia | W1 |
| Multipart upload | PENDING | CMSMedia | W2 |
| Metadata extraction | PENDING | CMSMedia | W2 |
| Thumbnail generation (Vapor Queues) | PENDING | CMSMedia | W2 |
| Signed URLs | PENDING | CMSMedia | W2 |
| Media browser admin page | PENDING | CMSAdmin | W2 |

## 9. Search

| Feature | Status | Module | Wave |
|---|---|---|---|
| Meilisearch wrapper | DONE (basic) | CMSSearch | W1 |
| Auto-index on schema create (hooks) | PENDING | CMSSearch | W2 |
| Content sync on CRUD (hooks) | PENDING | CMSSearch | W2 |
| Search API endpoint (`/api/v1/search`) | PENDING | CMSSearch | W2 |
| Configurable searchable fields per type | PENDING | CMSSearch | W2 |
| Admin global search (HTMX) | PENDING | CMSAdmin | W2 |

## 10. Events & Webhooks

| Feature | Status | Module | Wave |
|---|---|---|---|
| EventBus protocol | DONE | CMSEvents | W1 |
| InProcessEventBus | DONE | CMSEvents | W1 |
| RedisStreamsEventBus | DONE | CMSEvents | W1 |
| Core event types (content/schema/user) | DONE | CMSEvents | W1 |
| WebhookDispatcher (HMAC-SHA256 signed) | PENDING | CMSEvents | W2 |
| Exponential backoff retry (5 attempts) | PENDING | CMSJobs | W2 |
| Dead Letter Queue | DONE (model) | CMSSchema | W1 |
| DLQ processing & management | PENDING | CMSJobs, CMSAdmin | W2 |
| Idempotency key enforcement | PENDING | CMSEvents | W2 |
| Event replay (Redis Streams) | PENDING | CMSEvents | W3 |

## 11. Background Jobs

| Feature | Status | Module | Wave |
|---|---|---|---|
| Vapor Queues + Redis driver | DONE (configured) | App | W1 |
| Scheduled publishing job | PENDING | CMSJobs | W2 |
| Version pruning job | PENDING | CMSJobs | W2 |
| Audit log cleanup job | PENDING | CMSJobs | W2 |
| Webhook delivery job | PENDING | CMSJobs | W2 |
| Thumbnail generation job | PENDING | CMSJobs | W2 |

## 12. Plugin System

| Feature | Status | Module | Wave |
|---|---|---|---|
| CMSModule protocol lifecycle | DONE | CMSCore | W1 |
| Plugin discovery (directory scanning) | DONE | CMSCore/Plugins | W1 |
| Route registration (namespaced) | PENDING | CMSCore | W2 |
| Event hook registration (type-safe) | PENDING | CMSCore | W2 |
| Admin UI extension (nav items, widgets, field types) | PENDING | CMSAdmin | W3 |
| SEO plugin (example) | DONE (basic) | Modules/SEO | W1 |
| Analytics plugin (example) | DONE (basic) | Modules/Analytics | W1 |

## 13. CLI Tools

| Feature | Status | Module | Wave |
|---|---|---|---|
| ArgumentParser foundation | DONE | CMSCLI | W1 |
| Scaffold generators | DONE (basic) | CMSCLI | W1 |
| `cms generate-sdk swift` | PENDING | CMSCLI | W3 |
| `cms generate-sdk typescript` | PENDING | CMSCLI | W3 |
| `cms export` (static JSON bundles) | PENDING | CMSCLI | W4 |
| Strapi JSON import | PENDING | CMSCLI | W4 |
| WordPress XML import | PENDING | CMSCLI | W4 |

## 14. Client SDK

| Feature | Status | Module | Wave |
|---|---|---|---|
| Swift client SDK auto-generation | PENDING | ClientSDK | W3 |
| Typed Codable structs from content types | PENDING | ClientSDK | W3 |
| Async URLSession API client | PENDING | ClientSDK | W3 |
| Schema hash versioning | PENDING | ClientSDK | W3 |
| TypeScript type definitions | PENDING | CMSCLI | W3 |

## 15. Internationalization

| Feature | Status | Module | Wave |
|---|---|---|---|
| Locale service | DONE (basic) | CMSSchema/I18n | W1 |
| Per-locale content entries | PENDING | CMSSchema/I18n | W3 |
| Locale-aware API responses | PENDING | CMSApi | W3 |
| Admin locale switcher | PENDING | CMSAdmin | W3 |

## 16. Multi-Tenancy

| Feature | Status | Module | Wave |
|---|---|---|---|
| tenant_id on all models | DONE (columns exist) | CMSSchema | W1 |
| TenantContext middleware | PENDING | App | W4 |
| Row-level tenant isolation | PENDING | Cross-cutting | W4 |
| Tenant-scoped query modifier | PENDING | Cross-cutting | W4 |

## 17. Observability & Performance

| Feature | Status | Module | Wave |
|---|---|---|---|
| Health checks (/healthz, /ready, /startup) | DONE | App | W1 |
| swift-otel OpenTelemetry integration | PENDING | Infrastructure | W3 |
| Structured logging (swift-log) | PENDING | Infrastructure | W3 |
| Gatekeeper rate limiting | PENDING | Infrastructure | W3 |
| Redis caching layer | PENDING | Cross-cutting | W4 |
| ETag conditional responses | PENDING | CMSApi | W4 |
| Connection pool tuning (PgBouncer) | PENDING | Infrastructure | W4 |

## 18. Performance Targets (vs Strapi/Node.js)

| Metric | SwiftCMS Target (p99) | Strapi Typical | Advantage |
|---|---|---|---|
| Content read (cached) | <50ms | 150-300ms | 3-6x faster |
| Content read (uncached, 10K) | <200ms | 500-1,200ms | 3-6x faster |
| Content creation + validation | <100ms | 200-500ms | 2-5x faster |
| GraphQL query (10 fields) | <80ms | 150-400ms | 2-5x faster |
| Memory per instance | 50-100MB RSS | 150-400MB RSS | 3-4x leaner |
| Cold start (container) | ~200ms | 2-5s | 10-25x faster |
| Sustained throughput | >1,000 req/sec | 200-400 req/sec | 3-5x higher |
| Docker image size | ~200MB | ~800MB-1.2GB | 4-6x smaller |

## 19. DevOps & Deployment

| Feature | Status | Module | Wave |
|---|---|---|---|
| Multi-stage Dockerfile | DONE | Docker | W1 |
| docker-compose.yml (PG + Redis + Meili) | DONE | Docker | W1 |
| Kubernetes manifests | DONE | k8s/ | W1 |
| GitHub Actions CI | DONE | .github/workflows | W1 |
| HPA auto-scaling | DONE (manifest) | k8s/ | W1 |
| Production-optimized image | PENDING | Docker | W4 |
| Secrets management | PENDING | k8s | W4 |
