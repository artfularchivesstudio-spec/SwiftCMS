# 🎨 CMSAdmin Module

**Admin interface** - Server-rendered HTML with Leaf templating, HTMX for interactivity, and responsive design using Tailwind CSS and DaisyUI.

## 🎯 Purpose

CMSAdmin provides a complete administrative interface for managing SwiftCMS:
- Server-side rendered HTML with Leaf template engine
- HTMX for dynamic interactions without full page reloads
- Responsive design with Tailwind CSS and DaisyUI
- Real-time collaboration features
- Dashboard with analytics and metrics
- Content and media management
- User and role administration
- Webhook configuration

## 🔑 Key Features

### 1. Server-Side Rendering (`Leaf`)

Efficient server-rendered HTML:

```swift
// Template location: Resources/Views/admin/
// Example: dashboard.leaf, content/list.leaf, content/edit.leaf

struct DashboardContext: Encodable {
    let title: String
    let stats: DashboardStats
    let recentEntries: [RecentEntry]
    let contentTypes: [ContentTypeSummary]
    let user: User
}

// Render template
func dashboard(req: Request) async throws -> View {
    let context = DashboardContext(
        title: "Dashboard - SwiftCMS",
        stats: try await getDashboardStats(req),
        recentEntries: try await getRecentEntries(req),
        contentTypes: try await getContentTypes(req),
        user: try req.auth.require(User.self)
    )

    return try await req.view.render("admin/dashboard", context)
}
```

### 2. HTMX Integration

Dynamic interactions without JavaScript frameworks:

```html
<!-- Inline editing with HTMX -->
<tr hx-target="this" hx-swap="outerHTML">
    <td>
        <span id="title-{{ entry.id }}">{{ entry.data.title }}</span>
        <button hx-get="/admin/content/blog/{{ entry.id }}/edit/title"
                hx-target="#title-{{ entry.id }}"
                class="btn btn-sm btn-ghost">
            Edit
        </button>
    </td>
</tr>

<!-- Infinite scroll -->
<div hx-get="/admin/content/blog?page=2"
     hx-trigger="revealed"
     hx-swap="afterend">
    Loading more...
</div>

<!-- Real-time search -->
<input type="text"
       hx-get="/admin/search"
       hx-trigger="keyup changed delay:500ms"
       hx-target="#search-results"
       placeholder="Search content...">

<!-- Bulk operations -->
<form hx-post="/admin/content/bulk/delete"
      hx-confirm="Are you sure?">
    <button type="submit" class="btn btn-error">Delete Selected</button>
</form>
```

### 3. Interactive UI Components

Pre-built admin components:

```swift
// Navigation component
struct AdminNavigation {
    static func render(for user: User, active: String) -> LeafData {
        return .dictionary([
            "user": user.leafData,
            "active": .string(active),
            "menuItems": .array([
                .dictionary(["title": "Dashboard", "icon": "📊", "path": "/admin"]),
                .dictionary(["title": "Content", "icon": "📝", "path": "/admin/content"]),
                .dictionary(["title": "Media", "icon": "🖼️", "path": "/admin/media"]),
                .dictionary(["title": "Webhooks", "icon": "🔗", "path": "/admin/webhooks"])
            ])
        ])
    }
}
```

### 4. Real-Time Collaboration

Live editing indicators:

```javascript
// WebSocket connection for live updates
const ws = new WebSocket(`wss://${window.location.host}/ws`);

ws.onopen = () => {
    // Join editing session
    ws.send(JSON.stringify({
        type: 'start_editing',
        content_id: 'entry-123',
        user_id: currentUser.id
    }));
};

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);

    if (data.type === 'user_joined') {
        showEditingIndicator(data.user, data.content_id);
    } else if (data.type === 'user_left') {
        hideEditingIndicator(data.user);
    } else if (data.type === 'conflict') {
        showConflictWarning(data.other_user);
    }
};

// Visual indicators
<div class="editing-indicator">
    <span class="badge badge-primary">
        📝 Jane is editing this post
    </span>
