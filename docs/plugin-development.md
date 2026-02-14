# Plugin Development Guide

Plugins extend SwiftCMS functionality through a modular architecture. This guide covers creating, developing, and publishing plugins.

## Plugin Architecture

SwiftCMS plugins are Swift packages that implement the `CmsModule` protocol. They can:
- Register custom routes and API endpoints
- Hook into system events
- Add admin UI pages
- Provide custom field types
- Extend the CMS with new functionality

## Creating a Plugin

### 1. Plugin Structure

Create a directory for your plugin:

```
Modules/YourPlugin/
├── plugin.json              # Plugin manifest
├── YourPluginModule.swift   # Main module implementation
├── Controllers/             # Route controllers
├── Models/                  # Database models
├── Views/                   # Leaf templates (for admin UI)
└── Resources/               # Static assets
```

### 2. Plugin Manifest (plugin.json)

The manifest defines your plugin's metadata and capabilities:

```json
{
    "name": "your-plugin",
    "version": "1.0.0",
    "description": "Description of what your plugin does",
    "author": "Your Name",
    "website": "https://your-plugin.com",
    "dependencies": [
        "seo",
        "analytics"
    ],
    "hooks": [
        "content.created",
        "content.updated",
        "content.deleted",
        "media.uploaded"
    ],
    "adminPages": [
        {
            "label": "Your Plugin",
            "icon": "star",
            "path": "/admin/plugins/your-plugin",
            "permission": "plugin.admin"
        }
    ],
    "fieldTypes": [
        {
            "name": "colorPicker",
            "component": "ColorPicker"
        }
    ]
}
```

**Manifest Fields:**

- `name`: Unique plugin identifier (kebab-case)
- `version`: Semantic version (x.y.z)
- `description`: Brief plugin description
- `author`: Plugin author name
- `website`: Plugin homepage (optional)
- `dependencies`: Array of plugin names this plugin depends on
- `hooks`: Events this plugin listens to
- `adminPages`: Admin UI pages to register
- `fieldTypes`: Custom field types for content types

### 3. Implementing CmsModule Protocol

Create your main module file:

```swift
// Modules/YourPlugin/YourPluginModule.swift
import Vapor
import Fluent
import Leaf
import CMSCore
import CMSEvents
import CMSObjects

struct YourPluginModule: CmsModule {
    // MARK: - CmsModule Protocol

    let name = "your-plugin"
    let version = "1.0.0"
    let priority = 100

    func register(app: Application) throws {
        // Called during application startup
        // Register services, middleware, etc.
        app.logger.info("Registering \(name) v\(version)")
    }

    func boot(app: Application) throws {
        // Called after all modules are registered
        // Register routes, event handlers, etc.
        try registerRoutes(app: app)
        try registerEventHandlers(app: app)
        try registerAdminPages(app: app)
    }

    func shutdown(app: Application) async throws {
        // Called during application shutdown
        // Cleanup resources, close connections
    }
}

// MARK: - Route Registration

extension YourPluginModule {
    func registerRoutes(app: Application) throws {
        // Public API routes
        let pluginRoutes = app.grouped("api", "v1", "plugins", name)

        pluginRoutes.get("info") { req in
            return [
                "name": name,
                "version": version,
                "status": "active"
            ]
        }

        // Authenticated routes
        let protectedRoutes = pluginRoutes.grouped(
            app.storage[AuthProviderKey.self]?.middleware() ?? []
        )

        protectedRoutes.post("data") { req async throws -> Response in
            let data = try req.content.decode(PluginDataDTO.self)
            // Process plugin data
            return try await createPluginResponse(data)
        }
    }
}

// MARK: - Event Handler Registration

extension YourPluginModule {
    func registerEventHandlers(app: Application) throws {
        // Listen for content creation events
        app.eventBus.subscribe(ContentCreatedEvent.self) { event, context in
            Task {
                await self.handleContentCreated(event, context: context)
            }
        }

        // Listen for content updates
        app.eventBus.subscribe(ContentUpdatedEvent.self) { event, context in
            Task {
                await self.handleContentUpdated(event, context: context)
            }
        }
    }

    private func handleContentCreated(_ event: ContentCreatedEvent, context: EventContext) async {
        context.logger.info("Content created: \(event.entryId)")

        // Perform plugin-specific actions
        await syncData(event: event, context: context)
    }

    private func handleContentUpdated(_ event: ContentUpdatedEvent, context: EventContext) async {
        context.logger.info("Content updated: \(event.entryId)")

        // Invalidate caches, trigger workflows, etc.
        await invalidateCache(event: event, context: context)
    }

    private func syncData(event: any CmsEvent, context: EventContext) async {
        // Your plugin logic here
    }

    private func invalidateCache(event: any CmsEvent, context: EventContext) async {
        // Your cache invalidation logic here
    }
}

// MARK: - Admin UI Registration

extension YourPluginModule {
    func registerAdminPages(app: Application) throws {
        // Register admin route
        app.get("admin", "plugins", name) { req async throws -> View in
            let pluginData = try await fetchPluginData(req: req)
            return try await req.view.render("admin/plugins/\(name)/dashboard", [
                "plugin": [
                    "name": name,
                    "version": version,
                    "data": pluginData
                ]
            ])
        }
    }

    private func fetchPluginData(req: Request) async throws -> [String: Any] {
        // Fetch data for admin UI
        return [
            "stats": [
                "total": 42,
                "active": 38,
                "pending": 4
            ]
        ]
    }

    private func createPluginResponse(_ data: PluginDataDTO) async throws -> Response {
        // Process and return response
        let response = PluginResponseDTO(
            success: true,
            message: "Data processed successfully",
            data: data
        )
        return Response(status: .ok, body: .init(data: try JSONEncoder().encode(response)))
    }
}

// MARK: - DTOs

struct PluginDataDTO: Content {
    let action: String
    let payload: [String: AnyCodableValue]
    let metadata: [String: String]?
}

struct PluginResponseDTO: Content {
    let success: Bool
    let message: String
    let data: PluginDataDTO?
}
```

