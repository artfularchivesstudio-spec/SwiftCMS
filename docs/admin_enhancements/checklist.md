# SwiftCMS Admin Enhancement Checklist (Parallel Tracks)

Target: Build a premium Admin UI that exceeds Strapi in UX and developer experience.
Strategy: Execute these **parallel tracks** concurrently. Each track focuses on distinct file sets to minimize conflicts.

---

## Track 1: Content Experience
**Focus**: `edit.leaf`, field rendering logic.
**Dependencies**: None.

☐
Content Editor Heuristics
Update `edit.leaf` logic. String + No constraints → `longText` (Textarea). String + `maxLength: 255` → `shortText` (Input). String + `format: richtext` → TipTap.

☐
Complex Field Types (Editor)
Implement collapsible JSON code editor. Implement Media Picker modal for `format: uuid`. Implement Searchable Select for Relation fields.

☐
Autosave Polish
Replace hidden toggle with persistent status indicator ("Saving...", "Saved [time] ago", "Unsaved changes").

EXIT CRITERIA: Editor handles complex types correctly → Autosave reliability confirmed.

---

## Track 2: Navigation & Efficiency ✅ COMPLETED
**Focus**: `base.leaf`, `AdminController` context.
**Dependencies**: Minimal (AdminController context injection).
**Status**: COMPLETE - All features implemented and tested

✅
Command Palette (Cmd+K)
Inject content types into base context. Implement Alpine.js overlay with fuzzy search for navigation and actions.
**Implementation**: Fuse.js integration, dynamic content type injection, recent items tracking

✅
Global Keyboard Shortcuts
Implement shortcuts: `Cmd+S` (Save), `Cmd+K` (Palette), `?` (Help), `g` then `d`/`c`/`m` (Go to Dashboard/Content/Media).
**Implementation**: Save dispatches `cms:save` event, ? opens help modal, Vim-style g+key navigation

✅
Navigation & Feedback
Client-side breadcrumbs based on URL path. Alpine.js Toast system replacing `alert()` calls.
**Implementation**: Dynamic breadcrumb generation with Alpine.js, Toast integration with HTMX events

EXIT CRITERIA: ✅ PALETTE WORKS | ✅ SHORTCUTS TRIGGER | ✅ TOASTS APPEAR | ✅ BREADCRUMBS UPDATE

---

## Track 3: Dashboard & Visuals ✅ COMPLETED
**Focus**: `dashboard.leaf`, `settings/index.leaf`, CSS.
**Dependencies**: None.
**Status**: COMPLETE - All features implemented

✅
Dashboard Overhaul
Animated number counters (Alpine.js). Chart.js line chart with dark mode support for "Entries Created" and "API Requests".
**Implementation**: 800ms counter animations, responsive Chart.js with gradient fills

✅
UI Micro-interactions
CSS skeleton loading states (`.skeleton-pulse` animation). Enhanced card hover effects (border color shift). Illustrated empty states for empty lists.
**Implementation**: Empty states with SVG illustrations and action buttons for Recent Entries and Recent Media

✅
Settings UI Redesign
Refactor `settings/index.leaf` to use a Tabbed Interface (General, API, Media, Advanced).
**Implementation**: Alpine.js tab switching with smooth transitions, 4 distinct settings sections

EXIT CRITERIA: ✅ ANIMATED COUNTERS | ✅ LIVE CHART | ✅ EMPTY STATES | ✅ TABBED NAVIGATION

---

## Track 4: API & Ecosystem
**Focus**: New Modules (`CMSOpenAPI`, `CMSCLI`), `Package.swift`.
**Dependencies**: `Package.swift` updates.

☐
OpenAPI / Swagger Support
Create `CMSOpenAPI` module. Generate JSON spec from routes/models. Integrate Swagger UI at `/api/docs`.

☐
Client Generators
Generate TypeScript SDK for frontend consumption. Generate Swift SDK for iOS apps.

☐
Model Context Protocol (MCP)
Implement MCP Server endpoint (`cms://`) allowing AI agents to read content and manage schema.

☐
CLI Scaffolding
Add `swift run cms generate type` and `plugin` commands to CLI.

EXIT CRITERIA: OpenAPI spec validates → SDKs generate correctly → MCP server responds to agent queries.

---

## Track 5: Reliability & Testing
**Focus**: `Tests/`, `Package.swift`.
**Dependencies**: `Package.swift` updates.

☐
Snapshot Test Infrastructure
Add `swift-snapshot-testing` dependency. Create `CMSAdminTests` target. Implement `LeafSnapshotTestCase` & `WKWebView` helper. Generate baselines for Login/Dashboard.

EXIT CRITERIA: Tests pass → Baselines generated.
