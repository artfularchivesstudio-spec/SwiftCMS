import Foundation
import ArgumentParser

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
            ExportCommand.self,
        ],
        defaultSubcommand: ServeCommand.self
    )

    public init() {}
}

// MARK: - Serve

struct ServeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Start the SwiftCMS server"
    )

    @Option(name: .long, help: "Hostname to bind")
    var hostname: String = "0.0.0.0"

    @Option(name: .long, help: "Port to bind")
    var port: Int = 8080

    func run() throws {
        print("Starting SwiftCMS on \(hostname):\(port)")
        // In production, delegates to Vapor's serve command
    }
}

// MARK: - Migrate

struct MigrateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate",
        abstract: "Run database migrations"
    )

    @Flag(name: .long, help: "Revert the last migration")
    var revert = false

    @Flag(name: .long, help: "Auto-confirm")
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

struct GenerateSDKCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate-sdk",
        abstract: "Generate typed client SDK from content type definitions"
    )

    @Argument(help: "Target language: swift or typescript")
    var language: String

    @Option(name: .long, help: "Output directory")
    var output: String = "./ClientSDK"

    func run() throws {
        switch language.lowercased() {
        case "swift":
            print("Generating Swift SDK to \(output)...")
            try generateSwiftSDK(outputDir: output)
        case "typescript":
            print("Generating TypeScript definitions to \(output)...")
            try generateTypeScriptDefs(outputDir: output)
        default:
            print("Unsupported language: \(language). Use 'swift' or 'typescript'.")
        }
    }

    func generateSwiftSDK(outputDir: String) throws {
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

    func generateTypeScriptDefs(outputDir: String) throws {
        try FileManager.default.createDirectory(
            atPath: outputDir, withIntermediateDirectories: true
        )

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
        print("TypeScript definitions generated at \(outputDir)/swiftcms.d.ts")
    }
}

// MARK: - Import Strapi

struct ImportStrapiCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import-strapi",
        abstract: "Import content types and data from a Strapi project"
    )

    @Option(name: .long, help: "Path to the Strapi project root")
    var path: String

    func run() throws {
        print("Importing from Strapi project at: \(path)")
        let parser = StrapiSchemaParser(projectPath: path)
        let types = try parser.parseSchemas()
        print("Found \(types.count) content types:")
        for t in types {
            print("  - \(t.name) (\(t.fields.count) fields)")
        }
        print("\nTo complete import, run with a live database connection.")
    }
}



// MARK: - Export

struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export published content as static JSON bundles"
    )

    @Option(name: .long, help: "Output format")
    var format: String = "static-json"

    @Option(name: .long, help: "Output directory")
    var output: String = "./bundles"

    @Option(name: .long, help: "Locale to export")
    var locale: String = "en-US"

    @Option(name: .long, help: "Only export entries modified after this timestamp (ISO 8601)")
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