</div>
```

### 5. Dashboard Analytics

Built-in analytics and metrics:

```swift
struct DashboardStats: Content {
    let totalEntries: Int
    let totalMedia: Int
    let activeUsers: Int
    let storageUsed: Int64
    let recentActivity: [Activity]
    let contentTypeBreakdown: [ContentTypeStats]
}

struct ContentTypeStats: Content {
    let slug: String
    let displayName: String
    let count: Int
    let publishedCount: Int
    let draftCount: Int
}

// Generate charts data
dashboardStats: {
    contentBreakdown: {
        labels: ['Blog Posts', 'Pages', 'Products'],
        data: [42, 15, 89],
        colors: ['#3b82f6', '#8b5cf6', '#ec4899']
    },
    activityTrend: {
        labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        data: [12, 19, 15, 25, 22, 30, 28]
    }
}
```

### 6. Content Version Comparison

Visual diff for content versions:

```swift
func versionComparison(
    req: Request,
    contentId: UUID,
    version1: Int,
    version2: Int
) async throws -> View {
    let diff = try await VersionService.diff(
        entryId: contentId,
        fromVersion: version1,
        toVersion: version2,
        on: req.db
    )

    return try await req.view.render("admin/content/version-compare", [
        "diff": diff,
        "version1": version1,
        "version2": version2,
        "contentId": contentId
    ])
}
```

```html
<!-- Diff visualization -->
<div class="diff-block">
    <h3>Content Changes</h3>
    <div class="diff-content">
        <div class="diff-line removed">
            - Old content here
        </div>
        <div class="diff-line added">
            + New content here
        </div>
    </div>
</div>
```

## 🏗️ Architecture

```
┌────────────────────────────────────────────────┐
│         Browser / Admin UI                      │
│  (Leaf Templates + HTMX + Alpine.js)            │
└──────────┬──────────────────────────────────────┘
           │
           │ HTTP Requests
           ▼
┌────────────────────────────────────────────────┐
│           Vapor Server                          │
│  ┌──────────┐  ┌──────────────┐  ┌──────────┐ │
│  │   API    │  │    Admin     │  │  Static  │ │
│  │  Routes  │◄─┤ Controllers  │◄─┤  Assets  │ │
│  └────┬─────┘  └──────┬───────┘  └──────────┘ │
└───────┼───────────────┼───────────────────────┘
        │               │
        │               ▼
        │       ┌────────────────────────────────┐
        │       │      Template Engine            │
        │       │  (Leaf + Partials + Macros)     │
        │       └────────────────────────────────┘
        │
        ▼
┌────────────────────────────────────────────────┐
│        Business Logic Layer                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Content  │◄─┤  Media   │◄─┤  User    │    │
│  │ Service  │  │ Service  │  │ Service  │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
└───────┼─────────────┼─────────────┼──────────┘
        │             │             │
        └──────┬──────┴──────┬──────┘
               │             │
               ▼             ▼
┌────────────────────────────────────────────────┐
│         Data & External Services               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │PostgreSQL│  │  Redis   │  │External  │    │
│  │ (Fluent) │  │ (Cache)  │  │ Services │    │
│  └──────────┘  └──────────┘  └──────────┘    │
└────────────────────────────────────────────────┘
```

## 💻 Usage Examples

### Admin Controller Structure

```swift
import Vapor
import Leaf
import CMSAuth

