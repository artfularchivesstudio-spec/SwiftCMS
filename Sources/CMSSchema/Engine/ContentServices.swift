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

    /// List content entries with pagination, filtering, sorting, and field selection.
    ///
    /// Supports in-memory JSONB field filtering, JSONB-based sorting, and sparse fieldsets.
    /// - Parameters:
    ///   - contentType: The content type slug to query entries for.
    ///   - db: The database connection.
    ///   - page: The page number (1-based). Defaults to 1.
    ///   - perPage: The number of items per page. Defaults to 25.
    ///   - status: Optional status filter applied at the database level.
    ///   - locale: Optional locale filter applied at the database level.
    ///   - sortField: Optional JSONB field name to sort by (in-memory).
    ///   - sortDirection: Sort direction, either "asc" or "desc". Defaults to "desc".
    ///   - filters: Optional dictionary of JSONB field filters. Each key is a field name
    ///     within the entry's `data` dictionary, and the value is matched against the
    ///     field's string representation.
    ///   - fields: Optional list of field names for sparse fieldsets. When provided, only
    ///     the specified keys are retained in each entry's `data` dictionary.
    public static func list(
        contentType: String,
        on db: Database,
        page: Int = 1,
        perPage: Int = 25,
        status: String? = nil,
        locale: String? = nil,
        sortField: String? = nil,
        sortDirection: String = "desc",
        filters: [String: String]? = nil,
        fields: [String]? = nil
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

        // When JSONB filters are present, we need to fetch all matching entries first,
        // then apply in-memory filtering before paginating. Without JSONB filters,
        // use database-level pagination for efficiency.
        let hasJsonbProcessing = (filters != nil && !(filters?.isEmpty ?? true))
            || sortField != nil

        if hasJsonbProcessing {
            // Fetch all entries matching DB-level filters for in-memory processing
            let allEntries = try await query
                .sort(\.$createdAt, sortDirection == "asc" ? .ascending : .descending)
                .all()

            var dtos = allEntries.map { $0.toResponseDTO() }

            // Apply in-memory JSONB field filters
            if let filters = filters, !filters.isEmpty {
                dtos = dtos.filter { dto in
                    guard let dataDict = dto.data.dictionaryValue else { return false }
                    return filters.allSatisfy { key, value in
                        guard let fieldValue = dataDict[key] else { return false }
                        return Self.matchesFilter(fieldValue: fieldValue, filterValue: value)
                    }
                }
            }

            // Apply in-memory JSONB sort
            if let sortField = sortField {
                let ascending = sortDirection == "asc"
                dtos.sort { a, b in
                    let aVal = a.data[sortField]
                    let bVal = b.data[sortField]
                    return Self.compareAnyCodableValues(aVal, bVal, ascending: ascending)
                }
            }

            let total = dtos.count

            // Apply pagination in-memory
            let clampedPerPage = min(perPage, 100)
            let startIndex = (page - 1) * clampedPerPage
            let paginatedDtos: [ContentEntryResponseDTO]
            if startIndex < dtos.count {
                let endIndex = min(startIndex + clampedPerPage, dtos.count)
                paginatedDtos = Array(dtos[startIndex..<endIndex])
            } else {
                paginatedDtos = []
            }

            // Apply sparse fieldsets
            let finalDtos = Self.applyFieldSelection(dtos: paginatedDtos, fields: fields)
            return .paginate(items: finalDtos, page: page, perPage: clampedPerPage, total: total)
        } else {
            // No JSONB processing needed; use efficient database-level pagination
            let total = try await query.count()

            // Default sort by createdAt
            query = query.sort(\.$createdAt, sortDirection == "asc" ? .ascending : .descending)

            let clampedPerPage = min(perPage, 100)
            let entries = try await query
                .offset((page - 1) * clampedPerPage)
                .limit(clampedPerPage)
                .all()

            let dtos = entries.map { $0.toResponseDTO() }

            // Apply sparse fieldsets
            let finalDtos = Self.applyFieldSelection(dtos: dtos, fields: fields)
            return .paginate(items: finalDtos, page: page, perPage: clampedPerPage, total: total)
        }
    }

    // MARK: - In-Memory Filtering Helpers

    /// Checks whether a JSONB field value matches a filter string.
    ///
    /// Compares the string representation of the field value against the filter value.
    /// Supports string, int, double, and bool types.
    private static func matchesFilter(fieldValue: AnyCodableValue, filterValue: String) -> Bool {
        switch fieldValue {
        case .string(let v):
            return v == filterValue
        case .int(let v):
            return String(v) == filterValue
        case .double(let v):
            return String(v) == filterValue
        case .bool(let v):
            return String(v) == filterValue
        case .null:
            return filterValue.lowercased() == "null"
        default:
            return false
        }
    }

    /// Compares two optional AnyCodableValue instances for sorting purposes.
    ///
    /// Nil values are sorted to the end regardless of direction. Values are compared
    /// as strings, integers, or doubles depending on their type.
    private static func compareAnyCodableValues(
        _ a: AnyCodableValue?,
        _ b: AnyCodableValue?,
        ascending: Bool
    ) -> Bool {
        // Nil values sort to the end
        guard let aVal = a else { return false }
        guard let bVal = b else { return true }

        let result: Bool
        switch (aVal, bVal) {
        case (.string(let aStr), .string(let bStr)):
            result = aStr.localizedCaseInsensitiveCompare(bStr) == .orderedAscending
        case (.int(let aInt), .int(let bInt)):
            result = aInt < bInt
        case (.double(let aDbl), .double(let bDbl)):
            result = aDbl < bDbl
        case (.int(let aInt), .double(let bDbl)):
            result = Double(aInt) < bDbl
        case (.double(let aDbl), .int(let bInt)):
            result = aDbl < Double(bInt)
        case (.bool(let aBool), .bool(let bBool)):
            result = !aBool && bBool // false < true
        default:
            // Fall back to string comparison for mixed types
            let aStr = Self.anyCodableToSortString(aVal)
            let bStr = Self.anyCodableToSortString(bVal)
            result = aStr.localizedCaseInsensitiveCompare(bStr) == .orderedAscending
        }

        return ascending ? result : !result
    }

    /// Converts an AnyCodableValue to a string suitable for sort comparison.
    private static func anyCodableToSortString(_ value: AnyCodableValue) -> String {
        switch value {
        case .string(let v): return v
        case .int(let v): return String(v)
        case .double(let v): return String(v)
        case .bool(let v): return v ? "true" : "false"
        case .null: return ""
        default: return ""
        }
    }

    /// Applies sparse fieldset selection to response DTOs.
    ///
    /// When `fields` is provided, each DTO's `data` dictionary is stripped to only
    /// include the specified keys. If `fields` is nil, DTOs are returned unchanged.
    private static func applyFieldSelection(
        dtos: [ContentEntryResponseDTO],
        fields: [String]?
    ) -> [ContentEntryResponseDTO] {
        guard let fields = fields, !fields.isEmpty else { return dtos }

        let fieldSet = Set(fields)
        return dtos.map { dto in
            guard let dataDict = dto.data.dictionaryValue else { return dto }
            let filtered = dataDict.filter { fieldSet.contains($0.key) }
            return ContentEntryResponseDTO(
                id: dto.id,
                contentType: dto.contentType,
                data: .dictionary(filtered),
                status: dto.status,
                locale: dto.locale,
                publishAt: dto.publishAt,
                unpublishAt: dto.unpublishAt,
                createdBy: dto.createdBy,
                updatedBy: dto.updatedBy,
                tenantId: dto.tenantId,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt,
                publishedAt: dto.publishedAt
            )
        }
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
