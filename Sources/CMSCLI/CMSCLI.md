# CMSCLI Module Documentation

The CMSCLI module provides a comprehensive command-line interface for SwiftCMS management tasks including server management, database operations, SDK generation, Strapi migration, and content export.

## 📦 Module Overview

The CMSCLI module is the command-line entry point for SwiftCMS, powered by Apple's swift-argument-parser framework. It provides developers with tools to manage the CMS lifecycle, generate client SDKs, migrate from other CMS platforms, and export content for offline use.

**Executable Target:** `cms` (`Sources/CMSCLI/`)
**Dependencies:** ArgumentParser, Vapor, Fluent, CMSCore, CMSSchema, CMSObjects

## 🖥️ Command Structure

```bash
cms <command> [options] [arguments]
```

### Available Commands

1. **[`serve`](#serve-command)** - Start the SwiftCMS server
2. **[`migrate`](#migrate-command)** - Run database migrations
3. **[`seed`](#seed-command)** - Seed database with default data
4. **[`generate-sdk`](#generate-sdk-command)** - Generate typed client SDKs
5. **[`import-strapi`](#import-strapi-command)** - Import from Strapi projects
6. **[`export`](#export-command)** - Export content as static JSON bundles

---

## 🚀 Serve Command

### 🖥️ **`cms serve` - Start SwiftCMS Server**

Starts the SwiftCMS HTTP server with configurable hostname and port.

## Usage
```bash
cms serve [--hostname <host>] [--port <number>]
```

## Options
- `--hostname <host>` - Server bind address (default: `0.0.0.0`)
- `--port <number>` - Server port (default: `8080`)

## Examples
```bash
# Start on default address and port
cms serve

# Start on custom host and port
cms serve --hostname localhost --port 3000

# Start on production server
cms serve --hostname 0.0.0.0 --port 443
```

## 📊 Output
```
Starting SwiftCMS on 0.0.0.0:8080
Server startup logs... ✓
```

## 🔌 Integration
The serve command delegates to Vapor's built-in server infrastructure. In production, it automatically:
- Loads configuration from environment variables
- Initializes middleware pipeline
- Registers routes from all modules
- Connects to database and Redis
- Starts HTTP/HTTPS server

---

## 🔄 Migrate Command

### 🖥️ **`cms migrate` - Database Migration Management**

Runs pending database migrations or reverts existing ones.

## Usage
```bash
cms migrate [--revert] [--yes]
```

## Options
- `--revert` - Revert the last migration batch
- `--yes` - Auto-confirm operations without prompting

## Examples
```bash
# Run pending migrations
cms migrate

# Revert last migration batch
cms migrate --revert

# Auto-confirm migration run
cms migrate --yes
```

## 📊 Output
### Success - Run Migrations
```
Running pending migrations...
✓ CreateContentTypeDefinitions
✓ CreateContentEntries
✓ CreateContentVersions
✓ CreateUsers
✓ CreateRoles
✓ SeedDefaultRoles

Migration complete: 6 migrations run successfully
```

### Success - Revert Migrations
```
Reverting last migration...
✓ Reverted SeedDefaultRoles
✓ Reverted CreateRoles
✓ Reverted CreateUsers
✓ Reverted CreateContentVersions
✓ Reverted CreateContentEntries
✓ Reverted CreateContentTypeDefinitions

Reverted 6 migrations successfully
```

## ⚠️ Error Cases
```
Error: Database connection failed
Reason: Unable to connect to PostgreSQL at localhost:5432

Fix: Check DATABASE_URL environment variable or verify PostgreSQL is running
```

---

## 🌱 Seed Command

### 🖥️ **`cms seed` - Seed Database with Default Data**

Populates the database with default roles and an admin user for initial setup.

## Usage
```bash
cms seed
```

## 📊 Output
```
Seeding database with default roles and admin user...
✓ Created role: Super Admin (super-admin)
✓ Created role: Editor (editor)
✓ Created role: Author (author)
✓ Created role: Reader (reader)

✓ Created admin user:
  Email: admin@swiftcms.local
  Password: change-me-123

⚠️  IMPORTANT: Change the admin password immediately after first login!

Database seeded successfully in 0.234s
```

## 🔐 Default Credentials
- **Admin Email**: `admin@swiftcms.local`
- **Admin Password**: `change-me-123` (auto-generated)
- **Roles**: Super Admin, Editor, Author, Reader

## 🛡️ Security Note
The seed command is idempotent - it won't create duplicate entries if run multiple times. However, it will display credentials each time. Always change default passwords in production environments!

---

## 🔧 Generate SDK Command

### 🖥️ **`cms generate-sdk` - Generate Typed Client SDKs**

Generates type-safe client SDKs in Swift or TypeScript from content type definitions.

## Usage
```bash
cms generate-sdk <language> [--output <path>] [--force]
cms generate-sdk swift [--output <path>]
cms generate-sdk typescript [--output <path>]
```

## Arguments
- `<language>` - Target language: `swift` or `typescript` (required)

## Options
- `--output <path>` - Output directory (default: `./ClientSDK`)
- `--force` - Override schema hash cache and force regeneration

## Examples
```bash
# Generate Swift SDK in default directory
cms generate-sdk swift

# Generate TypeScript definitions in custom path
cms generate-sdk typescript --output ./frontend/src/cmstypes

# Force regeneration without schema checking
cms generate-sdk swift --output ./SDK --force
```

## 📊 Output - Swift SDK
```
⚡ Checking for schema changes...
✓ Schema cache valid (no changes detected)

Generating Swift SDK to ./ClientSDK...
✓ Created Package.swift
✓ Created Sources/SwiftCMSClient.swift
✓ Generated 5 content type models:
  - ArticleClient (article)
  - PageClient (page)
  - ProductClient (product)
  - EventClient (event)
  - AuthorClient (author)

Swift SDK generated successfully at ./ClientSDK
Package ready for:
  → iOS 15.0+
  → macOS 13.0+
```

## 📊 Output - TypeScript SDK
```
⚡ Checking for schema changes...
ℹ New content type 'book-review' detected
⚠ Schema for 'article' has changed. Regenerate SDK.

Generating TypeScript definitions to ./ClientSDK...
✓ Created swiftcms.d.ts
✓ Generated interfaces for 6 content types
✓ Added JSDoc documentation
✓ Cached schema hashes at ./ClientSDK/.schemahash

TypeScript definitions generated at ./ClientSDK/swiftcms.d.ts
```

## 📦 Generated Swift SDK Structure

### Package.swift
```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SwiftCMSClient",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "SwiftCMSClient", targets: ["SwiftCMSClient"]),
    ],
    targets: [
        .target(name: "SwiftCMSClient", path: "Sources"),
    ]
)
```

### Generated Model Example
```swift
/// Auto-generated from SwiftCMS content type: article
public struct Article: Codable, Sendable, Identifiable {
    public let id: UUID
    public let status: String
    public let createdAt: Date?
    public let updatedAt: Date?
    public let title: String
    public let slug: String?
    public let content: String?
    public let author: String?
    public let publishedAt: Date?
}

/// Typed API client for article content type.
public actor ArticleClient {
    let baseURL: URL
    let session: URLSession

    public func list(page: Int = 1, perPage: Int = 25) async throws -> PaginatedResponse<Article>
    public func get(id: UUID) async throws -> Article
    public func create(_ entry: Article) async throws -> Article
    public func delete(id: UUID) async throws
}
```

## 🔍 Schema Hash Caching
The SDK generator uses schema hash caching to avoid unnecessary regeneration:

- Caches hashes of all content type schemas
- Compares current schemas against cached version
- Only regenerates when changes are detected
- Cache stored at `<output-dir>/.schemahash`

**Cache Structure:**
```json
{
  "version": "1",
  "hashes": {
    "article": "abc123...",
    "page": "def456...",
    "product": "ghi789..."
  }
}
```

## 🧩 Advanced Features

### Content Type Models
The generator creates actor-based clients for each content type with full CRUD operations:

```swift
let client = ArticleClient(baseURL: URL(string: "https://api.mycms.com")!)

// List with pagination
let articles = try await client.list(page: 1, perPage: 10)

// Get single entry
let article = try await client.get(id: articleID)

// Create new entry
let newArticle = Article(
    id: UUID(),
    status: "draft",
    title: "My Article",
    // ... other fields
)
try await client.create(newArticle)

// Delete entry
try await client.delete(id: articleID)
```

### TypeScript Interface Example
```typescript
export interface Article {
  id: string;
  status: string;
  createdAt: string | null;
  updatedAt: string | null;
  title: string;
  slug?: string;
  content?: string;
  author?: string;
  publishedAt?: string;
}
```

---

## 📥 Import Strapi Command

### 🖥️ **`cms import-strapi` - Import from Strapi Projects**

Parses Strapi project files and migrates content types and data to SwiftCMS.

## Usage
```bash
cms import-strapi --path <project-path> [--db-url <url>] [--dry-run] [--verbose]
```

## Options
- `--path <path>` - Path to Strapi project root (required)
- `--db-url <url>` - Database URL (default: env `DATABASE_URL`)
- `--dry-run` - Preview import without making changes
- `--verbose` - Enable verbose logging

## Examples
```bash
# Basic import with environment database
cms import-strapi --path /projects/my-strapi-app

# With explicit database URL
cms import-strapi \
  --path /projects/my-strapi-app \
  --db-url postgres://user:pass@localhost:5432/swiftcms

# Preview changes only
cms import-strapi --path /projects/my-strapi-app --dry-run --verbose
```

## 📊 Output - Schema Import
```
Importing from Strapi project at: /projects/my-strapi-app

🔄 Initializing Vapor application...
⚡ Connected to PostgreSQL database

🔍 Found 12 content types:
  - Article (8 fields)
  - Page (6 fields)
  - Product (15 fields)
  - Category (4 fields)
  - Author (7 fields)
  - Tag (3 fields)
  - Navigation (5 fields)
  - Menu Item (6 fields)
  - User (9 fields)
  - Role (3 fields)
  - Upload File (10 fields)
  - Upload Folder (4 fields)

📦 Creating content type definitions...
✓ Created: Article (blog-post)
✓ Created: Page (page)
✓ Created: Product (product)
✓ Created: Category (category)
✓ Created: Author (author)
✓ Created: Tag (tag)
  ✓ Created: Navigation (navigation)
  ✓ Created: Menu Item (menu-item)
  ⚠ Failed to create User: Relation mapping not supported yet
ℹ Skipped: Role (Already exists)

  Created 9/12 content type definitions

📥 Importing content data...
  Processing content type: article
✓ Imported 47 entries from export.json
  Processing content type: page
✓ Imported 12 entries from export.json
  Processing content type: product
✓ Imported 156 entries (3 files)
  Processing content type: author
✓ Imported 8 entries from export.json

Import complete!
✓ Successfully imported 223 content entries
✓ Preserved original Strapi IDs for data integrity
✓ Mapped Strapi field types to SwiftCMS equivalents

⚠ This was a dry run. No changes were made to the database.
Run without --dry-run to apply changes.
```

## 🔄 Strapi Type Mapping

### Supported Field Types
| Strapi Type | SwiftCMS Type | Notes |
|-------------|---------------|-------|
| `string` | `shortText` | Basic text field |
| `text` | `longText` | Long text, no formatting |
| `richtext` | `richText` | Rich text with formatting |
| `integer` | `integer` | Whole numbers |
| `biginteger` | `integer` | Large integers |
| `float` | `decimal` | Floating point |
| `decimal` | `decimal` | Precise decimal numbers |
| `boolean` | `boolean` | True/false values |
| `date` | `dateTime` | Date only |
| `datetime` | `dateTime` | Date and time |
| `time` | `shortText` | Time as string |
| `email` | `email` | Email validation |
| `enumeration` | `enumeration` | Dropdown/select field |
| `json` | `json` | JSON data |
| `media` | `media` | File/image uploads |
| `relation` | `relationHasOne` | Relations (limited support) |
| `uid` | `shortText` | Unique identifier |
| `password` | `shortText` | Password field |

### ⚠️ Limitations
- Complex relations (many-to-many with join tables) are flattened
- Component fields are imported as JSON objects
- Dynamic zones have limited support
- Media files are imported by URL reference only

## 📋 Import Process

### Phase 1: Schema Parsing
1. Scans `src/api/**/content-types/**/schema.json` files
2. Extracts field definitions and metadata
3. Maps Strapi types to SwiftCMS equivalents
4. Validates schema integrity

### Phase 2: Content Type Creation
1. Checks for existing content types (skips duplicates)
2. Builds JSON schema for each content type
3. Creates `ContentTypeDefinition` records
4. Maintains field order and validation requirements

### Phase 3: Data Import
1. Scans `data/**/export.json` files
2. Maps Strapi field formats to SwiftCMS
3. Preserves original UUID IDs for data integrity
4. Creates `ContentEntry` records with proper status

### Phase 4: Error Handling
- Continues on non-critical errors
- Logs detailed error information
- Tracks import success/failure counts

## 🗂️ Expected Strapi Project Structure
```
my-strapi-app/
├── src/
│   ├── api/
│   │   ├── article/
│   │   │   └── content-types/
│   │   │       └── article/
│   │   │           └── schema.json
│   │   └── page/
│   │       └── content-types/
│   │           └── page/
│   │               └── schema.json
│   └── components/
│       └── shared/
│           └── rich-text.json
└── data/
    ├── article/
    │   └── export.json
    └── page/
        └── export.json
```

---

## 📦 Export Command

### 🖥️ **`cms export` - Export Content as Static JSON**

Exports published content as static JSON bundles for offline iOS apps or static sites.

## Usage
```bash
cms export [--format <format>] [--output <path>] [--locale <locale>] [--since <timestamp>]
```

## Options
- `--format <format>` - Output format (default: `static-json`)
- `--output <path>` - Output directory (default: `./bundles`)
- `--locale <locale>` - Locale to export (default: `en-US`)
- `--since <timestamp>` - Only export entries modified after ISO 8601 timestamp

## Examples
```bash
# Full export
cms export

# Incremental export (since last run)
cms export --since 2024-01-15T10:30:00Z

# Export specific locale
cms export --locale es-ES --output ./spanish-bundles

# Continuous integration with timestamp
cms export --since $(cat .last-export) --output ./ci-bundles
```

## 📊 Output
```
Exporting published content...
  Format: static-json
  Output: ./bundles
  Locale: en-US
  Since: 2024-01-15T10:30:00Z (incremental)

Creating bundle structure...
✓ bundles/
✓ bundles/en-US/
✓ bundles/en-US/article/
✓ bundles/en-US/page/
✓ bundles/en-US/product/

Exporting entries:
  article: 47 entries
✓ article/welcome-to-swiftcms.json
✓ article/getting-started-guide.json
✓ article/advanced-features.json
...
  page: 12 entries
✓ page/home.json
✓ page/about.json
✓ page/contact.json
...
  product: 156 entries
✓ product/product-001.json
✓ product/product-002.json
...

Generated bundle manifest: bundles/ExportManifest.json

Export complete!
✓ 215 entries exported
✓ 3.2 MB total size
✓ Export manifest written to bundles/ExportManifest.json

Next steps:
1. Sync bundles to CDN: aws s3 sync ./bundles s3://my-cms-bundles/
2. Update app with new manifest
3. Clear CDN cache if needed
```

## 📦 Output Structure
```
bundles/
├── ExportManifest.json
└── en-US/
    ├── article/
    │   ├── welcome-to-swiftcms.json
    │   ├── getting-started-guide.json
    │   └── ...
    ├── page/
    │   ├── home.json
    │   ├── about.json
    │   └── ...
    └── product/
        ├── product-001.json
        ├── product-002.json
        └── ...
```

## 📋 ExportManifest.json Structure
```json
{
  "exportedAt": "2024-01-15T12:34:56Z",
  "locale": "en-US",
  "format": "static-json",
  "incremental": true,
  "entries": [
    {
      "contentType": "article",
      "slug": "welcome-to-swiftcms",
      "hash": "aBcDeFgH"
    },
    {
      "contentType": "product",
      "slug": "product-001",
      "hash": "xYz12345"
    }
  ],
  "totalEntries": 215,
  "totalSize": "3.2 MB"
}
```

## 🎯 Use Cases

### Offline iOS Apps
```swift
// Load article from bundle
if let url = Bundle.main.url(forResource: "welcome-to-swiftcms", withExtension: "json", subdirectory: "articles") {
    let data = try Data(contentsOf: url)
    let article = try JSONDecoder().decode(Article.self, from: data)
}
```

### Static Site Generation
```javascript
// Build static pages from bundles
const manifest = require('./bundles/ExportManifest.json');
manifest.entries.forEach(entry => {
    const content = require(`./bundles/en-US/${entry.contentType}/${entry.slug}.json`);
    // Generate HTML files
});
```

### CDN Distribution
```bash
# Sync to S3 for CDN distribution
aws s3 sync ./bundles s3://my-cms-cdn/bundles/

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id EDFDVBD6EXAMPLE \
  --paths "/bundles/*"
```

---

## 🔧 Configuration

### Environment Variables

The CMSCLI respects standard SwiftCMS environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `nil` (uses SQLite in dev) |
| `REDIS_URL` | Redis connection for caching | `nil` |
| `JWT_SECRET` | Secret for JWT signing | Required in production |
| `LOG_LEVEL` | Logging verbosity | `info` |

### Database Configuration
```bash
# Development (SQLite in-memory)
export DATABASE_URL=""

# Testing (PostgreSQL)
export DATABASE_URL="postgres://test:test@localhost:5432/cms_test"

# Production
export DATABASE_URL="postgres://cms:<password>@db.swiftcms.io:5432/cms_prod"
```

## 🚀 Building and Running

### Build CLI from Source
```bash
# Build all targets
swift build

# Build only CLI
swift build --target CMSCLI

# Create release build
swift build -c release --target CMSCLI
```

### Run Directly with Swift
```bash
# From repo root
swift run cms --help

# With environment
DATABASE_URL="postgres://..." swift run cms migrate
```

### Install System-wide
```bash
# Build release
swift build -c release --target CMSCLI

# Copy to bin
cp .build/release/cms /usr/local/bin/

# Test installation
cms --help
```

## 📚 Error Handling

All CLI commands follow consistent error handling patterns:

### Exit Codes
- `0` - Success
- `1` - General error
- `2` - Invalid arguments
- `3` - Database error
- `4` - File system error

### Error Messages
```error
Error: Invalid language 'go'
Reason: Supported languages are 'swift' and 'typescript'

Usage: cms generate-sdk <language> [--output <output>]

See 'cms generate-sdk --help' for more information.
```

### Verbose Mode
Add `--verbose` to any command for detailed debugging:
```bash
cms import-strapi --path ./strapi --verbose
```

## 🔗 Integration Examples

### CI/CD Pipeline
```yaml
# .github/workflows/deploy.yml
- name: Run migrations
  run: |
    export DATABASE_URL="${{ secrets.DATABASE_URL }}"
    cms migrate --yes

- name: Generate SDK
  run: |
    cms generate-sdk typescript --output ./frontend/src/cms
    git add ./frontend/src/cms/swiftcms.d.ts
```

### Docker
```dockerfile
FROM swift:5.10
WORKDIR /app
COPY . .
RUN swift build -c release

CMD ["cms", "serve", "--hostname", "0.0.0.0", "--port", "8080"]
```

### Shell Alias
```bash
# Add to ~/.zshrc or ~/.bashrc
alias cms-dev='DATABASE_URL=postgres://dev:dev@localhost/cms_dev cms'
alias cms-prod='cms --hostname 0.0.0.0'
```

---

**📖 Related Documentation:**
- [CMSCore Documentation](./CMSCore.md) - Core CMS functionality
- [CMSSchema Documentation](./CMSSchema.md) - Database schemas
- [CMSObjects Documentation](./CMSObjects.md) - Shared DTOs

**🛡️ Security Note:** Never commit generated SDKs with API keys or sensitive data. Always add `.schemahash` to `.gitignore`.
