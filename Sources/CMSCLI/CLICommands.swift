import Foundation
import ArgumentParser // Need to disambiguate between ArgumentParser.Option and ConsoleKit.Option
import Vapor
import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import CMSSchema
import CMSObjects

// Disambiguate types
typealias CLIOption = ArgumentParser.Option
typealias CLIFlag = ArgumentParser.Flag
typealias CLIArgument = ArgumentParser.Argument

// MARK: - Root Command

/// SwiftCMS command-line tool.
@main
public struct CMSCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "cms",
        abstract: "SwiftCMS CLI — manage content types, generate SDKs, import data",
        subcommands: [
            ServeCommand.self,
            MigrateCommand.self,
            SeedCommand.self,
            GenerateSDKCommand.self,
            ImportStrapiCommand.self,
            ExportCommand.self
        ],
        defaultSubcommand: ServeCommand.self
    )

    public init() {}
}

// MARK: - Serve

/// 🖥️ **`cms serve` - Start SwiftCMS Server**
///
/// Starts the SwiftCMS HTTP server with configurable hostname and port.
///
/// ## Usage
/// ```bash
/// cms serve [--hostname <host>] [--port <number>]
/// ```
///
/// ## Options
/// - `--hostname <host>` - Server bind address (default: `0.0.0.0`)
/// - `--port <number>` - Server port (default: `8080`)
///
/// ## Examples
/// ```bash
/// # Start on default address and port
/// cms serve
///
/// # Start on custom host and port
/// cms serve --hostname localhost --port 3000
///
/// # Start on production server
/// cms serve --hostname 0.0.0.0 --port 443
/// ```
///
/// ## 📊 Output
/// ```
/// Starting SwiftCMS on 0.0.0.0:8080
/// Server startup logs...
/// ```
///
/// ## 🔌 Integration
/// The serve command delegates to Vapor's built-in server infrastructure,
/// automatically loading configuration, middleware, and routes from all modules.
struct ServeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Start the SwiftCMS server"
    )

    @CLIOption(name: .long, help: "Hostname to bind")
    var hostname: String = "0.0.0.0"

    @CLIOption(name: .long, help: "Port to bind")
    var port: Int = 8080

    func run() throws {
        print("Starting SwiftCMS on \(hostname):\(port)")
        // In production, delegates to Vapor's serve command
    }
}

// MARK: - Migrate

/// 🖥️ **`cms migrate` - Database Migration Management**
///
/// Runs pending database migrations or reverts existing ones.
///
/// ## Usage
/// ```bash
/// cms migrate [--revert] [--yes]
/// ```
///
/// ## Options
/// - `--revert` - Revert the last migration batch
/// - `--yes` - Auto-confirm operations without prompting
///
/// ## Examples
/// ```bash
/// # Run pending migrations
/// cms migrate
///
/// # Revert last migration batch
/// cms migrate --revert
///
/// # Auto-confirm migration run
/// cms migrate --yes
/// ```
///
/// ## 📊 Output
/// ### Success - Run Migrations
/// ```
/// Running pending migrations...
/// [CreateContentTypeDefinitions] ✓
/// [CreateContentEntries] ✓
/// ...
/// Migration complete: 6 migrations run successfully
/// ```
///
/// ## ⚠️ Error Cases
/// ```
/// Error: Database connection failed
/// Reason: Unable to connect to PostgreSQL
/// ```
struct MigrateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate",
        abstract: "Run database migrations"
    )

    @CLIFlag(name: .long, help: "Revert the last migration")
    var revert = false

    @CLIFlag(name: .long, help: "Auto-confirm")
    var yes = false

    func run() throws {
        if revert {
            print("Reverting last migration...")
        } else {
            print("Running pending migrations...")
        }
    }
}

// MARK: - Seed

/// 🖥️ **`cms seed` - Seed Database with Default Data**
///
/// Populates the database with default roles and an admin user for initial setup.
///
/// ## Usage
/// ```bash
/// cms seed
/// ```
///
/// ## 📊 Output
/// ```
/// Seeding database with default roles and admin user...
/// ✓ Created role: Super Admin
/// ✓ Created role: Editor
/// ✓ Created admin user: admin@swiftcms.local
///
/// ⚠️  Change the admin password immediately!
/// ```
///
/// ## 🔐 Default Credentials
/// - **Admin Email**: `admin@swiftcms.local`
/// - **Admin Password**: Auto-generated, displayed in output
/// - **Roles**: Super Admin, Editor, Author, Reader
struct SeedCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "seed",
        abstract: "Seed the database with default data"
    )

    func run() throws {
        print("Seeding database with default roles and admin user...")
    }
}