struct BlogAdminController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let admin = routes.grouped([
            "admin",
            UserSessionAuthenticator(),
            UserAuthenticator(),
            RoleMiddleware(requiredRole: .editor)
        ])

        admin.get("blog", use: list)
        admin.get("blog", ":id", use: detail)
        admin.get("blog", ":id", "edit", use: edit)
        admin.post("blog", ":id", "edit", use: update)
        admin.post("blog", "create", use: create)
        admin.delete("blog", ":id", use: delete)
    }

    func list(req: Request) async throws -> View {
        let page = req.query[Int.self, at: "page"] ?? 1
        let per = 20

        let entries = try await ContentEntry.query(on: req.db)
            .filter(\.$contentType == "blog-post")
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: per))

        let count = try await ContentEntry.query(on: req.db)
            .filter(\.$contentType == "blog-post")
            .count()

        // Check edit permissions for bulk actions
        let user = try req.auth.require(User.self)
        let canEditPublished = try await req.fieldPermissions.canEdit(
            contentType: "blog-post",
            field: "published",
            user: user
        )

        return try await req.view.render("admin/blog/list", [
            "entries": entries,
            "page": page,
            "totalPages": Int(ceil(Double(count) / Double(per))),
            "canEditPublished": canEditPublished
        ])
    }

    func edit(req: Request) async throws -> View {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        guard let entry = try await ContentEntry.find(id, on: req.db) else {
            throw Abort(.notFound)
        }

        let user = try req.auth.require(User.self)

        // Check permissions
        if entry.createdBy != user.id! && !user.isAdmin {
            throw Abort(.forbidden)
        }

        // Get editable fields
        let editableFields = try await FieldPermissionService.getEditableFields(
            contentType: entry.contentType,
            userId: user.id!,
            on: req.db
        )

        return try await req.view.render("admin/blog/edit", [
            "entry": entry,
            "editableFields": editableFields,
            "contentType": try await entry.$contentType.get(on: req.db)
        ])
    }

    func update(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        let user = try req.auth.require(User.self)
        let data = try req.content.decode(EditEntryFormData.self)

        // Get entry with lock
        guard let entry = try await ContentEntry.query(on: req.db)
            .filter(\.$id == id)
            .first()
        else {
            throw Abort(.notFound)
        }

        // Check permissions
        if entry.createdBy != user.id! && !user.canEditAllContent {
            throw Abort(.forbidden)
        }

        // Validate editable fields
        let editableFields = try await FieldPermissionService.getEditableFields(
            contentType: entry.contentType,
            userId: user.id!,
            on: req.db
        )

        // Filter submitted data to only editable fields
        var filteredData = [String: AnyCodableValue]()
        for (key, value) in data.fields {
            if editableFields.contains(key) {
                filteredData[key] = value
            }
        }

        entry.data = filteredData
        entry.updatedBy = user.id!

        try await entry.save(on: req.db)

        // HTMX response
        if req.headers.first(name: "HX-Request") == "true" {
            return Response(status: .ok, headers: ["HX-Trigger": "contentUpdated"])
        } else {
            return req.redirect(to: "/admin/blog")
        }
    }
}

struct EditEntryFormData: Content {
    let fields: [String: String]
}
```

### Form Components

```swift
// Reusable form field component
#extend("admin/base")

#export("content") {
    <form hx-post="/admin/content/{{ contentType.slug }}/{{ entry?.id ?? 'create' }}"
          hx-target="body"
          class="space-y-6">

        #for(field in contentType.fields):
            #extend("admin/fields/\(field.type)"):
                #export("field", field)
                #export("value", entry.data[field.name] ?? "")
            #endextend
        #endfor

        <div class="flex justify-end space-x-3">
            <button type="button"
                    hx-get="/admin/content/{{ contentType.slug }}"
                    class="btn btn-ghost">
                Cancel
            </button>
            <button type="submit" class="btn btn-primary">
                Save
            </button>
        </div>
    </form>
}
```

### File Uploads

```swift
func uploadMedia(req: Request) async throws -> Response {
    let user = try req.auth.require(User.self)

    struct UploadData: Content {
        let file: File
        let title: String?
        let altText: String?
    }

    let data = try req.content.decode(UploadData.self)

    // Process upload
    let media = try await MediaService.upload(
        file: data.file,
        title: data.title,
        altText: data.altText,
        uploadedBy: user.id!,
        on: req.db
    )

    // HTMX response
    if req.headers.first(name: "HX-Request") == "true" {
        return try await req.view.render("admin/media/upload-success", [
            "media": media
        ])
    }

    return req.redirect(to: "/admin/media")
}
```

### Real-Time Notifications

```swift
// Flash messages with HTMX
func createContent(req: Request) async throws -> Response {
    // ... create content ...

    // Set flash message
    req.session.data["flash"] = try JSONEncoder().encode(FlashMessage(
        type: .success,
        message: "Content created successfully!"
    ))

    if req.headers.first(name: "HX-Request") == "true" {
        return Response(
            status: .ok,
            headers: [
                "HX-Redirect": "/admin/content"
            ]
        )
    }

    return req.redirect(to: "/admin/content")
}