## Event System

SwiftCMS uses a powerful event system for inter-module communication:

### Available Events

```swift
// Content Events
ContentCreatedEvent        // Fired when content is created
ContentUpdatedEvent        // Fired when content is updated
ContentDeletedEvent        // Fired when content is deleted
ContentPublishedEvent      // Fired when content status changes to published
ContentUnpublishedEvent    // Fired when content is unpublished

// Schema Events
ContentTypeCreatedEvent    // Fired when a content type is created
ContentTypeUpdatedEvent    // Fired when a content type is updated
ContentTypeDeletedEvent    // Fired when a content type is deleted

// Media Events
MediaUploadedEvent         // Fired when media is uploaded
MediaDeletedEvent          // Fired when media is deleted

// Auth Events
UserCreatedEvent           // Fired when a new user is created
UserUpdatedEvent           // Fired when user details are updated

// System Events
PluginEnabledEvent         // Fired when a plugin is enabled
PluginDisabledEvent        // Fired when a plugin is disabled
WebhookTriggeredEvent      // Fired when a webhook is triggered
```

### Event Structure

```swift
struct ContentCreatedEvent: CmsEvent {
    static let eventName = "content.created"

    let entryId: UUID
    let contentTypeSlug: String
    let data: [String: AnyCodableValue]
    let createdBy: UUID?
    let createdAt: Date
}
```

### Subscribing to Events

```swift
// In your plugin's boot method
func registerEventHandlers(app: Application) throws {
    // Method 1: Using closure
    app.eventBus.subscribe(ContentCreatedEvent.self) { event, context in
        Task {
            await self.handleContentCreation(event, context: context)
        }
    }

    // Method 2: Using async method reference
    app.eventBus.subscribe(ContentCreatedEvent.self, handler: handleContentCreation)

    // Method 3: Multiple events with same handler
    [ContentCreatedEvent.self, ContentUpdatedEvent.self].forEach { eventType in
        app.eventBus.subscribe(eventType) { event, context in
            await self.handleContentChange(event, context: context)
        }
    }
}

private func handleContentCreation(_ event: ContentCreatedEvent, context: EventContext) async {
    // Your event handling logic
    context.logger.info("New content created: \(event.entryId)")

    // Access database if needed
    do {
        let count = try await ContentEntry.query(on: context.db)
            .filter(\.$contentTypeSlug == event.contentTypeSlug)
            .count()

        context.logger.info("Total \(event.contentTypeSlug): \(count)")
    } catch {
        context.logger.error("Database error: \(error)")
    }

    // Trigger other actions
    await notifySlack(event: event, context: context)
    await updateAnalytics(event: event, context: context)
}
```

## Admin UI Development

### Creating Admin Pages

Create Leaf templates in `Resources/Views/admin/plugins/your-plugin/`:

