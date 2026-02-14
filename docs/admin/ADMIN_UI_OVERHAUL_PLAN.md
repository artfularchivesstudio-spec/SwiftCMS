# Admin UI Overhaul — Beyond Strapi

## Context

The admin panel is already at **~7/10 polish** — dark mode, dynamic form builder with 14 field types, SortableJS drag-drop, HTMX search, mobile responsive layout, and glassmorphism login are all implemented. The goal is to push from "good open-source CMS" to "this feels better than Strapi" by adding power-user features, micro-interactions, missing editor capabilities, and visual snapshot tests. Nearly all changes are frontend Leaf templates + a new test target. **One small Swift change:** AdminController needs to pass `contentTypes` to the base template context so the command palette and sidebar can list content types dynamically.

### What Gemini Flagged (and current status)
| Gemini Item | Status |
|---|---|
| Dark mode toggle | Done |
| Mobile hamburger menu | Done |
| CDN links (SortableJS, TipTap) | Done |
| Animated gradient login + glassmorphism | Done |
| Chart.js on dashboard | **Placeholder only** — commented-out code at `dashboard.leaf:304-326` |
| Content editor field heuristics (longText vs shortText) | **Needs refinement** — current logic uses `format` property, not `maxLength` heuristic |
| JSON field type (collapsible code editor) | **Missing** — falls through to default text input |
| Media field (UUID-based media picker modal) | **Partial** — has file upload but no media library selector |
| Relation field (searchable select) | **Missing** — no relation support |
| Snapshot tests with swift-snapshot-testing | **Not started** |

---

## Plan Overview

### Phase 1: Snapshot Test Infrastructure (Foundation)
### Phase 2: Content Editor Fixes (Gemini's gaps)
### Phase 3: Power User Features (Strapi differentiators)
### Phase 4: Visual Polish & Micro-interactions
### Phase 5: Dashboard Chart.js & Settings Overhaul

---

## Phase 1: Snapshot Test Infrastructure

**Why first:** Tests let us verify every subsequent change doesn't regress. Screenshots serve as living documentation.

### 1A. Add swift-snapshot-testing dependency

**File:** `Package.swift`

```swift
// Add to dependencies array:
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),

// Add new test target:
.testTarget(
    name: "CMSAdminTests",
    dependencies: [
        .product(name: "XCTVapor", package: "vapor"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        .product(name: "Leaf", package: "leaf"),
        "CMSAdmin",
        "CMSSchema",
        "CMSObjects",
    ],
    resources: [
        .copy("__Snapshots__"),
    ]
),
```

### 1B. Create test helper for Leaf rendering

**New file:** `Tests/CMSAdminTests/LeafSnapshotTestCase.swift`

Approach: Use Vapor's `Application` in testing mode to render Leaf templates to HTML strings. Then snapshot the HTML string itself (not pixel screenshots — those require WebKit/macOS-only). This gives us:
- Cross-platform compatibility (Linux CI)
- Fast execution
- Detects structural/class changes in templates

```swift
// Pseudocode structure:
import XCTVapor
import Leaf
@testable import CMSAdmin
import SnapshotTesting

class LeafSnapshotTestCase: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        app.views.use(.leaf)
        // Configure Leaf source to point at Resources/Views/
    }

    func renderTemplate(_ name: String, context: [String: LeafData]) async throws -> String {
        // Use LeafRenderer to render template to string
    }
}
```

### 1C. Snapshot test cases

**New file:** `Tests/CMSAdminTests/AdminSnapshotTests.swift`

Test cases with fixture data:
1. **Login page** — render `admin/login` with `title: "Login"`, `error: nil`
2. **Login page (error state)** — render with `error: "invalid"`
3. **Dashboard** — render with `typeCount: 5`, `entryCount: 42`, `recentEntries: [fixtures]`
4. **Content types list** — render with 3 sample content types
5. **Content types empty state** — render with empty array
6. **Content editor (new)** — render with a blog post content type (string, textarea, boolean, number fields)
7. **Content editor (edit)** — render with existing entry data populated
8. **Content list** — render with mixed status entries

Each test uses two snapshot strategies:

**Strategy 1 — HTML string snapshots (all platforms):**
```swift
assertSnapshot(of: html, as: .lines, named: "login-html")
```

**Strategy 2 — Pixel screenshots (macOS only):**
```swift
#if canImport(WebKit)
import WebKit

// Render HTML in WKWebView at 1280x800 viewport
let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 800))
webView.loadHTMLString(html, baseURL: nil)
// Wait for load + CDN resources
assertSnapshot(of: webView, as: .image(size: CGSize(width: 1280, height: 800)), named: "login-screenshot")
#endif
```

Both strategies run on macOS dev machines. Linux CI only runs HTML string snapshots. Reference images go in `Tests/CMSAdminTests/__Snapshots__/`.

### 1D. Test fixtures

**New file:** `Tests/CMSAdminTests/Fixtures/AdminTestFixtures.swift`

Predefined test data:
- `sampleBlogContentType` — a ContentTypeDefinition with title (string, maxLength:255), body (string, format:richtext), published (boolean), views (number), category (string, enum)
- `sampleBlogEntry` — populated entry data
- `sampleContentTypes` — array of 3 types for list view

---

## Phase 2: Content Editor Fixes (Gemini's Gaps)

**File:** `Resources/Views/admin/content/edit.leaf`

### 2A. Fix field type heuristics

Current problem: The field renderer uses `field.format` to distinguish types, but the content type builder stores schemas without `format` for plain text fields. The heuristic should be:

```javascript
// In the field rendering switch (edit.leaf ~line 233):
case 'string':
    if (field.format === 'richtext' || field['x-field-type'] === 'richtext') {
        // TipTap editor
    } else if (field.format === 'textarea' || (!field.maxLength && !field.format && !field.enum)) {
        // Textarea (longText) — string with no constraints = textarea
    } else if (field.format === 'date' || field.format === 'date-time' || field.format === 'datetime') {
        // Date picker
    } else if (field.format === 'email') {
        // Email input with validation
    } else if (field.enum) {
        // Select dropdown
    } else if (field.format === 'file' || field.format === 'image') {
        // File upload
    } else if (field.format === 'uuid' && field['x-field-type'] === 'media') {
        // Media picker (new - Phase 2C)
    } else if (field.format === 'uuid' && field['x-field-type'] === 'relation') {
        // Relation picker (new - Phase 2D)
    } else {
        // shortText — text input with optional character counter
        // Show counter if maxLength is set
    }
```

### 2B. Add JSON field type

For `type: "object"` in the switch statement, render a collapsible JSON editor:

```html
<!-- Collapsible JSON editor -->
<div class="collapse collapse-arrow bg-base-200 rounded-lg">
    <input type="checkbox" checked>
    <div class="collapse-title font-medium">JSON Editor</div>
    <div class="collapse-content">
        <textarea class="textarea textarea-bordered w-full font-mono text-sm"
                  rows="8" x-model="jsonString"
                  @input="try { data.fieldName = JSON.parse(jsonString); errors.fieldName = '' } catch(e) { errors.fieldName = 'Invalid JSON' }">
        </textarea>
    </div>
</div>
```

### 2C. Add Media picker field

For media UUID fields, render a "Select Media" button that opens a modal with thumbnails from `/admin/media` loaded via HTMX:

```html
<div class="flex items-center gap-3">
    <img x-show="data.fieldName" :src="'/api/v1/media/' + data.fieldName + '/thumbnail'"
         class="w-16 h-16 object-cover rounded-lg">
    <button @click="$refs.mediaModal.showModal()" class="btn btn-outline btn-sm">
        Select Media
    </button>
    <button x-show="data.fieldName" @click="data.fieldName = null" class="btn btn-ghost btn-xs text-error">
        Remove
    </button>
</div>
<!-- Modal loaded via HTMX with media grid -->
```

### 2D. Add Relation field (searchable select)

For relation fields (identified by `x-field-type: 'relation'` or contextual detection), render a searchable dropdown:

```html
<div x-data="{ search: '', results: [], selected: data.fieldName }">
    <input type="text" x-model="search" placeholder="Search entries..."
           class="input input-bordered w-full"
           @input.debounce.300ms="fetchRelated(search)">
    <div x-show="results.length" class="dropdown-content bg-base-100 shadow-lg rounded-box mt-1 max-h-48 overflow-y-auto">
        <template x-for="item in results">
            <div @click="selected = item.id; data.fieldName = item.id; results = []"
                 class="p-2 hover:bg-base-200 cursor-pointer" x-text="item.title"></div>
        </template>
    </div>
</div>
```

### 2E. Polish autosave indicator

Replace the hidden/show toggle with a persistent status bar:

```html
<div class="flex items-center gap-2 text-sm">
    <!-- Saving state -->
    <span x-show="isSaving" class="flex items-center gap-1 text-warning">
        <span class="loading loading-spinner loading-xs"></span> Saving...
    </span>
    <!-- Saved state -->
    <span x-show="!isSaving && lastSaved" class="flex items-center gap-1 text-success">
        <svg class="w-3 h-3">...</svg>
        Saved <span x-text="timeAgo(lastSaved)"></span>
    </span>
    <!-- Unsaved changes indicator -->
    <span x-show="hasUnsavedChanges()" class="flex items-center gap-1 text-warning">
        <span class="w-2 h-2 bg-warning rounded-full animate-pulse"></span>
        Unsaved changes
    </span>
</div>
```

---

## Phase 3: Power User Features (Strapi Differentiators)

These are features Strapi doesn't have — they make SwiftCMS feel premium.

### 3A. Command Palette (Cmd+K)

**File:** `Resources/Views/admin/base.leaf` (add to bottom, before closing `</body>`)

Add Fuse.js CDN for fuzzy search:
```html
<script src="https://cdn.jsdelivr.net/npm/fuse.js@7.0.0"></script>
```

**Small Swift change required:** Add `contentTypes` to the base template context in `AdminController` so all admin pages have the list available. This is a one-line addition to each handler's context (or better: a shared middleware/helper that injects it).

**File:** `Sources/CMSAdmin/AdminController.swift` — each handler that renders a template adds:
```swift
// Fetch all content types for sidebar + command palette
let allTypes = try await ContentTypeDefinition.query(on: req.db).all()
// Add to context: "contentTypes": allTypes
```

Alpine.js component in `adminApp()`:

```javascript
commandPalette: {
    isOpen: false,
    query: '',
    results: [],
    selectedIndex: 0,
    // Static pages + server-rendered content types
    categories: [
        { name: 'Pages', items: [
            { title: 'Dashboard', url: '/admin', icon: 'home' },
            { title: 'Content Types', url: '/admin/content-types', icon: 'list' },
            { title: 'Media Library', url: '/admin/media', icon: 'image' },
            { title: 'Users & Roles', url: '/admin/users', icon: 'users' },
            { title: 'Webhooks', url: '/admin/webhooks', icon: 'link' },
            { title: 'Settings', url: '/admin/settings', icon: 'settings' },
        ]},
        { name: 'Content', items: [
            // Server-rendered from contentTypes passed to base.leaf
            #for(type in contentTypes):
            { title: '#(type.displayName)', url: '/admin/content/#(type.slug)', icon: 'doc' },
            #endfor
        ]},
        { name: 'Actions', items: [
            { title: 'New Content Type', url: '/admin/content-types/new', icon: 'plus' },
            #for(type in contentTypes):
            { title: 'New #(type.displayName)', url: '/admin/content/#(type.slug)/new', icon: 'plus' },
            #endfor
            { title: 'Toggle Dark Mode', action: 'toggleTheme', icon: 'moon' },
        ]}
    ]
}
```

UI: Full-screen overlay with centered search box, categorized results, keyboard navigation (up/down/enter/escape).