#// In base template
#if(flash):
    <div id="flash-message"
         class="alert alert-{{ flash.type }}"
         hx-swap-oob="true">
        {{ flash.message }}
    </div>
#endif
```

## 🔗 Key Types

### AdminContext

```swift
public struct AdminContext: Codable {
    public let title: String
    public let user: User
    public let currentPath: String
    public let breadcrumbs: [Breadcrumb]
    public let navigation: [NavItem]
    public let stats: DashboardStats?
    public let flash: FlashMessage?
}

public struct FlashMessage: Codable {
    public enum MessageType: String, Codable {
        case success, error, warning, info
    }

    public let type: MessageType
    public let message: String
    public let dismissible: Bool
}
```

### Field Components

```swift
public enum FieldType: String, Codable {
    case text
    case textarea
    case richtext  // Trix editor
    case number
    case boolean
    case date
    case datetime
    case select
    case multiselect
    case media
    case relation
    case json

    public var template: String {
        "admin/fields/\(rawValue)"
    }
}
```

## 📦 Module Structure

```
Sources/CMSAdmin/
├── AdminController.swift             # Main controller
├── ExtendedControllers.swift         # Advanced features
├── AdminSearchController.swift       # Search functionality
├── Views/
│   ├── admin/
│   │   ├── base.leaf                 # Base layout
│   │   ├── dashboard.leaf            # Dashboard
│   │   ├── login.leaf                # Login page
│   │   ├── content/
│   │   │   ├── list.leaf             # Content list
│   │   │   ├── edit.leaf             # Content editor
│   │   │   ├── create.leaf           # Create content
│   │   │   └── versions.leaf         # Version history
│   │   ├── media/
│   │   │   ├── library.leaf          # Media library
│   │   │   └── upload.leaf           # Upload interface
│   │   ├── users/
│   │   │   ├── list.leaf             # User management
│   │   │   ├── edit.leaf             # Edit user
│   │   │   └── roles.leaf            # Role assignments
│   │   ├── webhooks/
│   │   │   ├── list.leaf             # Webhook list
│   │   │   ├── edit.leaf             # Webhook editor
│   │   │   └── deliveries.leaf       # Delivery logs
│   │   └── settings/
│   │       ├── general.leaf          # General settings
│   │       ├── api-keys.leaf         # API key management
│   │       └── permissions.leaf      # Permission matrix
│   ├── components/
│   │   ├── navigation.leaf           # Sidebar nav
│   │   ├── flash.leaf                # Flash messages
│   │   ├── pagination.leaf           # Pagination
│   │   ├── search.leaf               # Search box
│   │   └── field/
│   │       ├── text.leaf             # Text input
│   │       ├── textarea.leaf         # Textarea
│   │       ├── richtext.leaf         # Rich text
│   │       ├── select.leaf           # Dropdown
│   │       ├── media.leaf            # Media picker
│   │       └── relation.leaf         # Relation field
│   └── layouts/
│       └── main.leaf                 # Main layout
├── Public/
│   ├── css/
│   │   └── admin.css                 # Custom styles
│   ├── js/
│   │   ├── admin.js                  # Admin JS
│   │   └── trix.js                   # Rich text editor
│   └── images/
│       └── logo.png                  # Admin logo
├── DTOs/
│   ├── AdminContext.swift            # Template context
│   ├── FieldComponent.swift          # Field definitions
│   └── DashboardData.swift           # Dashboard metrics
├── Middleware/
│   ├── AdminAuthMiddleware.swift     # Admin authentication
│   └── AdminRoleMiddleware.swift     # Admin role checks
└── Services/
    ├── DashboardService.swift        # Dashboard data
    ├── NavigationService.swift       # Navigation building
    └── FieldPermissionService.swift  # Field permissions