```leaf
<!-- Resources/Views/admin/plugins/your-plugin/dashboard.leaf -->
<!DOCTYPE html>
<html lang="en">
<head>
    <title>#(plugin.name) - SwiftCMS</title>
    #extend("admin/layout/base")
</head>
<body>
    #extend("admin/layout/sidebar")

    <main class="p-6">
        <div class="breadcrumbs text-sm">
            <ul>
                <li><a href="/admin">Home</a></li>
                <li>#(plugin.name)</li>
            </ul>
        </div>

        <h1 class="text-3xl font-bold mt-4">#(plugin.name)</h1>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-6">
            <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                    <h2 class="card-title">Total Items</h2>
                    <p class="text-3xl font-bold">#(stats.total)</p>
                </div>
            </div>

            <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                    <h2 class="card-title">Active</h2>
                    <p class="text-3xl font-bold text-success">#(stats.active)</p>
                </div>
            </div>

            <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                    <h2 class="card-title">Pending</h2>
                    <p class="text-3xl font-bold text-warning">#(stats.pending)</p>
                </div>
            </div>
        </div>

        <div class="mt-6">
            <button class="btn btn-primary" hx-post="/api/v1/plugins/your-plugin/sync"
                    hx-target="#result" hx-indicator="#loading">
                Sync Data
            </button>
            <div id="result" class="mt-4"></div>
            <div id="loading" class="htmx-indicator">Loading...</div>
        </div>
    </main>
</body>
</html>
```

### Using HTMX for Interactivity

SwiftCMS admin panel uses HTMX for dynamic interactions:

```leaf
<!-- Form with HTMX -->
<form hx-post="/api/v1/plugins/your-plugin/config"
      hx-target="#message"
      hx-swap="outerHTML">

    <div class="form-control">
        <label class="label" for="apiKey">
            <span class="label-text">API Key</span>
        </label>
        <input type="password" name="apiKey" class="input input-bordered"
               value="#(config.apiKey)">
    </div>

    <div class="form-control mt-6">
        <button type="submit" class="btn btn-primary">Save Settings</button>
    </div>
</form>

<div id="message"></div>
```

### Adding Custom Field Types

Plugins can register custom field types for content types:

```swift
// In your plugin module
func registerFieldTypes() {
    FieldTypeRegistry.shared.register(
        name: "colorPicker",
        component: ColorPickerField.self,
        adminComponent: "ColorPickerAdmin",
        validator: ColorValidator()
    )
}

// Field component implementation
struct ColorPickerField: FieldComponent {
    func render(value: AnyCodableValue?) -> HTML {
        // Render the field for public-facing forms
        return """
        <input type="color" value="\(value?.string ?? "#000000")"
               class="input input-bordered">
        """
    }
}

// Admin component (JavaScript/React component)
// Place in: Resources/admin/fields/ColorPickerAdmin.js
```

## Best Practices

### 1. Plugin Design Principles

- **Single Responsibility**: Each plugin should do one thing well
- **Configuration**: Allow users to configure plugin behavior
- **Idempotency**: Make repeated operations safe
- **Error Handling**: Handle errors gracefully with user-friendly messages
- **Performance**: Use async/await, avoid blocking operations
- **Testing**: Write unit tests for all public methods

### 2. Database Interactions

```swift
// Use transactions for multi-step operations
func processOrder(_ order: Order, context: EventContext) async throws {
    try await context.db.transaction { db in
        // Step 1: Update inventory
        try await updateInventory(order: order, db: db)

        // Step 2: Create invoice
        let invoice = try await createInvoice(order: order, db: db)

        // Step 3: Send confirmation
        try await sendOrderConfirmation(order: order, invoice: invoice, db: db)
    }
}

// Add indexes for frequently queried fields
struct CreatePluginDataIndex: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("plugin_data")
            .field("plugin_name", .string, .required)
            .field("entity_id", .uuid, .required)
            .field("key", .string, .required)
            .field("value", .json)
            .unique(on: "plugin_name", "entity_id", "key")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("plugin_data").delete()
    }
}
```

### 3. Configuration Management

```swift
// Create configuration struct
struct PluginConfiguration: Codable {
    let apiKey: String
    let webhookUrl: String
    let enabled: Bool
    let timeout: Int

    static let `default` = Self(
        apiKey: "",
        webhookUrl: "",
        enabled: true,
        timeout: 30
    )
}

// Store and retrieve configuration
extension Application {
    var yourPluginConfig: PluginConfiguration? {
        get {
            storage[YourPluginConfigKey.self]
        }
        set {
            storage[YourPluginConfigKey.self] = newValue
        }
    }
}

private struct YourPluginConfigKey: StorageKey {
    typealias Value = PluginConfiguration
}

// Load configuration from environment or database
func loadConfiguration(app: Application) async throws {
    if let envConfig = Environment.get("YOUR_PLUGIN_CONFIG") {
        let configData = Data(envConfig.utf8)
        let config = try JSONDecoder().decode(PluginConfiguration.self, from: configData)
        app.yourPluginConfig = config
    } else {
        // Load from database
        let config = try await PluginConfig.query(on: app.db)
            .filter(\.$pluginName == name)
            .first()

        app.yourPluginConfig = config?.value ?? .default
    }
}
```

