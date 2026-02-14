# Blog + SwiftUI Example

Demonstrates SwiftCMS as a backend for an iOS blog app.

## Setup
1. Start SwiftCMS: `cd ../.. && make dev`
2. Create the "posts" content type via admin panel or API
3. Generate Swift SDK: `cms generate-sdk swift --output ./ClientSDK`
4. Open the Xcode project and run

## Content Type
```json
{
  "name": "Posts",
  "slug": "posts",
  "kind": "collection",
  "jsonSchema": {
    "type": "object",
    "properties": {
      "title": {"type": "string"},
      "body": {"type": "string"},
      "author": {"type": "string"},
      "tags": {"type": "array", "items": {"type": "string"}},
      "featuredImage": {"type": "string", "format": "uuid"}
    },
    "required": ["title", "body"]
  }
}
```