```html
<!-- Command Palette Overlay -->
<div x-show="commandPalette.isOpen" x-transition.opacity
     class="fixed inset-0 z-[100] bg-black/50 backdrop-blur-sm flex items-start justify-center pt-[20vh]"
     @keydown.escape="commandPalette.isOpen = false"
     @click.self="commandPalette.isOpen = false">
    <div class="bg-base-100 rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden border border-base-300">
        <!-- Search input -->
        <div class="p-4 border-b border-base-300">
            <input type="text" x-model="commandPalette.query" x-ref="cmdInput"
                   placeholder="Type a command or search..."
                   class="input input-ghost w-full text-lg focus:outline-none"
                   @keydown.arrow-down.prevent="commandPalette.selectedIndex++"
                   @keydown.arrow-up.prevent="commandPalette.selectedIndex--"
                   @keydown.enter.prevent="executeCommand()">
        </div>
        <!-- Results list -->
        <div class="max-h-80 overflow-y-auto p-2">
            <!-- Categorized results with keyboard highlight -->
        </div>
        <!-- Footer hint -->
        <div class="p-3 border-t border-base-300 flex gap-4 text-xs text-base-content/50">
            <span><kbd class="kbd kbd-xs">↑↓</kbd> Navigate</span>
            <span><kbd class="kbd kbd-xs">↵</kbd> Open</span>
            <span><kbd class="kbd kbd-xs">esc</kbd> Close</span>
        </div>
    </div>
</div>
```

Global keyboard listener:
```javascript
// In adminApp init():
document.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        this.commandPalette.isOpen = !this.commandPalette.isOpen;
        if (this.commandPalette.isOpen) {
            this.$nextTick(() => this.$refs.cmdInput?.focus());
        }
    }
});
```

### 3B. Keyboard Shortcuts

**File:** `Resources/Views/admin/base.leaf`

Global shortcuts registered in `adminApp.init()`:

| Shortcut | Action | Scope |
|---|---|---|
| `Cmd+K` / `Ctrl+K` | Command palette | Global |
| `Cmd+S` / `Ctrl+S` | Save current entry | Content editor |
| `?` | Show shortcuts help modal | Global (when not in input) |
| `Escape` | Close modal/palette | Global |
| `g then d` | Go to dashboard | Global (vim-style) |
| `g then c` | Go to content types | Global |
| `g then m` | Go to media | Global |

Help modal (triggered by `?`):
```html
<dialog id="shortcuts-modal" class="modal">
    <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">Keyboard Shortcuts</h3>
        <!-- Table of shortcuts -->
    </div>
</dialog>
```

### 3C. Breadcrumb Navigation

**File:** `Resources/Views/admin/base.leaf` — add between header and `#import("content")`

```html
<nav class="breadcrumbs text-sm px-6 py-2 border-b border-base-200" aria-label="Breadcrumb">
    <ul>
        <li><a href="/admin" class="text-base-content/60 hover:text-primary">Dashboard</a></li>
        #if(breadcrumb1):
        <li><a href="#(breadcrumb1Url)" class="text-base-content/60 hover:text-primary">#(breadcrumb1)</a></li>
        #endif
        #if(breadcrumb2):
        <li><span class="text-base-content">#(breadcrumb2)</span></li>
        #endif
    </ul>
</nav>
```

**Note:** Breadcrumbs will be built client-side by parsing `window.location.pathname` — no backend change needed:

```javascript
// In adminApp init():
buildBreadcrumbs() {
    const path = window.location.pathname.replace('/admin', '').split('/').filter(Boolean);
    // Map path segments to readable labels using known route patterns
}
```

### 3D. Toast Notification System

**File:** `Resources/Views/admin/base.leaf`

Alpine.js store for toasts:

```javascript
// Add to adminApp():
toasts: [],
addToast(message, type = 'success', duration = 4000) {
    const id = Date.now();
    this.toasts.push({ id, message, type, progress: 100 });
    // Animate progress bar
    const interval = setInterval(() => {
        const toast = this.toasts.find(t => t.id === id);
        if (toast) toast.progress -= (100 / (duration / 50));
    }, 50);
    setTimeout(() => {
        clearInterval(interval);
        this.toasts = this.toasts.filter(t => t.id !== id);
    }, duration);
}
```

