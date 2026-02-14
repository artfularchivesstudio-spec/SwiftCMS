# SwiftCMS Enhancement Roadmap

**Goal:** Elevate SwiftCMS from "good open-source CMS" to a premium, developer-friendly platform that exceeds Strapi in UX and ecosystem capabilities.

**Strategy:** Execution is divided into **Parallel Tracks**. Each track focuses on a specific set of files/modules to minimize conflicts and allow multiple agents to work simultaneously.

---

## Track 1: Content Experience
*Focus: `edit.leaf`, field rendering logic*

### 1.1 Content Editor Heuristics
- [x] **Field Logic**: Update `edit.leaf` to correctly identify field types without explicit `format` properties:
    - String + No constraints → `longText` (EasyMDE Markdown).
    - String + `maxLength ≤ 500` → `shortText` (Input with char counter).
    - String + `format: richtext` → TipTap Editor with full toolbar.
    - String + `format: textarea` → EasyMDE Markdown editor.
    - String + `format: date/datetime/time` → Flatpickr Date Picker.
    - String + `format: email` → Email input.
    - String + `format: uri` → URL input.
- [x] **Builder Schema Markers**: Updated `builder.leaf` to emit `format: 'richtext'`, `format: 'textarea'`, `x-field-type: 'media'`, `x-field-type: 'relation'`, and `x-relation-type` in generated JSON schemas.

### 1.2 Complex Field Types (Editor)
- [x] **JSON Field**: Collapsible JSON editor with monospace textarea, live parse validation, inline error display.
- [x] **Media Field**: Single shared media picker modal (event-driven, no template cloning).
    - Thumbnail preview with empty state placeholder.
    - Select/Change/Remove buttons with inline media ID display.
    - Upload directly from modal with search.
- [x] **Relation Field**: Searchable relation picker with debounced API search.
    - Dropdown results fetched from `/api/v1/{relationType}`.
    - Badge showing selected relation ID with Clear button.
- [x] **Rich Text Toolbar**: Full TipTap toolbar — Bold, Italic, Strike, Code, H1-H3, Bullet/Ordered List, Blockquote, Code Block, HR, Undo/Redo. Active state tracking on selection change.
- [x] **Array Editor**: Dynamic list with add/remove items, re-render on change.
- [x] **Toggle**: Checkbox toggle with Enabled/Disabled state label.

### 1.3 Autosave Polish
- [x] **Status Bar**: Persistent status indicator in page header.
    - "Saving..." spinner.
    - "Saved [time] ago" with checkmark.
    - "Unsaved changes" with pulsing dot.
- [x] **Cmd+S Integration**: Wired `window.saveContent` for global Cmd+S shortcut from base.leaf.
- [x] **Unsaved Changes Warning**: `beforeunload` event prevents accidental navigation.
- [x] **Toast Feedback**: Save success/failure shown via toast notification system.
- [x] **Validation Error Panel**: Sidebar panel shows all validation errors with field names.

---

## Track 2: Navigation & Efficiency
*Focus: `base.leaf`, `AdminController` context*

### 2.1 Command Palette (Cmd+K)
- [ ] **Backend**: Inject `contentTypes` into `base.leaf` context via `AdminController` middleware.
- [ ] **UI/Logic**: Implement Alpine.js command palette overlay.
    - Fuzzy search using `Fuse.js`.
    - Categories: Pages, Content, Actions.
    - Keyboard navigation (Up/Down/Enter).

### 2.2 Global Keyboard Shortcuts
- [ ] **Registry**: Implement `adminApp` shortcut handler.
    - `Cmd+S` / `Ctrl+S`: Save Entry.
    - `Cmd+K` / `Ctrl+K`: Open Command Palette.
    - `?`: Show Shortcuts Help Modal.
    - `g` then `d`: Go to Dashboard.
    - `g` then `c`: Go to Content Types.

### 2.3 Navigation & Feedback
- [ ] **Breadcrumbs**: Implement client-side breadcrumb generator in `base.leaf` based on URL path segments.
- [ ] **Toasts**: Implement Alpine.js Toast Store.
    - Fixed bottom-right container.
    - Auto-dismiss with progress bar.
    - Replace all `alert()` calls with `addToast()`.

---

## Track 3: Dashboard & Visuals
*Focus: `dashboard.leaf`, `settings/index.leaf`, CSS*

### 3.1 Dashboard Overhaul
- [ ] **Counters**: Implement animated number counters for dashboard stats.
- [ ] **Charts**: Implement `Chart.js` line chart for "Entries Created".
    - Replace placeholder.
    - Source data from `CMSAdmin` (or dummy data initially).

### 3.2 UI Micro-interactions
- [ ] **Skeletons**: Add CSS for skeleton loading states (`.skeleton-pulse`).
- [ ] **Hover Effects**: Enhance Card hover states with border color shift.
- [ ] **Empty States**: Implement illustrated empty states for Content List, Media Library, and Webhooks.

### 3.3 Settings UI Redesign
- [ ] **Layout**: Refactor `settings/index.leaf` to use a Tabbed Interface.
    - Tabs: General, API, Media, Advanced.
    - "Coming Soon" states for unconnected settings.

---

## Track 4: API & Ecosystem
*Focus: New Modules (`CMSOpenAPI`, `CMSCLI`), `Package.swift`*

### 4.1 OpenAPI / Swagger Support
- [ ] **Spec Generator**: Create a `CMSOpenAPI` module.
    - Reflect over `ContentTypeDefinition` and `Vapor` routes.
    - Generate JSON OpenAPI 3.0 specification.
- [ ] **Documentation UI**: Integrate `Swagger UI` or `ReDoc` at `/api/docs`.

### 4.2 Client Generators
- [ ] **TypeScript SDK**: Generate fully typed TS client for the CMS API.
- [ ] **Swift SDK**: Generate a semantic Swift client (macros or source gen).

### 4.3 Model Context Protocol (MCP)
- [ ] **MCP Server**: Implement an MCP Server endpoint.
    - **Resource**: `cms://content/{type}` (Read content).
    - **Tool**: `create_content_type` (Schema management).
    - **Tool**: `create_entry` (Content creation).
    - Allow external AI agents (like Claude/Gateway) to manage the CMS directly.

### 4.4 CLI Scaffolding
- [ ] **Generators**: Add commands to `CMSCLI`.
    - `swift run cms generate type <name>`: Scaffolds a content type struct.
    - `swift run cms generate plugin <name>`: Scaffolds a new module structure.

---

## Track 5: Reliability & Testing
*Focus: `Tests/`, `Package.swift`*

### 5.1 Snapshot Test Infrastructure
- [ ] **Dependency**: Add `swift-snapshot-testing` to `Package.swift`.
- [ ] **Target**: Create `CMSAdminTests` target with `Leaf` and `SnapshotTesting` dependencies.
- [ ] **Helper**: Implement `LeafSnapshotTestCase` to render Leaf templates to HTML strings (cross-platform).
- [ ] **Helper (macOS)**: Implement `WKWebView` snapshot strategy for pixel-perfect visual regression tests.
- [ ] **Baselines**: Generate initial snapshots for Login, Dashboard, and Empty States.