### 4. Error Handling

```swift
enum PluginError: Error {
    case invalidConfiguration(String)
    case apiError(String)
    case rateLimitExceeded
}

extension PluginError: AbortError {
    var status: HTTPResponseStatus {
        switch self {
        case .invalidConfiguration:
            return .badRequest
        case .apiError:
            return .badGateway
        case .rateLimitExceeded:
            return .tooManyRequests
        }
    }

    var reason: String {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .rateLimitExceeded:
            return "Rate limit exceeded, please try again later"
        }
    }
}

// Use typed errors in route handlers
func configurePlugin(req: Request) async throws -> HTTPStatus {
    let config = try req.content.decode(PluginConfiguration.self)

    guard !config.apiKey.isEmpty else {
        throw PluginError.invalidConfiguration("API key is required")
    }

    guard URL(string: config.webhookUrl) != nil else {
        throw PluginError.invalidConfiguration("Invalid webhook URL")
    }

    try await saveConfiguration(config, db: req.db)
    return .ok
}
```

## Publishing Your Plugin

### 1. Prepare for Distribution

```bash
# Create plugin archive
cd Modules/YourPlugin
zip -r your-plugin-v1.0.0.zip . -x "*.git*" -x "*.DS_Store"
```

### 2. Submit to Plugin Registry

1. Fork the [SwiftCMS Plugins](https://github.com/artfularchivesstudio-spec/swiftcms-plugins) repository
2. Add your plugin to the registry JSON
3. Submit a pull request

### 3. Plugin Marketplace Listing

Create a README.md for your plugin:

```markdown
# Your Plugin for SwiftCMS

Description of your plugin's functionality.

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

1. Download the latest release
2. Extract to `Modules/`
3. Restart SwiftCMS

## Configuration

Add to your `.env`:

```bash
YOUR_PLUGIN_API_KEY=your-api-key
YOUR_PLUGIN_WEBHOOK_URL=https://your-webhook.com
```

## Usage

## License

MIT
```

## Examples

### Analytics Plugin Example

```swift
// Tracks content views and generates reports
struct AnalyticsModule: CmsModule {
    let name = "analytics"
    let version = "1.0.0"
    let priority = 50

    func boot(app: Application) throws {
        // Track all content views
        app.eventBus.subscribe(ContentViewedEvent.self) { event, context in
            Task {
                await self.trackView(event: event, context: context)
            }
        }

        // Register API routes
        let analytics = app.grouped("api", "v1", "analytics")
        analytics.get("stats") { req async throws in
            return try await self.getAnalytics(req: req)
        }
    }

    private func trackView(event: ContentViewedEvent, context: EventContext) async {
        let view = PageView(
            contentId: event.contentId,
            contentType: event.contentType,
            userId: event.userId,
            timestamp: Date(),
            ipAddress: event.ipAddress
        )

        try? await view.save(on: context.db)
    }
}
```

### SEO Plugin Example

```swift
// Generates sitemap.xml and manages meta tags
struct SEOModule: CmsModule {
    let name = "seo"
    let version = "1.0.0"
    let priority = 75

    func boot(app: Application) throws {
        // Register sitemap route
        app.get("sitemap.xml") { req async throws -> Response in
            let sitemap = try await self.generateSitemap(req: req)
            let response = Response(status: .ok, body: .init(string: sitemap))
            response.headers.contentType = .init(type: "application", subType: "xml")
            return response
        }

        // Add meta tags on content save
        app.eventBus.subscribe(ContentUpdatedEvent.self) { event, context in
            Task {
                await self.optimizeSEO(event: event, context: context)
            }
        }
    }
}
```

## Resources

- [SwiftCMS GitHub](https://github.com/artfularchivesstudio-spec/SwiftCMS)
- [Plugin Examples](https://github.com/artfularchivesstudio-spec/swiftcms-plugins)
- [Leaf Documentation](https://docs.vapor.codes/leaf/overview/)
- [Vapor Documentation](https://docs.vapor.codes/)

## Next Steps

- [Installation Guide](./installation.md) - Get started with SwiftCMS
- [Configuration Guide](./configuration.md) - Configure your installation
- [API Documentation](./api/) - Integrate with the API