Toast container:
```html
<!-- Fixed bottom-right toast stack -->
<div class="fixed bottom-6 right-6 z-[200] space-y-3 w-80">
    <template x-for="toast in toasts" :key="toast.id">
        <div x-transition:enter="transition ease-out duration-300"
             x-transition:enter-start="opacity-0 translate-x-8"
             x-transition:enter-end="opacity-100 translate-x-0"
             x-transition:leave="transition ease-in duration-200"
             x-transition:leave-start="opacity-100"
             x-transition:leave-end="opacity-0"
             class="alert shadow-lg"
             :class="{
                 'alert-success': toast.type === 'success',
                 'alert-error': toast.type === 'error',
                 'alert-warning': toast.type === 'warning',
                 'alert-info': toast.type === 'info'
             }">
            <span x-text="toast.message"></span>
            <button @click="toasts = toasts.filter(t => t.id !== toast.id)" class="btn btn-xs btn-ghost">x</button>
            <!-- Progress bar -->
            <div class="absolute bottom-0 left-0 h-1 bg-current/30 rounded-b transition-all"
                 :style="'width: ' + toast.progress + '%'"></div>
        </div>
    </template>
</div>
```

Replace all `alert()` calls in edit.leaf and other templates with `addToast()`.

---

## Phase 4: Visual Polish & Micro-interactions

### 4A. Animated stat counters on dashboard

**File:** `Resources/Views/admin/dashboard.leaf`

Replace static numbers with Alpine.js counter animation:

```html
<p class="text-2xl font-bold text-primary"
   x-data="{ count: 0, target: #(typeCount) }"
   x-init="let start = performance.now();
           function animate(now) {
               const elapsed = now - start;
               const progress = Math.min(elapsed / 800, 1);
               count = Math.round(target * progress);
               if (progress < 1) requestAnimationFrame(animate);
           }
           requestAnimationFrame(animate);"
   x-text="count">
</p>
```

### 4B. Skeleton loading states

**File:** `Resources/Views/admin/base.leaf` — add CSS classes:

```css
.skeleton-pulse {
    animation: skeleton-pulse 1.5s ease-in-out infinite;
    background: linear-gradient(90deg, var(--b3) 25%, var(--b2) 50%, var(--b3) 75%);
    background-size: 200% 100%;
}
@keyframes skeleton-pulse {
    0% { background-position: 200% 0; }
    100% { background-position: -200% 0; }
}
```

Add skeleton partials shown during HTMX loading via `hx-indicator` pattern. DaisyUI already has `.skeleton` class — leverage it.

### 4C. Card hover effects (enhance existing)

Current cards already have `hover:shadow-md hover:-translate-y-1`. Enhance with border color shift:

```css
.card {
    transition: all 0.2s ease;
    border: 1px solid transparent;
}
.card:hover {
    border-color: oklch(var(--p) / 0.2);
}
```

### 4D. Beautiful empty states

Content list (`list.leaf`) and other list pages — add illustrated empty states similar to what `types.leaf` already has (it has a good one at line 141-164). Replicate this pattern for:
- Content list (no entries for this type)
- Media library (no files)
- Webhooks list (no webhooks)

### 4E. Implement Chart.js on dashboard

**File:** `Resources/Views/admin/dashboard.leaf`

Replace the placeholder (lines 280-297) with a real canvas and chart:

```html
<canvas id="activityChart" class="w-full h-48"></canvas>
```

```javascript
// Use dummy data or data passed from server
const ctx = document.getElementById('activityChart');
new Chart(ctx, {
    type: 'line',
    data: {
        labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        datasets: [{
            label: 'Entries Created',
            data: [3, 7, 4, 6, 2, 8, 5], // Server-rendered or static
            borderColor: 'oklch(var(--p))',
            backgroundColor: 'oklch(var(--p) / 0.1)',
            fill: true,
            tension: 0.4,
        }]
    },
    options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: { y: { beginAtZero: true, ticks: { stepSize: 1 } } }
    }
});
```

Also fix the JS syntax error at `dashboard.leaf:329`: `default function refreshSystemHealth()` should be `function refreshSystemHealth()`.

---

## Phase 5: Settings Page Overhaul

**File:** `Resources/Views/admin/settings/index.leaf`

Replace bare-bones 2-field form with a tabbed interface:

