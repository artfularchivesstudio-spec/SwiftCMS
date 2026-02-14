import Vapor
import Fluent
import CMSObjects
import CMSSchema
import CMSAuth
import CMSEvents

/// Dynamic content controller that handles CRUD for any content type.
/// Routes: /api/v1/:contentType
public struct DynamicContentController: RouteCollection {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let content = routes.grouped(":contentType")

        // Public routes (permission checked per request)
        content.get(use: list)
        content.get(":entryId", use: read)

        // Protected routes
        content.post(use: create)
        content.put(":entryId", use: update)
        content.delete(":entryId", use: delete)

        // Version endpoints
        content.get(":entryId", "versions", use: listVersions)
        content.get(":entryId", "versions", ":version", use: getVersion)
        content.post(":entryId", "versions", ":version", "restore", use: restoreVersion)
    }

    // MARK: - List

    /// GET /api/v1/:contentType
    ///
    /// Supported query parameters:
    /// - `page` (Int): Page number (1-based). Defaults to 1.
    /// - `perPage` (Int): Items per page (max 100). Defaults to 25.
    /// - `status` (String): Filter by content status (e.g., "published", "draft").
    /// - `locale` (String): Filter by locale (e.g., "en-US").
    /// - `sort` (String): Sort by a JSONB field, format: `fieldName:asc` or `fieldName:desc`.
    /// - `filter[fieldName]` (String): Filter by JSONB field value. Multiple filters supported.
    /// - `fields` (String): Comma-separated list of JSONB field names for sparse fieldsets.
    @Sendable
    func list(req: Request) async throws -> PaginationWrapper<ContentEntryResponseDTO> {
        let contentType = try req.parameters.require("contentType")

        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = min(req.query[Int.self, at: "perPage"] ?? 25, 100)
        let status = req.query[String.self, at: "status"]
        let locale = req.query[String.self, at: "locale"]
        let sort = req.query[String.self, at: "sort"]

        // Parse sort parameter: "fieldName:asc" or "fieldName:desc"
        var sortField: String? = nil
        var sortDir = "desc"
        if let sort = sort, !sort.isEmpty {
            let parts = sort.split(separator: ":", maxSplits: 1)
            sortField = String(parts[0])
            if parts.count > 1 {
                sortDir = String(parts[1]).lowercased() == "asc" ? "asc" : "desc"
            }
        }

        // Parse filter[fieldName]=value query parameters from the URL query string.
        // Vapor does not natively decode bracket-notation keys, so we parse the raw
        // URL query string to extract them.
        let filters = Self.parseFilterParams(from: req)

        // Parse fields parameter: "title,body,status" -> ["title", "body", "status"]
        let fields: [String]?
        if let fieldsParam = req.query[String.self, at: "fields"], !fieldsParam.isEmpty {
            fields = fieldsParam.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        } else {
            fields = nil
        }

        return try await ContentEntryService.list(
            contentType: contentType,
            on: req.db,
            page: page,
            perPage: perPage,
            status: status,
            locale: locale,
            sortField: sortField,
            sortDirection: sortDir,
            filters: filters,
            fields: fields
        )
    }

    /// Parses `filter[fieldName]=value` query parameters from the request URL.
    ///
    /// Iterates over the raw URL query string components to find parameters matching
    /// the `filter[...]` pattern and returns them as a dictionary.
    /// - Parameter req: The incoming HTTP request.
    /// - Returns: A dictionary of filter field names to values, or nil if no filters found.
    private static func parseFilterParams(from req: Request) -> [String: String]? {
        guard let queryString = req.url.query else { return nil }

        var filters: [String: String] = [:]
        let pairs = queryString.split(separator: "&")
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            guard keyValue.count == 2 else { continue }

            let rawKey = String(keyValue[0])
            let rawValue = String(keyValue[1])
                .removingPercentEncoding ?? String(keyValue[1])

            // Match filter[fieldName] pattern
            if rawKey.hasPrefix("filter%5B") || rawKey.hasPrefix("filter[") {
                let decodedKey = rawKey.removingPercentEncoding ?? rawKey
                if decodedKey.hasPrefix("filter["),
                   decodedKey.hasSuffix("]") {
                    let fieldName = String(decodedKey.dropFirst("filter[".count).dropLast(1))
                    if !fieldName.isEmpty {
                        filters[fieldName] = rawValue
                    }
                }
            }
        }

        return filters.isEmpty ? nil : filters
    }

    // MARK: - Create

    /// POST /api/v1/:contentType
    @Sendable
    func create(req: Request) async throws -> Response {
        let contentType = try req.parameters.require("contentType")
        let dto = try req.content.decode(CreateContentEntryDTO.self)

        let user = req.auth.get(CmsUser.self)
        let context = CmsContext(
            logger: req.logger,
            userId: user?.userId,
            tenantId: user?.tenantId
        )

        let response = try await ContentEntryService.create(
            contentType: contentType,
            dto: dto,
            on: req.db,
            eventBus: req.eventBus,
            context: context
        )

        let res = Response(status: .created)
        try res.content.encode(response)
        return res
    }

    // MARK: - Read

    /// GET /api/v1/:contentType/:entryId
    @Sendable
    func read(req: Request) async throws -> ContentEntryResponseDTO {
        let contentType = try req.parameters.require("contentType")
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid entry ID")
        }

        var response = try await ContentEntryService.get(
            contentType: contentType,
            id: entryId,
            on: req.db
        )

        // Handle ?populate= for relations
        if let populateParam = req.query[String.self, at: "populate"] {
            let fields = populateParam.split(separator: ",").map(String.init)
            if let typeDef = try await ContentTypeDefinition.query(on: req.db)
                .filter(\.$slug == contentType)
                .first()
            {
                let resolvedData = try await RelationResolver.resolve(
                    data: response.data,
                    schema: typeDef.jsonSchema,
                    on: req.db,
                    populateFields: fields
                )
                response = ContentEntryResponseDTO(
                    id: response.id,
                    contentType: response.contentType,
                    data: resolvedData,
                    status: response.status,
                    locale: response.locale,
                    publishAt: response.publishAt,
                    unpublishAt: response.unpublishAt,
                    createdBy: response.createdBy,
                    updatedBy: response.updatedBy,
                    tenantId: response.tenantId,
                    createdAt: response.createdAt,
                    updatedAt: response.updatedAt,
                    publishedAt: response.publishedAt
                )
            }
        }

        return response
    }

    // MARK: - Update

    /// PUT /api/v1/:contentType/:entryId
    @Sendable
    func update(req: Request) async throws -> ContentEntryResponseDTO {
        let contentType = try req.parameters.require("contentType")
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid entry ID")
        }
        let dto = try req.content.decode(UpdateContentEntryDTO.self)

        let user = req.auth.get(CmsUser.self)
        let context = CmsContext(
            logger: req.logger,
            userId: user?.userId,
            tenantId: user?.tenantId
        )

        return try await ContentEntryService.update(
            contentType: contentType,
            id: entryId,
            dto: dto,
            on: req.db,
            eventBus: req.eventBus,
            context: context
        )
    }

    // MARK: - Delete

    /// DELETE /api/v1/:contentType/:entryId
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let contentType = try req.parameters.require("contentType")
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid entry ID")
        }

        let user = req.auth.get(CmsUser.self)
        let context = CmsContext(
            logger: req.logger,
            userId: user?.userId,
            tenantId: user?.tenantId
        )

        try await ContentEntryService.delete(
            contentType: contentType,
            id: entryId,
            on: req.db,
            eventBus: req.eventBus,
            context: context
        )

        return .noContent
    }

    // MARK: - Version Endpoints

    /// GET /api/v1/:contentType/:entryId/versions
    @Sendable
    func listVersions(req: Request) async throws -> [ContentVersionResponseDTO] {
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid entry ID")
        }
        return try await VersionService.listVersions(entryId: entryId, on: req.db)
    }

    /// GET /api/v1/:contentType/:entryId/versions/:version
    @Sendable
    func getVersion(req: Request) async throws -> ContentVersionResponseDTO {
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid entry ID")
        }
        guard let version = req.parameters.get("version", as: Int.self) else {
            throw ApiError.badRequest("Invalid version number")
        }
        return try await VersionService.getVersion(entryId: entryId, version: version, on: req.db)
    }

    /// POST /api/v1/:contentType/:entryId/versions/:version/restore
    @Sendable
    func restoreVersion(req: Request) async throws -> ContentEntryResponseDTO {
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid entry ID")
        }
        guard let version = req.parameters.get("version", as: Int.self) else {
            throw ApiError.badRequest("Invalid version number")
        }
        let user = req.auth.get(CmsUser.self)
        return try await VersionService.restore(
            entryId: entryId, version: version,
            on: req.db, userId: user?.userId
        )
    }
}

