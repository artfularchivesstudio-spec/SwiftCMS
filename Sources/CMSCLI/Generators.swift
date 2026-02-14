import Foundation

// MARK: - Swift SDK Generator

/// Generates typed Swift client SDK from content type definitions.
public struct SwiftSDKGenerator {

    /// Map JSON Schema types to Swift types.
    static let typeMapping: [String: String] = [
        "string": "String",
        "integer": "Int",
        "number": "Double",
        "boolean": "Bool",
        "array": "[AnyCodableValue]",
        "object": "[String: AnyCodableValue]",
    ]

    /// Generate a Swift struct from a content type definition.
    public static func generateStruct(
        name: String,
        slug: String,
        schema: [String: Any]
    ) -> String {
        let structName = name.replacingOccurrences(of: " ", with: "")
        var code = """
        import Foundation

        /// Auto-generated from SwiftCMS content type: \(slug)
        public struct \(structName): Codable, Sendable, Identifiable {
            public let id: UUID
            public let status: String
            public let createdAt: Date?
            public let updatedAt: Date?

        """

        if let properties = (schema["properties"] as? [String: Any]) {
            for (fieldName, fieldSchema) in properties.sorted(by: { $0.key < $1.key }) {
                guard let fieldDict = fieldSchema as? [String: Any],
                      let type = fieldDict["type"] as? String else {
                    continue
                }

                let swiftType = typeMapping[type] ?? "String"
                let isRequired = (schema["required"] as? [String])?.contains(fieldName) ?? false
                let optionalMark = isRequired ? "" : "?"

                code += "    public let \(fieldName): \(swiftType)\(optionalMark)\n"
            }
        }

        code += """
        }

        // MARK: - \(structName) Client

        /// Typed API client for \(slug) content type.
        public actor \(structName)Client {
            let baseURL: URL
            let session: URLSession

            public init(baseURL: URL, session: URLSession = .shared) {
                self.baseURL = baseURL
                self.session = session
            }

            /// List all \(slug) entries.
            public func list(page: Int = 1, perPage: Int = 25) async throws -> PaginatedResponse<\(structName)> {
                let url = baseURL.appendingPathComponent("api/v1/\(slug)")
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                components.queryItems = [
                    URLQueryItem(name: "page", value: "\\(page)"),
                    URLQueryItem(name: "perPage", value: "\\(perPage)")
                ]
                let (data, _) = try await session.data(from: components.url!)
                return try JSONDecoder().decode(PaginatedResponse<\(structName)>.self, from: data)
            }

            /// Get a single \(slug) entry by ID.
            public func get(id: UUID) async throws -> \(structName) {
                let url = baseURL.appendingPathComponent("api/v1/\(slug)/\\(id)")
                let (data, _) = try await session.data(from: url)
                return try JSONDecoder().decode(\(structName).self, from: data)
            }

            /// Create a new \(slug) entry.
            public func create(_ entry: \(structName)) async throws -> \(structName) {
                let url = baseURL.appendingPathComponent("api/v1/\(slug)")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(entry)
                let (data, _) = try await session.data(for: request)
                return try JSONDecoder().decode(\(structName).self, from: data)
            }

            /// Delete a \(slug) entry.
            public func delete(id: UUID) async throws {
                let url = baseURL.appendingPathComponent("api/v1/\(slug)/\\(id)")
                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                _ = try await session.data(for: request)
            }
        }
        """

        return code
    }

    /// Generate a complete SPM package.
    public static func generatePackage(types: [(name: String, slug: String, schema: [String: Any])]) -> String {
        return """
        // swift-tools-version:5.10
        import PackageDescription

        let package = Package(
            name: "SwiftCMSClient",
            platforms: [.iOS(.v15), .macOS(.v13)],
            products: [
                .library(name: "SwiftCMSClient", targets: ["SwiftCMSClient"]),
            ],
            targets: [
                .target(name: "SwiftCMSClient"),
            ]
        )
        """
    }
}

// MARK: - TypeScript Generator

/// Generates TypeScript type definitions from content types.
public struct TypeScriptGenerator {

    static let typeMapping: [String: String] = [
        "string": "string",
        "integer": "number",
        "number": "number",
        "boolean": "boolean",
        "array": "any[]",
        "object": "Record<string, any>",
    ]