```html
<div x-data="{ activeTab: 'general' }">
    <!-- Tab Navigation -->
    <div class="tabs tabs-bordered mb-6">
        <button @click="activeTab = 'general'" :class="{ 'tab-active': activeTab === 'general' }" class="tab">General</button>
        <button @click="activeTab = 'api'" :class="{ 'tab-active': activeTab === 'api' }" class="tab">API</button>
        <button @click="activeTab = 'media'" :class="{ 'tab-active': activeTab === 'media' }" class="tab">Media</button>
        <button @click="activeTab = 'advanced'" :class="{ 'tab-active': activeTab === 'advanced' }" class="tab">Advanced</button>
    </div>

    <!-- General Tab: site name, description, timezone -->
    <!-- API Tab: CORS origins, rate limits, API key display -->
    <!-- Media Tab: max upload size, allowed MIME types, storage provider -->
    <!-- Advanced Tab: cache TTL, debug mode toggle, maintenance mode -->
</div>
```

**Note:** Since there's no backend for most settings yet, these tabs will be UI-only with disabled save buttons and "Coming soon" indicators where data isn't available. This establishes the design pattern for when backend settings endpoints are added.

---

## Files Modified

| File | Phase | Change |
|---|---|---|
| `Package.swift` | 1A | Add swift-snapshot-testing dep + CMSAdminTests target |
| `Tests/CMSAdminTests/LeafSnapshotTestCase.swift` | 1B | **NEW** — Test helper |
| `Tests/CMSAdminTests/AdminSnapshotTests.swift` | 1C | **NEW** — Snapshot tests |
| `Tests/CMSAdminTests/Fixtures/AdminTestFixtures.swift` | 1D | **NEW** — Test data |
| `Resources/Views/admin/content/edit.leaf` | 2A-2E | Fix heuristics, add JSON/media/relation fields, polish autosave |
| `Resources/Views/admin/base.leaf` | 3A-3D, 4B-4C | Command palette, shortcuts, breadcrumbs, toasts, skeleton CSS |
| `Resources/Views/admin/dashboard.leaf` | 4A, 4E | Animated counters, Chart.js, fix JS error |
| `Resources/Views/admin/list.leaf` | 4D | Better empty state |
| `Resources/Views/admin/webhooks/list.leaf` | 4D | Better empty state |
| `Resources/Views/admin/settings/index.leaf` | 5 | Tabbed settings redesign |
| `Sources/CMSAdmin/AdminController.swift` | 3A | Pass `contentTypes` to base template context |

## New CDN Dependencies

| Library | Version | Purpose | CDN |
|---|---|---|---|
| Fuse.js | 7.0.0 | Fuzzy search for command palette | jsdelivr |

(Chart.js already loaded in dashboard.leaf)

---

## Verification Plan

### Automated
```bash
# Run all snapshot tests (generates baselines on first run)
swift test --filter CMSAdminTests

# Update snapshots after intentional changes
SNAPSHOT_TESTING_RECORD=true swift test --filter CMSAdminTests
```

### Manual Browser Testing
1. **Command Palette:** Press Cmd+K on any page -> overlay appears -> type to fuzzy search -> arrow keys navigate -> Enter opens -> Escape closes
2. **Keyboard Shortcuts:** Press `?` -> shortcuts modal appears. Press Cmd+S on editor -> saves entry.
3. **Content Editor:**
   - Create a type with: shortText (maxLength:255), longText (no constraints), richText (format:richtext), number, boolean, JSON (type:object), enum
   - Navigate to new entry -> verify each field renders correctly
   - Edit existing entry -> verify data populates
4. **Toast Notifications:** Save an entry -> green toast appears bottom-right -> auto-dismisses with progress bar
5. **Dashboard:** Verify animated counters count up on load. Verify Chart.js renders line chart.
6. **Dark Mode:** Toggle theme -> verify command palette, toasts, chart, and all new components respect dark mode
7. **Mobile:** Resize to <1024px -> verify command palette is full-width, toasts stack properly
8. **Settings:** Navigate to /admin/settings -> verify tabbed layout with 4 tabs
