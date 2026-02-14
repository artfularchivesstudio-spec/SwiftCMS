# Content Types Guide

## Overview
Content types define the schema for your content. SwiftCMS uses JSONB storage
with JSON Schema validation, enabling runtime-definable types without recompilation.

## Creating via Admin Panel
1. Navigate to /admin/content-types
2. Click "+ New Type"
3. Enter name, slug, and kind (collection or single)
4. Add fields using the drag-drop field builder
5. Save — the type is immediately available via REST and GraphQL

## Creating via API
```bash
curl -X POST http://localhost:8080/api/v1/content-types \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Blog Posts",
    "slug": "blog-posts",
    "displayName": "Blog Posts",
    "kind": "collection",
    "jsonSchema": {
      "type": "object",
      "properties": {
        "title": {"type": "string", "maxLength": 255},
        "body": {"type": "string"},
        "featured": {"type": "boolean"}
      },
      "required": ["title"]
    },
    "fieldOrder": ["title", "body", "featured"]
  }'
```

## Field Types
SwiftCMS supports 14 field types: shortText, longText, richText, integer,
decimal, boolean, dateTime, email, enumeration, json, media, relationHasOne,
relationHasMany, component.

## Relations
- `relationHasOne` — stores a UUID reference, resolved with `?populate=field`
- `relationHasMany` — stores UUID array, resolved with `?populate=field`
- Max population depth: 2 (prevents circular references)
