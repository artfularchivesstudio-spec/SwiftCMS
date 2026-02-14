import Vapor

/// The kind of content type.
public enum ContentTypeKind: String, Codable, Sendable {
    case collection
    case single
}

/// DTO for creating a new content type definition.
public struct CreateContentTypeDTO: Content, Sendable, Validatable {
    /// Unique machine name.
    public let name: String
    /// URL-safe slug.
    public let slug: String
    /// Human-readable display name.
    public let displayName: String
    /// Optional description.
    public let description: String?
    /// Whether this is a collection or single type.
    public let kind: ContentTypeKind
    /// JSON Schema for validation.
    public let jsonSchema: AnyCodableValue?
    /// Ordered list of field definitions.
    public let fieldOrder: [AnyCodableValue]?
    /// Additional settings.
    public let settings: AnyCodableValue?

    public static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("slug", as: String.self, is: !.empty && .alphanumeric || .pattern("^[a-z0-9-]+$"))
        validations.add("displayName", as: String.self, is: !.empty)
    }

    public init(
        name: String,
        slug: String,
        displayName: String,
        description: String? = nil,
        kind: ContentTypeKind = .collection,
        jsonSchema: AnyCodableValue? = nil,
        fieldOrder: [AnyCodableValue]? = nil,
        settings: AnyCodableValue? = nil
    ) {
        self.name = name
        self.slug = slug
        self.displayName = displayName
        self.description = description
        self.kind = kind
        self.jsonSchema = jsonSchema
        self.fieldOrder = fieldOrder
        self.settings = settings
    }
}

/// DTO for updating a content type definition.
public struct UpdateContentTypeDTO: Content, Sendable {
    public let name: String?
    public let displayName: String?
    public let description: String?
    public let kind: ContentTypeKind?
    public let jsonSchema: AnyCodableValue?
    public let fieldOrder: [AnyCodableValue]?
    public let settings: AnyCodableValue?

    public init(
        name: String? = nil,
        displayName: String? = nil,
        description: String? = nil,
        kind: ContentTypeKind? = nil,
        jsonSchema: AnyCodableValue? = nil,
        fieldOrder: [AnyCodableValue]? = nil,
        settings: AnyCodableValue? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.description = description
        self.kind = kind
        self.jsonSchema = jsonSchema
        self.fieldOrder = fieldOrder
        self.settings = settings
    }
}

/// DTO for content type definition responses.
public struct ContentTypeResponseDTO: Content, Sendable {
    public let id: UUID
    public let name: String
    public let slug: String
    public let displayName: String
    public let description: String?
    public let kind: ContentTypeKind
    public let jsonSchema: AnyCodableValue
    public let fieldOrder: AnyCodableValue
    public let settings: AnyCodableValue?
    public let tenantId: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        name: String,
        slug: String,
        displayName: String,
        description: String?,
        kind: ContentTypeKind,
        jsonSchema: AnyCodableValue,
        fieldOrder: AnyCodableValue,
        settings: AnyCodableValue?,
        tenantId: String?,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.displayName = displayName
        self.description = description
        self.kind = kind
        self.jsonSchema = jsonSchema
        self.fieldOrder = fieldOrder
        self.settings = settings
        self.tenantId = tenantId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
