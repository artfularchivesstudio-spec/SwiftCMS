import Vapor
import CMSObjects

/// Registry mapping field type strings to JSON Schema fragments.
public struct FieldTypeRegistry: Sendable {

    /// The 14 supported field types with their JSON Schema fragments.
    public static let fieldTypes: [String: AnyCodableValue] = [
        "shortText": .dictionary([
            "type": "string",
            "maxLength": 255
        ]),
        "longText": .dictionary([
            "type": "string"
        ]),
        "richText": .dictionary([
            "type": "string"
        ]),
        "integer": .dictionary([
            "type": "integer"
        ]),
        "decimal": .dictionary([
            "type": "number"
        ]),
        "boolean": .dictionary([
            "type": "boolean"
        ]),
        "dateTime": .dictionary([
            "type": "string",
            "format": "date-time"
        ]),
        "email": .dictionary([
            "type": "string",
            "format": "email"
        ]),
        "enumeration": .dictionary([
            "type": "string"
        ]),
        "json": .dictionary([
            "type": "object"
        ]),
        "media": .dictionary([
            "type": "string",
            "format": "uuid"
        ]),
        "relationHasOne": .dictionary([
            "type": "string",
            "format": "uuid"
        ]),
        "relationHasMany": .dictionary([
            "type": "array",
            "items": .dictionary(["type": "string", "format": "uuid"])
        ]),
        "component": .dictionary([
            "type": "object"
        ])
    ]

    /// Returns the JSON Schema fragment for a given field type.
    public static func schemaFragment(for fieldType: String) -> AnyCodableValue? {
        fieldTypes[fieldType]
    }

    /// Returns all registered field type names.
    public static var allFieldTypes: [String] {
        Array(fieldTypes.keys).sorted()
    }
}

// MARK: - Field Definition

/// Describes a single field within a content type.
public struct FieldDefinition: Codable, Sendable {
    public let name: String
    public let type: String
    public let required: Bool?
    public let unique: Bool?
    public let defaultValue: AnyCodableValue?
    public let enumValues: [String]?
    public let targetType: String?  // For relations
    public let description: String?

    public init(
        name: String, type: String, required: Bool? = nil,
        unique: Bool? = nil, defaultValue: AnyCodableValue? = nil,
        enumValues: [String]? = nil, targetType: String? = nil,
        description: String? = nil
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.unique = unique
        self.defaultValue = defaultValue
        self.enumValues = enumValues
        self.targetType = targetType
        self.description = description
    }
}

// MARK: - SchemaGenerator

/// Generates JSON Schema from field definitions.
public struct SchemaGenerator: Sendable {

    /// Generate a complete JSON Schema from an array of field definitions.
    /// - Parameter fields: The field definitions to generate schema from.
    /// - Returns: A JSON Schema as AnyCodableValue.
    public static func generate(from fields: [FieldDefinition]) -> AnyCodableValue {
        var properties: [String: AnyCodableValue] = [:]
        var requiredFields: [AnyCodableValue] = []

        for field in fields {
            guard var fragment = FieldTypeRegistry.schemaFragment(for: field.type)?
                    .dictionaryValue else {
                continue
            }

            // Add enum values if present
            if let enumValues = field.enumValues, field.type == "enumeration" {
                fragment["enum"] = .array(enumValues.map { .string($0) })
            }

            // Add default value if present
            if let defaultValue = field.defaultValue {
                fragment["default"] = defaultValue
            }

            // Add description if present
            if let desc = field.description {
                fragment["description"] = .string(desc)
            }

            properties[field.name] = .dictionary(fragment)

            if field.required == true {
                requiredFields.append(.string(field.name))
            }
        }

        var schema: [String: AnyCodableValue] = [
            "type": "object",
            "properties": .dictionary(properties)
        ]

        if !requiredFields.isEmpty {
            schema["required"] = .array(requiredFields)
        }

        schema["additionalProperties"] = .bool(false)

        return .dictionary(schema)
    }
}
