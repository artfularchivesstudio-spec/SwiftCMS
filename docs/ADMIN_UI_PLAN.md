# Admin UI Overhaul — Strapi-Quality Design

## Goal

Transform the existing bare-bones admin panel into a polished, Strapi-like CMS experience. The biggest gap is the **content editor** — currently a raw JSON textarea. Strapi generates field-specific form inputs (text fields, toggles, date pickers, rich text editors) from the content type schema. We need the same.

## Current State vs Target

| Area | Current | Target (Strapi-like) |
|---|---|---|
| Content editor | Raw JSON textarea | Field-specific form inputs generated from schema |
| Dashboard | 3 stat cards + table | Stat cards with icons + activity feed + quick actions |
| Base layout | Basic sidebar, no dark mode btn | Dark mode toggle, mobile hamburger, polished sidebar with dynamic content types |
| Login | Functional card | Gradient background, subtle animation |
| Content type builder | Functional (Alpine.js) | Visual polish, SortableJS drag-drop, field config panels |
| Content list | Plain table | Status badges with colors, bulk select, better pagination |
| Media library | Grid with hover actions | Already decent — minor polish |

## Proposed Changes

### Base Layout & Navigation

#### [MODIFY] [base.leaf](file:///Users/gurindersingh/Documents/Developer/Swift-CMS/Resources/Views/admin/base.leaf)

- Add dark mode toggle button (☀️/🌙) in top bar
- Add mobile hamburger menu with drawer
- Add SortableJS + TipTap CDN links
- Dynamic sidebar: list all content types as sub-items under "Content" with HTMX loading
- Add version badge in sidebar footer
- Premium styling: gradient sidebar header, better hover states, transition animations

---

### Content Editor (Critical Gap)

#### [MODIFY] [edit.leaf](file:///Users/gurindersingh/Documents/Developer/Swift-CMS/Resources/Views/admin/content/edit.leaf)

This is the biggest transformation. Replace the JSON textarea with a **dynamic form builder** that reads the content type's `jsonSchema` and generates appropriate inputs:

- `shortText` → text input with character count
- `longText` → auto-expanding textarea
- `richText` → TipTap rich text editor
- `integer/decimal` → number input with validation
- `boolean` → DaisyUI toggle switch
- `dateTime` → datetime-local input
- `email` → email input with validation icon
- `enumeration` → select dropdown
- `media` → image picker with preview thumbnail
- `json` → collapsible JSON editor with syntax highlighting
- `relation` → searchable select with HTMX autocomplete

Also add: status sidebar panel (like Strapi's right column), publish/unpublish actions, publish_at scheduler, and entry metadata display.

---

### Dashboard

#### [MODIFY] [dashboard.leaf](file:///Users/gurindersingh/Documents/Developer/Swift-CMS/Resources/Views/admin/dashboard.leaf)

- Stat cards with icons and trend colors
- Recent activity feed (from audit log)
- Quick action buttons (new content type, new entry)
- System health indicators with colors
- Welcome message

---

### Login Page

#### [MODIFY] [login.leaf](file:///Users/gurindersingh/Documents/Developer/Swift-CMS/Resources/Views/admin/login.leaf)

- Gradient background with subtle animation
- Larger branding
- Input focus animations

---

### Content Types List

#### [MODIFY] [types.leaf](file:///Users/gurindersingh/Documents/Developer/Swift-CMS/Resources/Views/admin/content/types.leaf)

- Card grid layout instead of plain table
- Field count, entry count per type
- Color-coded kind badges
- Better action buttons

---

### Content List

#### [MODIFY] [list.leaf](file:///Users/gurindersingh/Documents/Developer/Swift-CMS/Resources/Views/admin/content/list.leaf)

- Color-coded status badges (green=published, yellow=draft, blue=review, gray=archived)
- Better table styling with hover rows
- Field value preview columns (title, status, created)
- Bulk select checkboxes

---

### Content Type Builder

#### [MODIFY] [builder.leaf](file:///Users/gurindersingh/Documents/Developer/Swift-CMS/Resources/Views/admin/content/builder.leaf)

- Drag-and-drop with SortableJS (replace manual up/down buttons)
- Field configuration panels (expand to show min/max, default value, regex)
- Visual field type icons
- Live preview of generated schema

---

## Verification Plan

### Browser Testing
- Navigate to `/admin/login` and verify the polished login page
- Log in and verify the dashboard with stat cards and activity
- Create a content type and verify drag-drop builder
- Create an entry and verify field-specific form inputs
- Toggle dark mode and verify it works across all pages
- Test mobile responsiveness (hamburger menu)
