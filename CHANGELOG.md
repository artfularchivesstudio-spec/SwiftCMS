# Changelog

All notable changes to SwiftCMS will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added — Track 1: Content Experience (Complete)

**Content Editor Heuristics (1.1)**
- Smart field type detection from JSON Schema properties (type, format, maxLength, enum, x-field-type)
- 14 widget types: Rich Text, Long Text, Short Text, Email, URL, Date, DateTime, Time, Select, Integer, Number, Toggle, JSON, List, Media, Relation, File
- Builder schema markers: `format: 'richtext'`, `format: 'textarea'`, `x-field-type: 'media'`, `x-field-type: 'relation'`, `x-relation-type`

**Complex Field Types (1.2)**
- TipTap rich text editor with full toolbar (Bold, Italic, Strike, Code, H1-H3, Lists, Blockquote, Code Block, HR, Undo/Redo) and active state tracking
- EasyMDE markdown editor for long text fields with image upload support
- Single shared media picker modal (event-driven via CustomEvent dispatch)
- Relation picker with debounced API search and badge display
- JSON editor with collapsible view and live parse validation
- Array editor with dynamic add/remove items
- Flatpickr date/time picker (Date, DateTime, Time modes)
- Toggle checkbox with Enabled/Disabled state label
- Short text input with optional character counter (maxLength)
- Number input with min/max hints
- Select dropdown from enum values

**Autosave Polish (1.3)**
- Persistent status indicator: "Saving..." spinner, "Saved [time] ago" checkmark, "Unsaved changes" pulsing dot
- Cmd+S integration via `window.saveContent` global
- `beforeunload` warning prevents accidental navigation with unsaved changes
- Toast feedback on save success/failure via global `window.addToast`
- Validation error panel in sidebar with field-level error display

### Added — Admin UI Overhaul (Beyond Strapi)

**Snapshot Test Infrastructure (Phase 1)**
- swift-snapshot-testing dependency and CMSAdminTests target
- LeafSnapshotTestCase helper for cross-platform HTML snapshot testing
- Snapshot tests for login, dashboard, content types, content editor, content list
- Test fixtures with sample content types and entries

**Content Editor Fixes (Phase 2)**
- Fixed field type heuristics (longText vs shortText based on maxLength)
- JSON field type with collapsible code editor
- Media picker field with UUID-based media library selector modal
- Relation field with searchable dropdown
- Polished autosave indicator with saving/saved/unsaved states

**Power User Features (Phase 3)**
- Command palette (Cmd+K) with Fuse.js fuzzy search
- Keyboard shortcuts system (Cmd+S save, ? help, g+d/c/m vim-style nav)
- Breadcrumb navigation (client-side path parsing)
- Toast notification system with progress bars and auto-dismiss
- AdminController passes contentTypes to base template context

**Visual Polish & Micro-interactions (Phase 4)**
- Animated stat counters on dashboard (requestAnimationFrame)
- Skeleton loading states for HTMX transitions
- Enhanced card hover effects with border color shift
- Beautiful empty states for content list, media library, webhooks
- Chart.js activity chart on dashboard (replacing placeholder)
- Fixed `default function refreshSystemHealth()` JS syntax error

**Settings Page Overhaul (Phase 5)**
- Tabbed settings interface (General, API, Media, Advanced)
- UI-ready design pattern for future backend settings

**Documentation**
- Admin UI Overhaul plan (`docs/admin/ADMIN_UI_OVERHAUL_PLAN.md`)

### Added — Wave 3 Features (Planned)

**GraphQL API (Agent 1)**
- GraphQL endpoint at `/graphql` with Graphiti + Pioneer integration
- Auto-generated schema from content type definitions
- Query operations (contentEntries, contentEntry, contentTypes)
- Mutation operations (createContentEntry, updateContentEntry, deleteContentEntry)
- Subscription support for real-time updates
- GraphQL Playground at `/graphql` for interactive queries
- SDL introspection endpoint at `/graphql/schema`
- Type-safe GraphQL types in `Sources/CMSApi/GraphQL/`

**Admin UI Enhancements (Agent 3)**
- Dark mode with system preference detection and manual toggle
- Persistent theme preference saved to localStorage
- Cross-tab theme synchronization
- Smooth theme transitions (300ms)
- Dark mode overrides for all UI components

**Bulk Operations (Agent 3)**
- Multi-entry selection with checkbox interface
- Selection persistence across page navigation
- Bulk actions: publish, unpublish, archive, delete, change locale
- Real-time progress tracking during bulk operations
- Undo functionality for bulk operations (30-minute window)
- Mobile card view with selection support

**Responsive Design (Agent 3)**
- Mobile-first responsive design
- Breakpoints: xs (639px), sm (640px), md (768px), lg (1024px), xl (1280px)
- Off-canvas sidebar with hamburger menu on mobile
- Card view for content entries on mobile devices
- Touch-friendly interactions (44x44px minimum touch targets)
- Swipe gestures for mobile card actions
- Responsive tables with horizontal scroll on mobile

**Content Preview System (Agent 1)**
- Secure token-based content preview
- Short-lived preview tokens (1-hour default TTL)
- Draft content viewing without authentication
- Preview link generation from admin panel
- API endpoint for token generation
- Preview access logging and auditing
- Token revocation support

**Caching & Performance (Agent 1)**
- Redis-powered caching system
- Configurable cache TTL and memory limits
- Cache key prefixing for multi-tenant support
- Automatic cache invalidation on content changes
- Manual cache invalidation endpoints
- Cache warming support
- Cache metrics and monitoring

**Observability (Agent 1)**
- Structured JSON logging with context
- OpenTelemetry integration for distributed tracing
- Prometheus metrics endpoint at `/metrics`
- Request latency histograms
- Database query metrics
- Cache hit/miss tracking
- Business metrics (content operations, active users)
- Health check endpoints (`/healthz`, `/ready`, `/live`)
- Error tracking and aggregation

**Documentation**
- GraphQL API documentation (`docs/api/graphql.md`)
- Dark mode guide (`docs/admin/dark-mode.md`)
- Bulk operations guide (`docs/admin/bulk-operations.md`)
- Responsive design guide (`docs/admin/responsive.md`)
- Caching guide (`docs/operations/caching.md`)
- Observability guide (`docs/operations/observability.md`)
- Preview system guide (`docs/features/preview.md`)

### Changed

- Updated documentation summary with Wave 3 features

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
