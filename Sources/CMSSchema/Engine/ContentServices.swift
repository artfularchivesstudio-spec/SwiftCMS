import Vapor
import Fluent
import CMSObjects
import CMSCore
import CMSEvents

// MARK: - ContentTypeService

/// Service for managing content type definitions.
public struct ContentTypeService: Sendable {

    /// Create a new content type definition.
    public static func create(
        dto: CreateContentTypeDTO,
        on db: Database,
        eventBus: EventBus,
        context: CmsContext
    ) async throws -> ContentTypeResponseDTO {
        // Check slug uniqueness
        let existing = try await ContentTypeDefinition.query(on: db)
            .filter(\.$slug == dto.slug)
            .first()

        if existing != nil {
            throw ApiError.conflict("Content type with slug '\(dto.slug)' already exists")
        }

        // Generate schema from field definitions if not provided
        let schema = dto.jsonSchema ?? .dictionary(["type": "object", "properties": .dictionary([:] as [String: AnyCodableValue])])

        let definition = ContentTypeDefinition(
            name: dto.name,
            slug: dto.slug,
            displayName: dto.displayName,
            description: dto.description,
            kind: dto.kind,
            jsonSchema: schema,
            fieldOrder: dto.fieldOrder.map { .array($0) } ?? .array([])
        )

        try await definition.save(on: db)

        // Fire schema changed event
        let event = SchemaChangedEvent(contentTypeSlug: dto.slug, action: "created")
        try await eventBus.publish(event: event, context: context)

        return definition.toResponseDTO()
    }

    /// Get a content type by slug.
    public static func get(slug: String, on db: Database) async throws -> ContentTypeResponseDTO {
        guard let definition = try await ContentTypeDefinition.query(on: db)
            .filter(\.$slug == slug)
            .first()
        else {
            throw ApiError.notFound("Content type '\(slug)' not found")
        }
        return definition.toResponseDTO()
    }

    /// List all content types.
    public static func list(
        on db: Database,
        page: Int = 1,
        perPage: Int = 50
    ) async throws -> PaginationWrapper<ContentTypeResponseDTO> {
        let total = try await ContentTypeDefinition.query(on: db).count()
        let definitions = try await ContentTypeDefinition.query(on: db)
            .offset((page - 1) * perPage)
            .limit(perPage)
            .sort(\.$name)
            .all()

        let dtos = definitions.map { $0.toResponseDTO() }
        return .paginate(items: dtos, page: page, perPage: perPage, total: total)
    }

    /// Update a content type definition.
    public static func update(
        slug: String,
        dto: UpdateContentTypeDTO,
        on db: Database,
        eventBus: EventBus,
        context: CmsContext
    ) async throws -> ContentTypeResponseDTO {
        guard let definition = try await ContentTypeDefinition.query(on: db)
            .filter(\.$slug == slug)
            .first()
        else {
            throw ApiError.notFound("Content type '\(slug)' not found")
        }

        if let name = dto.name { definition.name = name }
        if let displayName = dto.displayName { definition.displayName = displayName }
        if let description = dto.description { definition.description = description }
        if let kind = dto.kind { definition.kind = kind.rawValue }
        if let jsonSchema = dto.jsonSchema { definition.jsonSchema = jsonSchema }
        if let fieldOrder = dto.fieldOrder { definition.fieldOrder = .array(fieldOrder) }
        if let settings = dto.settings { definition.settings = settings }

        try await definition.save(on: db)

        let event = SchemaChangedEvent(contentTypeSlug: slug, action: "updated")
        try await eventBus.publish(event: event, context: context)

        return definition.toResponseDTO()
    }

    /// Delete a content type definition.
    public static func delete(
        slug: String,
        force: Bool = false,
        on db: Database,
        eventBus: EventBus,
        context: CmsContext
    ) async throws {
        guard let definition = try await ContentTypeDefinition.query(on: db)
            .filter(\.$slug == slug)
            .first()
        else {
            throw ApiError.notFound("Content type '\(slug)' not found")
        }

        if !force {
            let entryCount = try await ContentEntry.query(on: db)
                .filter(\.$contentType == slug)
                .count()
            if entryCount > 0 {
                throw ApiError.conflict(
                    "Cannot delete content type '\(slug)' with \(entryCount) entries. Use force=true to override."
                )
            }
        }

        try await definition.delete(on: db)

        let event = SchemaChangedEvent(contentTypeSlug: slug, action: "deleted")
        try await eventBus.publish(event: event, context: context)
    }
}

// MARK: - ContentEntryService

/// Service for managing content entries.
public struct ContentEntryService: Sendable {

    /// Create a new content entry.
    public static func create(
        contentType: String,
        dto: CreateContentEntryDTO,
        on db: Database,
        eventBus: EventBus,
        context: CmsContext
    ) async throws -> ContentEntryResponseDTO {
        // Lookup content type definition
        guard let typeDef = try await ContentTypeDefinition.query(on: db)
            .filter(\.$slug == contentType)
            .first()
        else {
            throw ApiError.notFound("Content type '\(contentType)' not found")
        }

        // Validate data against JSON schema
        let errors = SchemaValidator.validate(data: dto.data, against: typeDef.jsonSchema)
        if !errors.isEmpty {
            let details = Dictionary(
                uniqueKeysWithValues: errors.enumerated().map { ("error_\($0.offset)", $0.element.description) }
            )
            throw ApiError.badRequest("Validation failed", details: details)
        }

        let entry = ContentEntry(
            contentType: contentType,
            data: dto.data,
            status: dto.status ?? .draft,
            locale: dto.locale,
            publishAt: dto.publishAt,
            unpublishAt: dto.unpublishAt,
            createdBy: context.userId,
            updatedBy: context.userId,
            tenantId: context.tenantId
        )

        try await entry.save(on: db)

        // Fire content created event
        let event = ContentCreatedEvent(
            entryId: entry.id ?? UUID(),
            contentType: contentType,
            userId: context.userId
        )
        try await eventBus.publish(event: event, context: context)

        return entry.toResponseDTO()
    }