// MARK: - ContentTypeController

/// Controller for managing content type definitions.
/// Routes: /api/v1/content-types
public struct ContentTypeController: RouteCollection {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let types = routes.grouped("content-types")
        types.get(use: list)
        types.get(":slug", use: get)
        types.post(use: create)
        types.put(":slug", use: update)
        types.delete(":slug", use: delete)
    }

    @Sendable
    func list(req: Request) async throws -> PaginationWrapper<ContentTypeResponseDTO> {
        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = req.query[Int.self, at: "perPage"] ?? 50
        return try await ContentTypeService.list(on: req.db, page: page, perPage: perPage)
    }

    @Sendable
    func get(req: Request) async throws -> ContentTypeResponseDTO {
        let slug = try req.parameters.require("slug")
        return try await ContentTypeService.get(slug: slug, on: req.db)
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        let dto = try req.content.decode(CreateContentTypeDTO.self)
        let user = req.auth.get(CmsUser.self)
        let context = CmsContext(logger: req.logger, userId: user?.userId, tenantId: user?.tenantId)

        let response = try await ContentTypeService.create(
            dto: dto, on: req.db, eventBus: req.eventBus, context: context
        )
        let res = Response(status: .created)
        try res.content.encode(response)
        return res
    }

    @Sendable
    func update(req: Request) async throws -> ContentTypeResponseDTO {
        let slug = try req.parameters.require("slug")
        let dto = try req.content.decode(UpdateContentTypeDTO.self)
        let user = req.auth.get(CmsUser.self)
        let context = CmsContext(logger: req.logger, userId: user?.userId, tenantId: user?.tenantId)

        return try await ContentTypeService.update(
            slug: slug, dto: dto, on: req.db, eventBus: req.eventBus, context: context
        )
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let slug = try req.parameters.require("slug")
        let force = req.query[Bool.self, at: "force"] ?? false
        let user = req.auth.get(CmsUser.self)
        let context = CmsContext(logger: req.logger, userId: user?.userId, tenantId: user?.tenantId)

        try await ContentTypeService.delete(
            slug: slug, force: force, on: req.db, eventBus: req.eventBus, context: context
        )
        return .noContent
    }
}

// MARK: - SearchController

/// Search endpoint controller.
/// Routes: /api/v1/search
public struct SearchController: RouteCollection {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        routes.get("search", use: search)
    }

    @Sendable
    func search(req: Request) async throws -> PaginationWrapper<ContentEntryResponseDTO> {
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            throw ApiError.badRequest("Query parameter 'q' is required")
        }

        let contentType = req.query[String.self, at: "type"]
        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = min(req.query[Int.self, at: "perPage"] ?? 20, 100)

        // Basic database search (Meilisearch integration comes via CMSSearch module)
        var dbQuery = ContentEntry.query(on: req.db)
            .filter(\.$deletedAt == nil)
            .filter(\.$status == "published")

        if let contentType = contentType {
            dbQuery = dbQuery.filter(\.$contentType == contentType)
        }

        let total = try await dbQuery.count()
        let entries = try await dbQuery
            .offset((page - 1) * perPage)
            .limit(perPage)
            .sort(\.$createdAt, .descending)
            .all()

        let dtos = entries.map { $0.toResponseDTO() }
        return .paginate(items: dtos, page: page, perPage: perPage, total: total)
    }
}