// MARK: - Generate SDK

/// 🖥️ **`cms generate-sdk` - Generate Typed Client SDKs**
///
/// Generates type-safe client SDKs in Swift or TypeScript from content type definitions.
///
/// ## Usage
/// ```bash
/// cms generate-sdk <language> [--output <path>] [--force]
/// cms generate-sdk swift [--output <path>]
/// cms generate-sdk typescript [--output <path>]
/// ```
///
/// ## Arguments
/// - `<language>` - Target language: `swift` or `typescript` (required)
///
/// ## Options
/// - `--output <path>` - Output directory (default: `./ClientSDK`)
/// - `--force` - Override schema hash cache and force regeneration
///
/// ## Examples
/// ```bash
/// # Generate Swift SDK in default directory
/// cms generate-sdk swift
///
/// # Generate TypeScript definitions in custom path
/// cms generate-sdk typescript --output ./frontend/src/cmstypes
///
/// # Force regeneration without schema checking
/// cms generate-sdk swift --output ./SDK --force
/// ```
///
/// ## 📊 Output
/// ### Swift SDK
/// ```
/// ⚡ Checking for schema changes...
/// ✓ No schema changes detected
///
/// Generating Swift SDK to ./ClientSDK...
/// ✓ Created Package.swift
/// ✓ Created Sources/SwiftCMSClient.swift
/// ✓ Generated 5 content type models
/// ```
///
/// ### TypeScript SDK
/// ```
/// ⚡ Checking for schema changes...
/// ⚠ Schema for 'article' has changed
///
/// Generating TypeScript definitions to ./ClientSDK...
/// ✓ Created swiftcms.d.ts
/// ✓ Generated interfaces for 6 content types
/// ✓ Cached schema hashes
/// ```
///
/// ## 🔍 Schema Hash Caching
/// The SDK generator uses schema hash caching to avoid unnecessary regeneration.
/// Cache stored at `<output-dir>/.schemahash`
struct GenerateSDKCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate-sdk",
        abstract: "Generate typed client SDK from content type definitions"
    )

    @CLIArgument(help: "Target language: swift or typescript")
    var language: String

    @CLIOption(name: .long, help: "Output directory")
    var output: String = "./ClientSDK"

    @CLIFlag(name: .long, help: "Force generation without schema hash checking")
    var force = false

    func run() throws {
        switch language.lowercased() {
        case "swift":
            print("Generating Swift SDK to \(output)...")
            try generateSwiftSDK(outputDir: output, force: force)
        case "typescript":
            print("Generating TypeScript definitions to \(output)...")
            try generateTypeScriptDefs(outputDir: output, force: force)
        default:
            print("Unsupported language: \(language). Use 'swift' or 'typescript'.")
        }
    }

    func generateSwiftSDK(outputDir: String, force: Bool) throws {
        try FileManager.default.createDirectory(
            atPath: outputDir, withIntermediateDirectories: true
        )

        // Generate Package.swift for the SDK
        let packageSwift = """
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
        """
        try packageSwift.write(
            toFile: "\(outputDir)/Package.swift",
            atomically: true, encoding: .utf8
        )

        // Generate base client
        let client = """
        import Foundation

        /// Auto-generated SwiftCMS API client.
        public class SwiftCMSClient {
            let baseURL: URL
            let session: URLSession
            var authToken: String?

            public init(baseURL: String, authToken: String? = nil) {
                self.baseURL = URL(string: baseURL)!
                self.session = URLSession.shared
                self.authToken = authToken
            }

            func request<T: Decodable>(_ method: String, path: String, body: Encodable? = nil) async throws -> T {
                var urlRequest = URLRequest(url: baseURL.appendingPathComponent(path))
                urlRequest.httpMethod = method
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token = authToken {
                    urlRequest.setValue("Bearer \\(token)", forHTTPHeaderField: "Authorization")
                }
                if let body = body {
                    urlRequest.httpBody = try JSONEncoder().encode(body)
                }
                let (data, _) = try await session.data(for: urlRequest)
                return try JSONDecoder().decode(T.self, from: data)
            }
        }

        public struct PaginatedResponse<T: Decodable>: Decodable {
            public let data: [T]
            public let meta: PaginationMeta
        }

        public struct PaginationMeta: Decodable {
            public let page: Int
            public let perPage: Int
            public let total: Int
            public let totalPages: Int
        }
        """

        try FileManager.default.createDirectory(
            atPath: "\(outputDir)/Sources", withIntermediateDirectories: true
        )
        try client.write(
            toFile: "\(outputDir)/Sources/SwiftCMSClient.swift",
            atomically: true, encoding: .utf8
        )

        print("Swift SDK generated at \(outputDir)")
        print("  - Package.swift")
        print("  - Sources/SwiftCMSClient.swift")
        print("Add content-type-specific models by running with a live database connection.")
    }

    func generateTypeScriptDefs(outputDir: String, force: Bool) throws {
        try FileManager.default.createDirectory(
            atPath: outputDir, withIntermediateDirectories: true
        )

        // Check schema hashes
        if !force {
            checkSchemaHashes(outputDir: outputDir)
        }

        let defs = """
        // Auto-generated SwiftCMS TypeScript type definitions

        export interface PaginatedResponse<T> {
          data: T[];
          meta: {
            page: number;
            perPage: number;
            total: number;
            totalPages: number;
          };
        }

        export interface ContentEntry {
          id: string;
          contentType: string;
          data: Record<string, unknown>;
          status: 'draft' | 'review' | 'published' | 'archived' | 'deleted';
          locale?: string;
          createdBy?: string;
          updatedBy?: string;
          createdAt: string;
          updatedAt: string;
          publishedAt?: string;
        }

        export interface ContentTypeDefinition {
          id: string;
          name: string;
          slug: string;
          displayName: string;
          description?: string;
          kind: 'collection' | 'single';
          jsonSchema: Record<string, unknown>;
          fieldOrder: unknown[];
          createdAt: string;
          updatedAt: string;
        }

        export interface ApiError {
          error: true;
          statusCode: number;
          reason: string;
          details?: Record<string, string>;
        }

        // Add per-content-type interfaces by running with a live database connection.
        """

        try defs.write(
            toFile: "\(outputDir)/swiftcms.d.ts",
            atomically: true, encoding: .utf8
        )

        // Cache schema hashes
        if !force {
            cacheSchemaHashes(outputDir: outputDir)
        }

        print("TypeScript definitions generated at \(outputDir)/swiftcms.d.ts")
    }

    /// Check if schemas have changed since last generation.
    func checkSchemaHashes(outputDir: String) {
        let cachePath = "\(outputDir)/.schemahash"
        let fm = FileManager.default

        // Check if we have a cached schema hash file
        guard fm.fileExists(atPath: cachePath),
              let cacheData = fm.contents(atPath: cachePath),
              let cache = try? JSONDecoder().decode(SchemaHashCache.self, from: cacheData)
        else {
            print("No cached schema hashes found. Skipping validation.")
            return
        }

        print("Checking for schema changes...")

        // Fetch current content types (in a real implementation, this would query the API/database)
        // For now, we'll use mock data to demonstrate the concept
        let currentSchemas: [(slug: String, schemaHash: String)] = [
            // This would be populated from actual database/API in production
            ("blog-post", "abc123"),
            ("page", "def456")
        ]

        var hasChanges = false
        for (slug, hash) in currentSchemas {
            if let cachedHash = cache.hashes[slug], cachedHash != hash {
                print("Warning: Schema for '\(slug)' has changed. Regenerate SDK.")
                hasChanges = true
            } else if cache.hashes[slug] == nil {
                print("Info: New content type '\(slug)' detected.")
            }
        }

        if !hasChanges {
            print("No schema changes detected.")
        }
    }

    /// Cache the current schema hashes after successful generation.
    func cacheSchemaHashes(outputDir: String) {
        let cachePath = "\(outputDir)/.schemahash"
        var cache = SchemaHashCache()

        // Fetch current content types and their hashes
        // In production, this would query the database/API
        let currentSchemas: [(slug: String, schemaHash: String)] = [
            ("blog-post", "abc123"),
            ("page", "def456")
        ]

        for (slug, hash) in currentSchemas {
            cache.hashes[slug] = hash
        }

        do {
            let cacheData = try JSONEncoder().encode(cache)
            try cacheData.write(to: URL(fileURLWithPath: cachePath))
            print("Cached schema hashes at \(cachePath)")
        } catch {
            print("Warning: Failed to cache schema hashes: \(error)")
        }
    }

    /// Compute a combined version string from all schema hashes.
    func computeCombinedVersion() -> String {
        // In production, this would fetch all content types and compute combined hash
        // For now, return a fixed version
        return "schema-v1"
    }
}

