import Fluent
import Vapor
import CMSObjects
import CryptoKit

// MARK: - ContentTypeDefinition

/// Defines a content type's schema, stored in the schema registry.
public final class ContentTypeDefinition: Model, Content, @unchecked Sendable {
    public static let schema = "content_type_definitions"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @Field(key: "slug")
    public var slug: String

    @Field(key: "display_name")
    public var displayName: String

    @OptionalField(key: "description")
    public var description: String?

    @Field(key: "kind")
    public var kind: String

    @Field(key: "json_schema")
    public var jsonSchema: AnyCodableValue

    @Field(key: "field_order")
    public var fieldOrder: AnyCodableValue

    @OptionalField(key: "settings")
    public var settings: AnyCodableValue?

    @OptionalField(key: "tenant_id")
    public var tenantId: String?

    @Field(key: "schema_hash")
    public var schemaHash: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {
        self.schemaHash = ""
    }

    public init(
        id: UUID? = nil, name: String, slug: String, displayName: String,
        description: String? = nil, kind: ContentTypeKind = .collection,
        jsonSchema: AnyCodableValue = .dictionary([:]),
        fieldOrder: AnyCodableValue = .array([]),
        settings: AnyCodableValue? = nil, tenantId: String? = nil,
        schemaHash: String? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.displayName = displayName
        self.description = description
        self.kind = kind.rawValue
        self.jsonSchema = jsonSchema
        self.fieldOrder = fieldOrder
        self.settings = settings
        self.tenantId = tenantId
        self.schemaHash = schemaHash ?? computeSchemaHash(jsonSchema: jsonSchema)
    }

    /// Convert to response DTO.
    public func toResponseDTO() -> ContentTypeResponseDTO {
        ContentTypeResponseDTO(
            id: id ?? UUID(),
            name: name,
            slug: slug,
            displayName: displayName,
            description: description,
            kind: ContentTypeKind(rawValue: kind) ?? .collection,
            jsonSchema: jsonSchema,
            fieldOrder: fieldOrder,
            settings: settings,
            tenantId: tenantId,
            schemaHash: schemaHash,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Compute SHA256 hash of JSON schema for version tracking.
    func computeSchemaHash(jsonSchema: AnyCodableValue) -> String {
        guard let data = try? JSONEncoder().encode(jsonSchema) else {
            return ""
        }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Update schema hash when jsonSchema changes.
    func updateSchemaHash() {
        self.schemaHash = computeSchemaHash(jsonSchema: jsonSchema)
    }
}

// MARK: - ContentEntry

/// A single content entry storing dynamic JSONB data.
public final class ContentEntry: Model, Content, @unchecked Sendable {
    public static let schema = "content_entries"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "content_type")
    public var contentType: String

    @Field(key: "data")
    public var data: AnyCodableValue

    @Field(key: "status")
    public var status: String

    @OptionalField(key: "locale")
    public var locale: String?

    @OptionalField(key: "publish_at")
    public var publishAt: Date?

    @OptionalField(key: "unpublish_at")
    public var unpublishAt: Date?

    @OptionalField(key: "created_by")
    public var createdBy: String?

    @OptionalField(key: "updated_by")
    public var updatedBy: String?

    @OptionalField(key: "tenant_id")
    public var tenantId: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    @OptionalField(key: "published_at")
    public var publishedAt: Date?

    @OptionalField(key: "deleted_at")
    public var deletedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil, contentType: String,
        data: AnyCodableValue = .dictionary([:]),
        status: ContentStatus = .draft, locale: String? = nil,
        publishAt: Date? = nil, unpublishAt: Date? = nil,
        createdBy: String? = nil, updatedBy: String? = nil,
        tenantId: String? = nil
    ) {
        self.id = id
        self.contentType = contentType
        self.data = data
        self.status = status.rawValue
        self.locale = locale
        self.publishAt = publishAt
        self.unpublishAt = unpublishAt
        self.createdBy = createdBy
        self.updatedBy = updatedBy
        self.tenantId = tenantId
    }

    /// Convert to response DTO.
    public func toResponseDTO() -> ContentEntryResponseDTO {
        ContentEntryResponseDTO(
            id: id ?? UUID(),
            contentType: contentType,
            data: data,
            status: ContentStatus(rawValue: status) ?? .draft,
            locale: locale,
            publishAt: publishAt,
            unpublishAt: unpublishAt,
            createdBy: createdBy,
            updatedBy: updatedBy,
            tenantId: tenantId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            publishedAt: publishedAt
        )
    }
}

// MARK: - ContentVersion

/// Version history for content entries.
public final class ContentVersion: Model, Content, @unchecked Sendable {
    public static let schema = "content_versions"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "entry_id")
    public var entry: ContentEntry

    @Field(key: "version")
    public var version: Int

    @Field(key: "data")
    public var data: AnyCodableValue

    @OptionalField(key: "changed_by")
    public var changedBy: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil, entryID: UUID, version: Int,
        data: AnyCodableValue, changedBy: String? = nil
    ) {
        self.id = id
        self.$entry.id = entryID
        self.version = version
        self.data = data
        self.changedBy = changedBy
    }

    /// Convert to response DTO.
    public func toResponseDTO() -> ContentVersionResponseDTO {
        ContentVersionResponseDTO(
            id: id ?? UUID(),
            entryId: $entry.id,
            version: version,
            data: data,
            changedBy: changedBy,
            createdAt: createdAt
        )
    }
}