    /// Get a content entry by ID.
    public static func get(
        contentType: String,
        id: UUID,
        on db: Database
    ) async throws -> ContentEntryResponseDTO {
        guard let entry = try await ContentEntry.query(on: db)
            .filter(\.$contentType == contentType)
            .filter(\.$id == id)
            .filter(\.$deletedAt == nil)
            .first()
        else {
            throw ApiError.notFound("Entry not found")
        }
        return entry.toResponseDTO()
    }

    /// List content entries with pagination, filtering, and sorting.
    public static func list(
        contentType: String,
        on db: Database,
        page: Int = 1,
        perPage: Int = 25,
        status: String? = nil,
        locale: String? = nil,
        sortField: String? = nil,
        sortDirection: String = "desc"
    ) async throws -> PaginationWrapper<ContentEntryResponseDTO> {
        var query = ContentEntry.query(on: db)
            .filter(\.$contentType == contentType)
            .filter(\.$deletedAt == nil)

        if let status = status {
            query = query.filter(\.$status == status)
        }
        if let locale = locale {
            query = query.filter(\.$locale == locale)
        }

        let total = try await query.count()

        // Default sort by createdAt desc
        query = query.sort(\.$createdAt, sortDirection == "asc" ? .ascending : .descending)

        let entries = try await query
            .offset((page - 1) * perPage)
            .limit(min(perPage, 100))
            .all()

        let dtos = entries.map { $0.toResponseDTO() }
        return .paginate(items: dtos, page: page, perPage: perPage, total: total)
    }

    /// Update a content entry.
    public static func update(
        contentType: String,
        id: UUID,
        dto: UpdateContentEntryDTO,
        on db: Database,
        eventBus: EventBus,
        context: CmsContext
    ) async throws -> ContentEntryResponseDTO {
        guard let entry = try await ContentEntry.query(on: db)
            .filter(\.$contentType == contentType)
            .filter(\.$id == id)
            .filter(\.$deletedAt == nil)
            .first()
        else {
            throw ApiError.notFound("Entry not found")
        }

        // Validate new data if provided
        if let data = dto.data {
            guard let typeDef = try await ContentTypeDefinition.query(on: db)
                .filter(\.$slug == contentType)
                .first()
            else {
                throw ApiError.notFound("Content type '\(contentType)' not found")
            }

            let errors = SchemaValidator.validate(data: data, against: typeDef.jsonSchema)
            if !errors.isEmpty {
                let details = Dictionary(
                    uniqueKeysWithValues: errors.enumerated().map { ("error_\($0.offset)", $0.element.description) }
                )
                throw ApiError.badRequest("Validation failed", details: details)
            }
            entry.data = data
        }

        // Handle status transition
        if let newStatus = dto.status {
            let currentStatus = ContentStatus(rawValue: entry.status) ?? .draft
            let allowed = ContentStateMachine.allowedTransitions(from: currentStatus)
            guard allowed.contains(newStatus) else {
                throw ApiError.unprocessableEntity(
                    "Cannot transition from '\(entry.status)' to '\(newStatus.rawValue)'. Allowed: \(allowed.map(\.rawValue))"
                )
            }
            let oldStatus = entry.status
            entry.status = newStatus.rawValue
            if newStatus == .published {
                entry.publishedAt = Date()
            }

            // Fire state changed event
            let stateEvent = ContentStateChangedEvent(
                entryId: id, contentType: contentType,
                fromState: oldStatus, toState: newStatus.rawValue,
                userId: context.userId
            )
            try await eventBus.publish(event: stateEvent, context: context)
        }

        if let locale = dto.locale { entry.locale = locale }
        if let publishAt = dto.publishAt { entry.publishAt = publishAt }
        if let unpublishAt = dto.unpublishAt { entry.unpublishAt = unpublishAt }
        entry.updatedBy = context.userId

        try await entry.save(on: db)

        // Create version
        let versionCount = try await ContentVersion.query(on: db)
            .filter(\.$entry.$id == id)
            .count()
        let version = ContentVersion(
            entryID: id,
            version: versionCount + 1,
            data: entry.data,
            changedBy: context.userId
        )
        try await version.save(on: db)

        // Fire updated event
        let event = ContentUpdatedEvent(
            entryId: id, contentType: contentType, userId: context.userId
        )
        try await eventBus.publish(event: event, context: context)

        return entry.toResponseDTO()
    }

    /// Soft delete a content entry.
    public static func delete(
        contentType: String,
        id: UUID,
        on db: Database,
        eventBus: EventBus,
        context: CmsContext
    ) async throws {
        guard let entry = try await ContentEntry.query(on: db)
            .filter(\.$contentType == contentType)
            .filter(\.$id == id)
            .filter(\.$deletedAt == nil)
            .first()
        else {
            throw ApiError.notFound("Entry not found")
        }

        entry.deletedAt = Date()
        try await entry.save(on: db)

        let event = ContentDeletedEvent(
            entryId: id, contentType: contentType, userId: context.userId
        )
        try await eventBus.publish(event: event, context: context)
    }
}
