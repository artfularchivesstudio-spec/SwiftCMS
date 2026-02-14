import Foundation

/// Parses Strapi's schema.json files into SwiftCMS type definitions.
public struct StrapiSchemaParser: Sendable {
    public let projectPath: String?

    public init(projectPath: String? = nil) {
        self.projectPath = projectPath
    }

    /// Strapi field type to SwiftCMS field type mapping.
    public static let typeMapping: [String: String] = [
        "string": "shortText",
        "text": "longText",
        "richtext": "richText",
        "integer": "integer",
        "biginteger": "integer",
        "float": "decimal",
        "decimal": "decimal",
        "boolean": "boolean",
        "date": "dateTime",
        "datetime": "dateTime",
        "time": "shortText",
        "email": "email",
        "enumeration": "enumeration",
        "json": "json",
        "media": "media",
        "relation": "relationHasOne",
        "uid": "shortText",
        "password": "shortText"
    ]

    public struct ParsedType: Sendable {
        public let name: String
        public let slug: String
        public let fields: [(name: String, type: String, required: Bool)]
    }

    /// Parse all schemas in a Strapi project directory.
    public func parseSchemas() throws -> [ParsedType] {
        guard let projectPath = projectPath else {
            throw NSError(domain: "StrapiParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Project path not set"])
        }
        
        let apiPath = "\(projectPath)/src/api"
        let fm = FileManager.default

        guard fm.fileExists(atPath: apiPath) else {
            return []
        }

        var types: [ParsedType] = []
        let contents = try fm.contentsOfDirectory(atPath: apiPath)

        for dir in contents {
            let schemaGlob = "\(apiPath)/\(dir)/content-types"
            guard fm.fileExists(atPath: schemaGlob) else { continue }

            let typeContents = try fm.contentsOfDirectory(atPath: schemaGlob)
            for typeDir in typeContents {
                let schemaPath = "\(schemaGlob)/\(typeDir)/schema.json"
                guard fm.fileExists(atPath: schemaPath) else { continue }

                let data = try Data(contentsOf: URL(fileURLWithPath: schemaPath))
                let result = try StrapiSchemaParser.parse(schemaJSON: data)
                
                types.append(ParsedType(
                    name: result.name,
                    slug: result.slug,
                    fields: result.fields
                ))
            }
        }

        return types
    }

    /// Parse a single Strapi schema.json Data.
    public static func parse(schemaJSON: Data) throws -> (name: String, slug: String, fields: [(name: String, type: String, required: Bool)]) {
        guard let json = try JSONSerialization.jsonObject(with: schemaJSON) as? [String: Any],
              let info = json["info"] as? [String: Any],
              let displayName = info["displayName"] as? String,
              let singularName = (info["singularName"] as? String) ?? (info["displayName"] as? String)?.lowercased(),
              let attributes = json["attributes"] as? [String: Any] else {
            throw NSError(domain: "StrapiParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Strapi schema"])
        }

        var fields: [(String, String, Bool)] = []
        for (fieldName, fieldDef) in attributes {
            guard let def = fieldDef as? [String: Any],
                  let strapiType = def["type"] as? String else {
                continue
            }
            let cmsType = StrapiSchemaParser.typeMapping[strapiType] ?? "shortText"
            let required = def["required"] as? Bool ?? false
            fields.append((fieldName, cmsType, required))
        }

        return (name: displayName.capitalized, slug: singularName, fields: fields)
    }
}