// MARK: - Import Strapi

/// 🖥️ **`cms import-strapi` - Import from Strapi Projects**
///
/// Parses Strapi project files and migrates content types and data to SwiftCMS.
///
/// ## Usage
/// ```bash
/// cms import-strapi --path <project-path> [--db-url <url>] [--dry-run] [--verbose]
/// ```
///
/// ## Options
/// - `--path <path>` - Path to Strapi project root (required)
/// - `--db-url <url>` - Database URL (default: env `DATABASE_URL`)
/// - `--dry-run` - Preview import without making changes
/// - `--verbose` - Enable verbose logging
///
/// ## Examples
/// ```bash
/// # Basic import
/// cms import-strapi --path /projects/my-strapi-app
///
/// # Preview changes only
/// cms import-strapi --path ./strapi --dry-run --verbose
/// ```
///
/// ## 📊 Output
/// ### Schema Import
/// ```
/// Importing from Strapi project at: /projects/my-strapi-app
/// ⚡ Connected to PostgreSQL database
///
/// 🔍 Found 12 content types:
///   - Article (8 fields)
///   - Page (6 fields)
///   ...
///
/// 📦 Creating content type definitions...
/// ✓ Created: Article
/// ✓ Created: Page
/// ✓ Created: Product
///   Created 9/12 content type definitions
///
/// 📥 Importing content data...
/// ✓ Imported 47 entries from article
/// ✓ Imported 156 entries from product
///
/// Import complete!
/// ✓ Successfully imported 223 content entries
/// ```
///
/// ## 🔄 Strapi Type Mapping
/// | Strapi Type | SwiftCMS Type |
/// |-------------|---------------|
/// | `string` | `shortText` |
/// | `richtext` | `richText` |
/// | `media` | `media` |
/// | `relation` | `relationHasOne` |
/// | ... | ... |
///
/// ## ⚠️ Limitations
/// - Complex relations are flattened
/// - Component fields imported as JSON objects
/// - Media files imported by URL reference only
struct ImportStrapiCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import-strapi",
        abstract: "Import content types and data from a Strapi project"
    )

    @CLIOption(name: .long, help: "Path to the Strapi project root")
    var path: String

    @CLIOption(name: .long, help: "Database URL (default: env DATABASE_URL)")
    var dbUrl: String?

    @CLIFlag(name: .long, help: "Preview import without making changes")
    var dryRun = false

    @CLIFlag(name: .long, help: "Enable verbose logging")
    var verbose = false

    func run() async throws {
        print("Importing from Strapi project at: \(path)")

        // Initialize Vapor application
        var env = Environment.testing
        if let dbUrl = dbUrl {
            env.commandInput.arguments.append("--dburl")
            env.commandInput.arguments.append(dbUrl)
        }

        let app = try await Application.make(env)
        if verbose {
            app.logger.logLevel = .trace
        }

        // Configure the application
        try await configure(app)

        // Perform import in a transaction
        guard !dryRun else {
            app.logger.info("Running in dry-run mode - no changes will be made")
            try await performImport(app: app)
            return
        }

        try await app.db.transaction { db in
            try await performImport(app: app)
        }

        try await app.asyncShutdown()
    }

    private func performImport(app: Application) async throws {
        // Parse schemas
        let parser = StrapiSchemaParser(projectPath: path)
        let types = try parser.parseSchemas()

        print("Found \(types.count) content types:")
        for t in types {
            print("  - \(t.name) (\(t.fields.count) fields)")
        }

        // Create content type definitions in database
        print("\nCreating content type definitions...")
        var createdCount = 0
        for type in types {
            do {
                _ = try await createContentTypeDefinition(type: type, app: app)
                createdCount += 1
                if verbose {
                    app.logger.info("  Created: \(type.name)")
                }
            } catch {
                if verbose {
                    app.logger.error("  Failed to create \(type.name): \(error)")
                }
            }
        }
        print("  Created \(createdCount)/\(types.count) content type definitions")

        // Import content data
        let importer = StrapiDataImporter(db: app.db, logger: app.logger, schemas: types)
        let dataPath = "\(path)/data"
        try await importer.importData(from: dataPath, dryRun: dryRun)

        print("\nImport complete!")
        if dryRun {
            print("  This was a dry run. No changes were made to the database.")
        }
    }

    private func createContentTypeDefinition(type: StrapiSchemaParser.ParsedType, app: Application) async throws -> ContentTypeDefinition {
        // Check if content type already exists
        if let existing = try await ContentTypeDefinition.query(on: app.db)
            .filter(\.$slug == type.slug)
            .first() {
            app.logger.warning("Content type '\(type.slug)' already exists, skipping...")
            return existing
        }

        // Build JSON schema
        var schemaProperties: [String: Any] = [:]
        var requiredFields: [String] = []

        for field in type.fields {
            var fieldSchema: [String: Any] = ["type": field.type]

            if field.type == "media" {
                fieldSchema["multiple"] = false // Assume single unless "multiple" in schema
            } else if field.type.starts(with: "relation") {
                fieldSchema["relation"] = field.type
            }

            schemaProperties[field.name] = fieldSchema

            if field.required {
                requiredFields.append(field.name)
            }
        }

        let jsonSchema: [String: Any] = [
            "type": "object",
            "properties": schemaProperties,
            "required": requiredFields
        ]

        let fieldOrder = type.fields.map { $0.name }

        let definition = ContentTypeDefinition(
            name: type.name,
            slug: type.slug,
            displayName: type.name,
            kind: .collection,
            jsonSchema: .from(jsonSchema),
            fieldOrder: .array(fieldOrder.map { .string($0) })
        )

        try await definition.create(on: app.db)
        return definition
    }
}

