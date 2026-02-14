# Blog + SwiftUI Example

A complete iOS blog app demonstrating SwiftCMS integration with SwiftUI. This example shows how to build a mobile blog reader and editor using SwiftCMS as the backend.

## Features

- Browse published blog posts
- View post details with images
- Search posts by title or content
- Offline caching with Core Data
- Pull-to-refresh for latest posts
- Rich text rendering

## Quick Start

### 1. Start SwiftCMS Backend

```bash
cd ../..
make setup    # Starts PostgreSQL, Redis, Meilisearch and builds SwiftCMS
swift run cms seed  # Create admin user and sample data
make run      # Start the server
```

The server will be available at `http://localhost:8080`

### 2. Create Content Types

#### Option A: Using Admin Panel

1. Open `http://localhost:8080/admin` in your browser
2. Login with: `admin@swiftcms.dev` / `admin123`
3. Navigate to **Settings → Content Types**
4. Click "Create Content Type" and use the configuration below

#### Option B: Using API

```bash
curl -X POST http://localhost:8080/api/v1/content-types \
  -H "Content-Type: application/json" \
  -d @content-types.json
```

### 3. Generate Swift Client SDK

```bash
swift run cms generate-sdk swift \
  --output ./ClientSDK \
  --package-name BlogSDK \
  --author "Your Name"
```

This will create a type-safe Swift SDK for your content types.

### 4. Open and Run Xcode Project

```bash
open BlogApp.xcodeproj
```

- Select your target device (iPhone simulator or device)
- Build and run (⌘R)

## Content Types

### Blog Post (posts)

```json
{
  "name": "Posts",
  "slug": "posts",
  "displayName": "Blog Posts",
  "kind": "collection",
  "jsonSchema": {
    "type": "object",
    "properties": {
      "title": {
        "type": "string",
        "minLength": 1,
        "maxLength": 200
      },
      "slug": {
        "type": "string",
        "pattern": "^[a-z0-9-]+$
      },
      "excerpt": {
        "type": "string",
        "maxLength": 300
      },
      "content": {
        "type": "string",
        "minLength": 1
      },
      "author": {
        "type": "string"
      },
      "tags": {
        "type": "array",
        "items": {
          "type": "string"
        }
      },
      "featuredImage": {
        "type": "string",
        "format": "uuid",
        "description": "Featured image from media library"
      },
      "publishedAt": {
        "type": "string",
        "format": "date-time"
      }
    },
    "required": ["title", "slug", "content", "author"]
  },
  "fieldOrder": [
    {
      "name": "title",
      "type": "text",
      "label": "Post Title"
    },
    {
      "name": "slug",
      "type": "text",
      "label": "URL Slug"
    },
    {
      "name": "excerpt",
      "type": "textarea",
      "label": "Excerpt",
      "rows": 3
    },
    {
      "name": "content",
      "type": "richtext",
      "label": "Content"
    },
    {
      "name": "author",
      "type": "text",
      "label": "Author Name"
    },
    {
      "name": "tags",
      "type": "tags",
      "label": "Tags"
    },
    {
      "name": "featuredImage",
      "type": "media",
      "label": "Featured Image"
    },
    {
      "name": "publishedAt",
      "type": "datetime",
      "label": "Published Date"
    }
  ],
  "settings": {
    "draftAndPublish": true,
    "timestamps": true,
    "locales": ["en", "es", "fr"]
  }
}
```

## API Integration

### Fetch All Posts

```swift
import BlogSDK

let client = SwiftCMSClient(baseURL: "http://localhost:8080")

// Fetch published posts
let posts = try await client.getContent(
    contentType: "posts",
    status: .published,
    sort: "-publishedAt"
)

for post in posts.data {
    print("\(post.data.title) by \(post.data.author)")
}
```

### Fetch Single Post

```swift
let postId = "550e8400-e29b-41d4-a716-446655440000"
let post = try await client.getContentEntry(
    contentType: "posts",
    id: postId
)

print(post.data.title)
print(post.data.content)
```