    /// Generate TypeScript interface.
    public static func generateInterface(
        name: String,
        schema: [String: Any]
    ) -> String {
        let interfaceName = name.replacingOccurrences(of: " ", with: "")
        var code = """
        /** Auto-generated from SwiftCMS */
        export interface \(interfaceName) {
            id: string;
            status: string;
            createdAt: string | null;
            updatedAt: string | null;

        """

        if let properties = schema["properties"] as? [String: Any] {
            let required = schema["required"] as? [String] ?? []
            for (fieldName, fieldSchema) in properties.sorted(by: { $0.key < $1.key }) {
                guard let fieldDict = fieldSchema as? [String: Any],
                      let type = fieldDict["type"] as? String else {
                    continue
                }
                let tsType = typeMapping[type] ?? "any"
                let optional = required.contains(fieldName) ? "" : "?"
                code += "    \(fieldName)\(optional): \(tsType);\n"
            }
        }

        code += "}\n"
        return code
    }
}

// MARK: - Strapi Schema Parser

/// Parses Strapi schema.json files and converts to SwiftCMS format.
public struct StrapiSchemaParser {

    /// Strapi to SwiftCMS type mapping.
    static let typeMapping: [String: String] = [
        "string": "shortText",
        "text": "longText",
        "richtext": "richText",
        "integer": "integer",
        "float": "decimal",
        "decimal": "decimal",
        "boolean": "boolean",
        "date": "dateTime",
        "datetime": "dateTime",
        "time": "shortText",
        "email": "email",
        "enumeration": "enumeration",
        "media": "media",
        "json": "json",
        "uid": "shortText",
        "relation": "relationHasOne",
    ]

    /// Parse a Strapi schema.json and return SwiftCMS field definitions.
    public static func parse(schemaJSON: Data) throws -> (name: String, fields: [[String: Any]]) {
        guard let schema = try JSONSerialization.jsonObject(with: schemaJSON) as? [String: Any],
              let info = schema["info"] as? [String: Any],
              let displayName = info["displayName"] as? String,
              let attributes = schema["attributes"] as? [String: Any] else {
            throw NSError(domain: "StrapiParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Strapi schema"])
        }

        var fields: [[String: Any]] = []
        for (name, attrValue) in attributes {
            guard let attr = attrValue as? [String: Any],
                  let strapiType = attr["type"] as? String else {
                continue
            }

            let swiftCMSType = typeMapping[strapiType] ?? "shortText"
            var field: [String: Any] = [
                "name": name,
                "type": swiftCMSType,
                "required": attr["required"] as? Bool ?? false,
            ]

            if let enumValues = attr["enum"] as? [String] {
                field["enumValues"] = enumValues
            }

            fields.append(field)
        }

        return (name: displayName, fields: fields)
    }
}

// MARK: - Static Export

/// Generates static JSON bundles for offline iOS apps.
public struct StaticExporter {

    /// Export published entries as static JSON files.
    public static func export(
        entries: [(contentType: String, slug: String, data: Data)],
        locale: String = "en-US",
        outputDir: String = "./bundles"
    ) throws -> ExportManifest {
        let fm = FileManager.default
        var manifest = ExportManifest(locale: locale, entries: [])

        for entry in entries {
            let dir = "\(outputDir)/\(locale)/\(entry.contentType)"
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

            let path = "\(dir)/\(entry.slug).json"
            try entry.data.write(to: URL(fileURLWithPath: path))

            // Compute hash for delta updates
            let hash = entry.data.base64EncodedString().prefix(16)
            manifest.entries.append(ExportManifest.Entry(
                contentType: entry.contentType,
                slug: entry.slug,
                hash: String(hash)
            ))
        }

        // Write manifest
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: URL(fileURLWithPath: "\(outputDir)/ExportManifest.json"))

        return manifest
    }
}

/// Manifest for exported static JSON bundles.
public struct ExportManifest: Codable {
    let locale: String
    var entries: [Entry]

    struct Entry: Codable {
        let contentType: String
        let slug: String
        let hash: String
    }
}

// MARK: - Shared Types

/// Generic paginated response for SDK client.
public struct PaginatedResponse<T: Codable>: Codable {
    public let data: [T]
    public let meta: PaginationMetaResponse
}

public struct PaginationMetaResponse: Codable {
    public let page: Int
    public let perPage: Int
    public let total: Int
    public let totalPages: Int
}