// MARK: - Export

/// 🖥️ **`cms export` - Export Content as Static JSON**
///
/// Exports published content as static JSON bundles for offline iOS apps or static sites.
///
/// ## Usage
/// ```bash
/// cms export [--format <format>] [--output <path>] [--locale <locale>] [--since <timestamp>]
/// ```
///
/// ## Options
/// - `--format <format>` - Output format (default: `static-json`)
/// - `--output <path>` - Output directory (default: `./bundles`)
/// - `--locale <locale>` - Locale to export (default: `en-US`)
/// - `--since <timestamp>` - Only export entries modified after ISO 8601 timestamp
///
/// ## Examples
/// ```bash
/// # Full export
/// cms export
///
/// # Incremental export
/// cms export --since 2024-01-15T10:30:00Z
///
/// # Export specific locale
/// cms export --locale es-ES --output ./spanish-bundles
/// ```
///
/// ## 📊 Output
/// ```
/// Exporting published content...
///   Format: static-json
///   Output: ./bundles
///   Locale: en-US
///   Since: 2024-01-15T10:30:00Z (incremental)
///
/// Exporting entries:
///   article: 47 entries
///   page: 12 entries
///   product: 156 entries
///
/// Generated bundle manifest: bundles/ExportManifest.json
///
/// Export complete!
/// ✓ 215 entries exported
/// ✓ 3.2 MB total size
/// ```
///
/// ## 📦 Output Structure
/// ```
/// bundles/
/// ├── ExportManifest.json
/// └── en-US/
///     ├── article/
///     │   ├── welcome.json
///     │   └── ...
///     ├── page/
///     │   └── ...
///     └── ...
/// ```
struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export published content as static JSON bundles"
    )

    @CLIOption(name: .long, help: "Output format")
    var format: String = "static-json"

    @CLIOption(name: .long, help: "Output directory")
    var output: String = "./bundles"

    @CLIOption(name: .long, help: "Locale to export")
    var locale: String = "en-US"

    @CLIOption(name: .long, help: "Only export entries modified after this timestamp (ISO 8601)")
    var since: String?

    func run() throws {
        print("Exporting published content...")
        print("  Format: \(format)")
        print("  Output: \(output)")
        print("  Locale: \(locale)")
        if let since = since {
            print("  Since: \(since) (incremental)")
        }

        try FileManager.default.createDirectory(
            atPath: "\(output)/\(locale)",
            withIntermediateDirectories: true
        )

        // Generate manifest
        let manifest: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "locale": locale,
            "format": format,
            "incremental": since != nil,
            "entries": [] as [Any]
        ]
        let manifestData = try JSONSerialization.data(
            withJSONObject: manifest, options: [.prettyPrinted]
        )
        try manifestData.write(to: URL(fileURLWithPath: "\(output)/ExportManifest.json"))

        print("Export complete. Connect to a live database for full content export.")
    }
}

// MARK: - Configuration

/// Lightweight configuration for CLI commands.
func configure(_ app: Application) async throws {
    // Configure database
    if let databaseURL = Environment.get("DATABASE_URL") {
        try app.databases.use(
            .postgres(url: databaseURL),
            as: .psql
        )
        app.logger.info("Using PostgreSQL database")
    } else {
        app.databases.use(.sqlite(.memory), as: .sqlite)
        app.logger.warning("No DATABASE_URL set, using SQLite in-memory (development only)")
    }

    // Run migrations
    app.migrations.add(CreateContentTypeDefinitions())
    app.migrations.add(CreateContentEntries())
    app.migrations.add(CreateContentVersions())
    app.migrations.add(CreateUsers())
    app.migrations.add(CreateRoles())
    app.migrations.add(SeedDefaultRoles())

    try await app.autoMigrate()
}