### Search Posts

```swift
let results = try await client.search(
    query: "SwiftUI",
    contentType: "posts"
)

for result in results.results {
    print("\(result.title) - Score: \(result.score)")
}
```

### Create New Post (Authenticated)

```swift
let newPost = CreateContentEntry(
    title: "My New Post",
    slug: "my-new-post",
    content: "Post content here...",
    author: "John Doe",
    tags: ["swift", "swiftui"],
    status: .draft
)

let created = try await client.createContent(
    contentType: "posts",
    entry: newPost
)
```

## App Features

### 1. Post List View

- Displays all published posts
- Pull-to-refresh functionality
- Search bar for filtering posts
- Infinite scroll pagination
- Offline support with cached data

### 2. Post Detail View

- Full post content display
- Featured image at top
- Author and publish date
- Tags/chips for categories
- Share functionality

### 3. Search

- Full-text search via Meilisearch
- Real-time search as you type
- Search result highlighting
- Recent searches history

### 4. Offline Support

- Core Data local cache
- Cache posts for offline reading
- Sync when connection restored
- Offline indicator

## WebSocket Real-time Updates (Optional)

Enable real-time updates in your app:

```swift
import SwiftCMSWebSocket

let ws = SwiftCMSWebSocket(url: "ws://localhost:8080/ws")
ws.onContentCreated { content in
    if content.type == "posts" {
        // Refresh post list
    }
}
ws.connect()
```

## Customization

### Change API URL

Update `BlogApp/Config.swift`:

```swift
struct Config {
    static let apiURL = "https://your-production-server.com"
    static let websocketURL = "wss://your-production-server.com/ws"
}
```

### Customize UI

The app uses SwiftUI and is fully customizable:

- Modify `PostRow.swift` for post list appearance
- Update `PostDetailView.swift` for detail layout
- Customize colors in `Assets.xcassets`
- Add new features in `ContentView.swift`

## Sample Data

### Creating Sample Posts

```bash
# Create sample posts
cd ../..
swift run cms import strapi \
  --file examples/blog-swiftui/sample-data.json \
  --skip-content-types
```

Or use the generated SDK:

```swift
// In your app or playground
let samplePosts = [
    ("Getting Started with SwiftUI", "swiftui-intro", "Learn the basics of SwiftUI..."),
    ("Building Lists in SwiftUI", "swiftui-lists", "Master list views..."),
    ("State Management", "swiftui-state", "Understand @State and @Binding...")
]

for (title, slug, content) in samplePosts {
    let post = CreateContentEntry(
        title: title,
        slug: slug,
        content: content,
        author: "SwiftCMS Team",
        tags: ["swiftui", "tutorial"],
        status: .published,
        publishedAt: Date()
    )

    try await client.createContent(contentType: "posts", entry: post)
}
```

## Deploying to Production

### Backend Deployment

See [Deployment Guide](../../docs/deployment.md) for production deployment.

### App Store Submission

1. Update API URLs to production
2. Configure proper entitlements
3. Test on device with production backend
4. Submit through Xcode Organizer

## Troubleshooting

### Connection Issues

```swift
// Debug network issues
let client = SwiftCMSClient(baseURL: "http://localhost:8080")
client.debugMode = true

// Check reachability
if !NetworkReachability.isConnected {
    showOfflineMode()
}
```

### Authentication Problems

```swift
// Ensure token is valid
do {
    let posts = try await client.getContent(contentType: "posts")
} catch SwiftCMSClientError.unauthorized {
    // Redirect to login
} catch {
    // Handle other errors
}
```

### Offline Sync Issues

```swift
// Force sync when online
if NetworkReachability.isConnected {
    await CoreDataSyncManager.shared.syncAll()
}
```

## Next Steps

- Add user authentication flow
- Implement post creation/editing
- Add image upload from device
- Integrate push notifications
- Add analytics tracking

See the [full documentation](../../docs/) for more advanced features.
