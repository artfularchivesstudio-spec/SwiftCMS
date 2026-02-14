# Plugin Development Guide

## Overview
Plugins extend SwiftCMS via the CMSModule protocol with three extension points:
routes, event hooks, and admin UI.

## Creating a Plugin

### 1. Create directory
```
Modules/MyPlugin/
  plugin.json
  MyPluginModule.swift
```

### 2. Write manifest (plugin.json)
```json
{
    "name": "my-plugin",
    "version": "1.0.0",
    "description": "My custom plugin",
    "author": "Your Name",
    "dependencies": [],
    "hooks": ["afterSave"],
    "adminPages": [
        {"label": "My Plugin", "icon": "star", "path": "/admin/plugins/my-plugin"}
    ]
}
```

### 3. Implement CMSModule
```swift
import Vapor
import CMSCore
import CMSEvents

struct MyPluginModule: CmsModule {
    let name = "my-plugin"
    let priority = 100

    func boot(app: Application) throws {
        // Register routes
        app.get("api", "v1", "plugins", "my-plugin", "data") { req in
            return ["status": "ok"]
        }

        // Subscribe to events
        app.eventBus.subscribe(ContentCreatedEvent.self) { event, ctx in
            ctx.logger.info("MyPlugin: new content \(event.entryId)")
        }

        // Register admin page
        app.get("admin", "plugins", "my-plugin") { req -> View in
            return try await req.view.render("admin/plugins/my-plugin")
        }
    }
}
```

## Extension Points
- **Routes**: Register under /api/v1/plugins/{name}/ and /admin/plugins/{name}/
- **Event Hooks**: Subscribe to any CmsEvent (content.created, schema.changed, etc.)
- **Admin UI**: Register Leaf templates as sidebar items or dashboard widgets
