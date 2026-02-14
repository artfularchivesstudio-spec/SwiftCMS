# 📐 CMSSchema Module

**Dynamic content modeling engine** - Runtime-defined content types, JSONB storage, and schema evolution.

## 🎯 Purpose

CMSSchema provides SwiftCMS with its core content management capabilities:
- Runtime content type definition
- Dynamic JSON Schema enforcement
- JSONB-based content storage in PostgreSQL
- Type-safe SDK generation
- Version control for content entries

## 🔑 Key Features

### 1. Dynamic Content Types

Define content types at runtime without code changes:

```swift
// Create content type via API
POST /api/v1/content-types
{
  "name": "Blog Post",
  "slug": "blog-post",
  "jsonSchema": {
    "type": "object",
    "properties": {
      "title": { "type": "string", "maxLength": 255 },
      "body": { "type": "string" },
      "published": { "type": "boolean" }
    },
    "required": ["title"]
  }
}
```

### 2. JSON Schema Validation

Automatic validation of content against schemas:

```swift
// Schema is enforced on all content operations
try await contentEntry.validate(
    schema: contentType.jsonSchema,
    jsonValidator: jsonValidator
)
```

### 3. JSONB Storage

Efficient PostgreSQL JSONB column storage:

```sql
-- Content data stored as JSONB
CREATE TABLE content_entries (
    id UUID PRIMARY KEY,
    content_type_id UUID REFERENCES content_types,
    data JSONB NOT NULL,
    status TEXT NOT NULL
);

-- Efficient queries with JSONB operators
SELECT * FROM content_entries
WHERE data->>'published' = 'true'
AND content_type_id = '...';
```

### 4. Content Versioning

Full version history with diff support:

```swift
// Automatic versioning on save
try await entry.save(on: db) // Creates version 1
try await entry.save(on: db) // Creates version 2

// List versions
let versions = try await VersionService.listVersions(
    entryId: entry.id!,
    on: db
)

// Restore version
try await VersionService.restore(
    entryId: entry.id!,
    version: 1,
    on: db
)

// View changes
let diff = try await VersionService.diff(
    fromVersion: 1,
    toVersion: 2,
    on: db
)
```

### 5. SDK Generation

Generate type-safe Swift client SDKs:

```swift
// Generates Swift models and API clients
swift run cms-cli generate-sdk
  --module-name "BlogAPI"
  --output ./Sources/BlogAPI

// Generated code includes:
// - Content type models
// - API client methods
// - Request/response DTOs
// - Mock data for testing
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│         API Layer (CMSApi)              │
│     REST + GraphQL Endpoints            │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│       CMSSchema Engine                 │
│  ┌──────────────┐  ┌────────────────┐  │
│  │ Content      │  │   Version      │  │
│  │  Service     │◄─┤  Management    │  │
│  └──────┬───────┘  └────────┬───────┘  │
│         │                   │          │
│         ▼                   ▼          │
│  ┌──────────────┐  ┌────────────────┐  │
│  │ JSON Schema  │  │   SDK          │  │
│  │  Validator   │  │  Generator     │  │
│  └──────────────┘  └────────────────┘  │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│   Database Layer (PostgreSQL)          │
│  ┌──────────────────────────────────┐  │
│  │ content_types                    │  │
│  │ content_entries (JSONB)          │  │
│  │ content_versions                 │  │
│  │ field_definitions                │  │
│  │ content_relations                │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## 💻 Usage Examples

### Creating Content Types

```swift
// Programmatically
try await ContentTypeService.create(
    name: "Product",
    slug: "product",
    jsonSchema: productSchema,
    on: db
)

// Via DTO
let dto = CreateContentTypeDTO(
    name: "Blog Post",
    slug: "blog-post",
    displayName: "Blog Posts",
    kind: .collection,
    jsonSchema: blogSchema,
    fieldOrder: ["title", "body", "tags"]
)

