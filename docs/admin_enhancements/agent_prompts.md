# Agent Prompts for Parallel Excution

Use these prompts to instruct other agents to start work on specific **Tracks**. Each prompt is designed to be self-contained but references the global plan.

---

## 🚀 Track 1: Content Experience Agent
**Goal**: Polish the Content Editor (`edit.leaf`).

```text
@docs/admin_enhancements/checklist.md @task.md

You are the "Content Experience Agent". Your goal is to execute **Track 1** from the enhancement checklist.

**Focus Area**: `Resources/Views/admin/content/edit.leaf`

**Tasks**:
1. Fix field heuristics (Textarea vs Input vs TipTap).
2. Implement a collapsible JSON code editor.
3. Implement a Media Picker modal (using `format: uuid`).
4. Implement a Searchable Select for Relations.
5. Polish the Autosave UI (persistent status indicator).

Refer to `docs/admin_enhancements/roadmap.md` (Track 1) for implementation details.
Start by reading `edit.leaf` and `docs/admin_enhancements/roadmap.md`.
```

---

## 🧭 Track 2: Navigation Agent
**Goal**: Add Command Palette, Shortcuts, and Toasts.

```text
@docs/admin_enhancements/checklist.md @task.md

You are the "Navigation Agent". Your goal is to execute **Track 2** from the enhancement checklist.

**Focus Area**: `Resources/Views/admin/base.leaf` and `AdminController.swift` context.

**Tasks**:
1. Inject `contentTypes` into the base template context (in AdminController).
2. Implement the Command Palette (Cmd+K) with Alpine.js + Fuse.js.
3. Add global keyboard shortcuts (Save, Help, Navigation).
4. Implement client-side Breadcrumbs.
5. Implement a Toast notification system in `base.leaf`.

Refer to `docs/admin_enhancements/roadmap.md` (Track 2) for implementation details.
Start by reading `base.leaf` and `AdminController.swift`.
```

---

## 🎨 Track 3: Visuals Agent
**Goal**: Polish Dashboard and Settings.

```text
@docs/admin_enhancements/checklist.md @task.md

You are the "Visuals Agent". Your goal is to execute **Track 3** from the enhancement checklist.

**Focus Area**: `dashboard.leaf`, `settings/index.leaf`, and CSS.

**Tasks**:
1. Implement Chart.js on the Dashboard (replace placeholder).
2. Add animated number counters to dashboard stats.
3. Add skeleton loading states and enhanced hover effects.
4. Implement illustrated empty states for lists.
5. Redesign the Settings page to use a Tabbed Interface.

Refer to `docs/admin_enhancements/roadmap.md` (Track 3) for implementation details.
Start by reading `dashboard.leaf` and `docs/admin_enhancements/roadmap.md`.
```

---

## 🛠️ Track 4: Ecosystem Agent
**Goal**: Build OpenAPI and CLI tools.

```text
@docs/admin_enhancements/checklist.md @task.md

You are the "Ecosystem Agent". Your goal is to execute **Track 4** from the enhancement checklist.

**Focus Area**: New Modules (`CMSOpenAPI`, `CMSCLI`) and `Package.swift`.

**Tasks**:
1. Create `CMSOpenAPI` module and generate OpenAPI Spec.
2. Integrate Swagger UI.
3. Implement basic MCP Server endpoints (`cms://`).
4. Add CLI scaffolding commands (`generate type`, `generate plugin`).

Refer to `docs/admin_enhancements/roadmap.md` (Track 4) for implementation details.
Start by reading `Package.swift`.
```

---

## 🧪 Track 5: Reliability Agent (Me)
**Goal**: Snapshot Testing Infrastructure.

*(I am currently capable of handling this track. If you want another agent to do it, use this prompt:)*

```text
@docs/admin_enhancements/checklist.md @task.md

You are the "Reliability Agent". Your goal is to execute **Track 5** from the enhancement checklist.

**Focus Area**: `Tests/` and `Package.swift`.

**Tasks**:
1. Add `swift-snapshot-testing` to `Package.swift`.
2. Create `CMSAdminTests` target.
3. Implement `LeafSnapshotTestCase` helper.
4. Generate initial visual baselines for Admin UI.

Refer to `docs/admin_enhancements/roadmap.md` (Track 5) for implementation details.
Start by reading `Package.swift`.
```
