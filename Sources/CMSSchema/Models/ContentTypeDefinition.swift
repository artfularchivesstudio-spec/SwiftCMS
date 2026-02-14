import Fluent
import Vapor
import CMSObjects
import CryptoKit

// MARK: - ContentTypeDefinition Model

/// 🗂️ **ContentTypeDefinition**
/// The schema registry for all content types in the CMS.
///
/// This model stores the complete definition of a content type including:
/// - Field structure via JSON Schema
/// - Display information and metadata
/// - Schema hash for version tracking
/// - Kind (collection or single)
///
/// ## 🗄️ Database Schema
/// - Table: `content_type_definitions`
/// - Primary Key: `id` (UUID)
/// - Unique Index: `slug`
///
/// ## 🔗 Relationships
/// None - This is a top-level schema definition
///
/// ## 💾 Persistence
/// Stored with timestamp tracking for `created_at` and `updated_at`
/// Schema hash automatically computed and updated on changes
public final class ContentTypeDefinition: Model, Content, @unchecked Sendable {
    public static let schema = "content_type_definitions"

    // MARK: - 🎯 Primary Key
    /// 🆔 Unique identifier for this content type definition
    @ID(key: .id)
    public var id: UUID?

    // MARK: - 🎯 Field Data
    /// ✏️ Human-readable name of the content type
    @Field(key: "name")
    public var name: String

    /// 🔖 URL-friendly unique identifier for the content type
    /// - Important: Must be unique across all content types
    @Field(key: "slug")
    public var slug: String

    /// 🏷️ User-facing display name
    @Field(key: "display_name")
    public var displayName: String

    /// 📝 Optional description of the content type's purpose
    @OptionalField(key: "description")
    public var description: String?

    /// 🎯 Type of content: "collection" or "single"
    @Field(key: "kind")
    public var kind: String

    /// 📋 Complete JSON Schema defining the content structure
    /// - Format: JSON Schema v7 specification
    /// - Contains: Properties, types, validation rules
    @Field(key: "json_schema")
    public var jsonSchema: AnyCodableValue

    /// 📋 Field order array defining UI presentation order
    @Field(key: "field_order")
    public var fieldOrder: AnyCodableValue

    /// ⚙️ Optional settings object for content type configuration
    @OptionalField(key: "settings")
    public var settings: AnyCodableValue?

    /// 👥 Optional tenant identifier for multi-tenant setups
    @OptionalField(key: "tenant_id")
    public var tenantId: String?

    /// 🔗 SHA256 hash of the JSON schema for change detection
    /// - Automatically computed on save
    /// - Used for SDK versioning and schema change tracking
    @Field(key: "schema_hash")
    public var schemaHash: String

    // MARK: - 📊 Timestamps
    /// ⏰ Timestamp when the content type was created
    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    /// ⏰ Timestamp when the content type was last updated
    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {
        self.schemaHash = ""
    }

    // MARK: - 🏗️ Initializers
    /// Initialize a new content type definition
    /// - Parameters:
    ///   - id: Optional UUID (auto-generated if nil)
    ///   - name: Human-readable content type name
    ///   - slug: URL-friendly unique identifier
    ///   - displayName: User-facing display name
    ///   - description: Optional description
    ///   - kind: Content type kind (.collection or .single)
    ///   - jsonSchema: JSON Schema defining the structure
    ///   - fieldOrder: Array defining field presentation order
    ///   - settings: Optional configuration settings
    ///   - tenantId: Optional tenant identifier
    ///   - schemaHash: Optional pre-computed schema hash (auto-computed if nil)
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

/// 📤 Convert model to response DTO
    /// - Returns: ContentTypeResponseDTO for API responses
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

    /// 🔐 Compute SHA256 hash of JSON schema for version tracking
    /// - Parameter jsonSchema: The schema to hash
    /// - Returns: Hex-encoded SHA256 hash string
    func computeSchemaHash(jsonSchema: AnyCodableValue) -> String {
        guard let data = try? JSONEncoder().encode(jsonSchema) else {
            return ""
        }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// 🔄 Update schema hash when jsonSchema changes
    /// - Important: Must be called after any schema modification before saving
    public func updateSchemaHash() {
        self.schemaHash = computeSchemaHash(jsonSchema: jsonSchema)
    }
}

// MARK: - ContentEntry Model

/// 🗂️ **ContentEntry**
/// A single content entry storing dynamic JSONB data
///
/// Content entries are polymorphic instances of content types.
/// They contain JSONB data that is validated against the content type's JSON Schema.
///
/// ## 🗄️ Database Schema
/// - Table: `content_entries`
/// - Primary Key: `id` (UUID)
/// - Indexes:
///   - `(tenant_id, content_type)` - B-tree index
///   - `data` - GIN index (PostgreSQL only, SQLite skips)
///
/// ## 🔗 Relationships
/// - 🔗 to ContentTypeDefinition via `content_type` slug
/// - 🔗 to ContentVersion (parent relationship for version history)
///
/// ## 💾 Data Lifecycle
/// - Status tracking: draft → review → published → archived → deleted
/// - Soft delete via `deleted_at` timestamp
/// - Version history automatically created on updates
/// - Publishing schedule support via `publish_at` / `unpublish_at`

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