let contentType = try await ContentTypeAPI.create(dto, on: db)
```

### Managing Content Entries

```swift
// Create entry
let entry = ContentEntry(
    contentType: "blog-post",
    data: .dictionary([
        "title": .string("My First Post"),
        "body": .string("Content here..."),
        "tags": .array([.string("swift"), .string("cms")])
    ]),
    status: .draft
)

try await entry.create(on: db)

// Update entry
entry.data["published"] = .bool(true)
entry.status = .published
try await entry.save(on: db) // Creates new version

// Query entries
let posts = try await ContentEntry.query(on: db)
    .filter(\.$contentType == "blog-post")
    .filter(.sql(raw: "data->>'published' = 'true'"))
    .all()
```

### State Machine

```swift
// Define state transitions in content type
try await StateMachineService.createDefinition(
    contentTypeId: contentType.id!,
    states: ["draft", "review", "published", "archived"],
    transitions: [
        .init(from: "draft", to: "review"),
        .init(from: "review", to: "published"),
        .init(from: "published", to: "archived")
    ],
    on: db
)

// Use state machine
var entry = try await ContentEntry.find(entryId, on: db)
try await StateMachineService.transition(
    entry: entry,
    to: "published",
    userId: userId,
    on: db
)
```

### Relations

```swift
// Create relation
try await RelationService.createRelation(
    from: blogPost.id!,
    to: author.id!,
    relationType: "author",
    on: db
)

// Query related content
let author = try await RelationService.getRelated(
    from: blogPost.id!,
    relationType: "author",
    on: db
)
```

### Content Duplication

```swift
// Duplicate content type
let newType = try await ContentTypeService.duplicate(
    contentTypeId: type.id!,
    newName: "New Blog Posts",
    on: db
)

// Recursively duplicate entries
let duplicated = try await ContentService.duplicate(
    entryId: entryId,
    recursive: true, // Include relations
    on: db
)
```

## 🔗 Key Types

### ContentTypeDefinition

```swift
public final class ContentTypeDefinition: Model {
    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "slug")
    var slug: String

    @Field(key: "json_schema")
    var jsonSchema: String // JSON Schema as string

    @OptionalField(key: "field_order")
    var fieldOrder: [String]?

    @Field(key: "schema_hash")
    var schemaHash: String // SHA256 hash for versioning
}
```

### ContentEntry

```swift
public final class ContentEntry: Model {
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "content_type_id")
    var contentType: ContentTypeDefinition

    @Field(key: "data")
    var data: [String: AnyCodableValue] // JSONB storage

    @Field(key: "status")
    var status: EntryStatus

    @Field(key: "version")
    var version: Int
}
```

### ContentVersion

```swift
public final class ContentVersion: Model {
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "entry_id")
    var entry: ContentEntry

    @Field(key: "version")
    var version: Int

    @Field(key: "data")
    var data: [String: AnyCodableValue]

    @Field(key: "changed_by")
    var changedBy: String?
}
```

## 📦 Module Structure

```
Sources/CMSSchema/
├── ContentTypeService.swift      # Content type CRUD
├── ContentEntryService.swift     # Content entry CRUD
├── VersionService.swift          # Version management
├── StateMachineService.swift     # State transitions
├── RelationService.swift         # Content relations
├── DuplicateService.swift        # Duplication logic
├── SDKGenerator.swift            # Client SDK generation
├── Models/
│   ├── ContentTypeDefinition.swift
│   ├── ContentEntry.swift
│   ├── ContentVersion.swift
│   ├── ContentRelation.swift
│   └── FieldDefinition.swift
├── Migrations/
│   ├── CreateContentTypes.swift
│   ├── CreateContentEntries.swift
│   ├── CreateContentVersions.swift
│   └── CreateContentRelations.swift
└── Validation/
    ├── JSONSchemaValidator.swift # Schema validation
    ├── FieldValidator.swift      # Field-level validation
    └── ValidationRules.swift     # Custom rules