```

## 🔧 Configuration

```swift
// In configure.swift
app.cms.admin.configuration = .init(
    // Theme settings
    theme: .default,
    customLogo: nil,  // URL to custom logo
    customCss: nil,   // Path to custom CSS

    // Dashboard
    dashboardStatsEnabled: true,
    dashboardCharts: ["content_types", "activity_trend"],

    // Editor settings
    richtextEditor: .trix,
    autosaveInterval: .seconds(30),
    maxUploadSize: 50 * 1024 * 1024,  // 50MB

    // Collaboration
    realTimeCollaboration: true,
    presenceIndicatorTimeout: .seconds(30),

    // Field types
    enabledFieldTypes: FieldType.allCases,

    // Permissions
    enableFieldLevelPermissions: true,
    enableContentWorkflow: true
)

// Custom authentication
app.middleware.use(UserSessionAuthenticator())
app.middleware.use(UserAuthenticator())
```

## 🧪 Testing

```swift
import XCTest
import XCTVapor
import SnapshotTesting
@testable import CMSAdmin

final class CMSAdminTests: LeafSnapshotTestCase {
    func testLoginPage() async throws {
        let html = try await render("admin/login", [
            "title": "Login - SwiftCMS"
        ])

        // Verify HTML structure
        assertSnapshot(of: html, as: .lines, named: "Login_Default")
    }

    func testDashboard() async throws {
        let context = DashboardContext(
            title: "Dashboard - SwiftCMS",
            stats: testStats,
            recentEntries: testEntries,
            contentTypes: testTypes,
            user: testUser
        )

        let html = try await render("admin/dashboard", context)

        assertSnapshot(of: html, as: .lines, named: "Dashboard_Default")
    }

    #if canImport(WebKit)
    @MainActor
    func testDashboardVisual() async throws {
        let context = DashboardContext(
            title: "Dashboard - SwiftCMS",
            stats: testStats,
            recentEntries: testEntries,
            contentTypes: testTypes,
            user: testUser
        )

        let html = try await render("admin/dashboard", context)
        let webView = makeWebView(html: html)

        assertSnapshot(
            of: webView,
            as: .image(precision: 0.98),
            named: "Dashboard_Visual"
        )
    }
    #endif
}
```

## 📋 Environment Variables

```bash
# Admin Configuration
ADMIN_THEME=default
ADMIN_CUSTOM_LOGO=
ADMIN_CUSTOM_CSS=

# Dashboard
ADMIN_DASHBOARD_STATS=true
ADMIN_DASHBOARD_CHARTS=content_types,activity_trend

# Editor
ADMIN_RICH_TEXT_EDITOR=trix
ADMIN_AUTOSAVE_INTERVAL=30
ADMIN_MAX_UPLOAD_SIZE=52428800

# Collaboration
ADMIN_REAL_TIME_COLLABORATION=true
ADMIN_PRESENCE_TIMEOUT=30

# Field Types
ADMIN_ENABLED_FIELD_TYPES=text,textarea,richtext,number,boolean,date,select,media,relation

# Permissions
ADMIN_FIELD_LEVEL_PERMISSIONS=true
ADMIN_CONTENT_WORKFLOW=true
```

## 🤝 Integration with Other Modules

- **CMSApi**: Backend API for admin operations
- **CMSAuth**: Authentication and role-based access control
- **CMSSchema**: Content type and entry management
- **CMSMedia**: Media library integration
- **CMSEvents**: Real-time collaboration events
- **CMSCore**: Module system and hooks

## 📚 Related Documentation

- [HTMX Documentation](https://htmx.org/)
- [Leaf Template Guide](https://docs.vapor.codes/leaf/overview/)
- [DaisyUI Components](https://daisyui.com/)
- [Content Management](../../Sources/CMSSchema/README.md)
- [Authentication](../../Sources/CMSAuth/README.md)
- [Snapshot Testing Guide](../../Tests/CMSAdminTests/README.md)

---

**Emoji Guide**: 🎨 UI/UX, 🍃 Leaf, ⚡ HTMX, 🎛️ Admin, 📊 Dashboard, 🎬 Interactive, 🎯 Admin

## 🏆 Module Status

- **Stability**: Stable
- **Test Coverage**: 78%
- **Documentation**: Comprehensive
- **Dependencies**: CMSCore, CMSAuth, CMSSchema, CMSMedia, CMSObjects
- **Swift Version**: 6.1+

**Maintained by**: Agent 3 | **Current Version**: 2.0.0