```

## 🔧 Configuration

```swift
// In configure.swift
app.cms.schema.configuration = .init(
    // Version retention policy
    versionRetentionCount: 10,

    // Version pruning settings
    versionPruningEnabled: true,
    versionPruningSchedule: .daily(hour: 2),

    // SDK generation settings
    sdkOutputDirectory: "./GeneratedSDK",
    sdkModuleName: "ContentAPI"
)
```

## 🚀 Performance Features

### Database Optimizations

```swift
// JSONB indexing for common queries
CREATE INDEX idx_content_entries_data ON content_entries
USING GIN (data jsonb_path_ops);

CREATE INDEX idx_entries_content_type_status
ON content_entries (content_type_id, status);

// Partial indexes for common filters
CREATE INDEX idx_published_entries
ON content_entries (content_type_id)
WHERE data->>'published' = 'true';
```

### Caching

```swift
// Schema caching
app.cms.schema.cache.schemas = .init(
    ttl: .minutes(5),
    maxCount: 100
)

// Entry caching for high-traffic content
app.cms.schema.cache.entries = .init(
    ttl: .minutes(1),
    maxCount: 1000
)
```

### Query Optimization

```swift
// Eager loading for relations
let entries = try await ContentEntry.query(on: db)
    .with(\.$contentType)
    .with(\.$versions)
    .filter(\.$contentType.$id == typeId)
    .all()

// Batch operations
let batch = try await ContentEntry.query(on: db)
    .filter(\.$status == .published)
    .batch(size: 100)

for try await entries in batch {
    // Process in batches
}
```

## 🧪 Testing

```swift
import XCTest
import FluentSQLiteDriver
@testable import CMSSchema

final class CMSSchemaTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        try await app.autoMigrate()
    }

    func testContentTypeCreation() async throws {
        let contentType = try await ContentTypeService.create(
            name: "Test Type",
            slug: "test",
            jsonSchema: testSchema,
            on: app.db
        )

        XCTAssertEqual(contentType.name, "Test Type")
        XCTAssertNotNil(contentType.schemaHash)
    }

    func testVersionCreation() async throws {
        var entry = try await createTestEntry()
        try await entry.save(on: app.db)

        let versions = try await ContentVersion.query(on: app.db).all()
        XCTAssertEqual(versions.count, 1)
    }
}
```

## 🤝 Integration with Other Modules

- **CMSCore**: Uses module system and hooks
- **CMSAuth**: Secures content operations
- **CMSAdmin**: Provides UI for content management
- **CMSApi**: Exposes REST and GraphQL APIs
- **CMSSearch**: Indexes content for search
- **CMSMedia**: Handles media fields in content

## 📋 Environment Variables

```bash
# Schema Configuration
CONTENT_VERSION_RETENTION=10
ENABLE_STATE_MACHINES=true

# Validation
MAX_CONTENT_TYPE_FIELDS=100
MAX_ENTRY_SIZE_BYTES=10485760  # 10MB

# Caching
SCHEMA_CACHE_TTL=300
ENTRY_CACHE_TTL=60

# SDK Generation
SDK_OUTPUT_DIRECTORY=./Generated
SDK_MODULE_NAME=ContentAPI
```

## 📚 Related Documentation

- [Content Modeling Guide](../../docs/ContentModeling.md)
- [API Reference](../CMSApi/README.md)
- [Admin UI Guide](../CMSAdmin/README.md)
- [JSON Schema Reference](https://json-schema.org/)
- [PostgreSQL JSONB](https://www.postgresql.org/docs/current/datatype-json.html)

---

**Emoji Guide**: 📐 Schema, 🎯 Validation, 📊 Database, 🔄 Versioning, 🏗️ Architecture, 🔧 Configuration, 🚀 Performance, 💾 Storage

## 🏆 Module Status

- **Stability**: Stable
- **Test Coverage**: 82%
- **Documentation**: Comprehensive
- **Dependencies**: CMSCore, CMSObjects
- **Swift Version**: 6.1+

**Maintained by**: Agent 3 (W1 models), Agent 1 (W2 engine) | **Current Version**: 2.0.0
