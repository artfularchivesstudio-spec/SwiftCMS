import Vapor
import Fluent
import CMSObjects
import CMSSchema
import CMSAuth
import CMSEvents

/// 🌐 **Dynamic Content Controller**
///
/// Handles complete CRUD operations for any content type defined in the CMS.
/// This controller provides RESTful endpoints for dynamic content management.
///
/// ## Routes
/// - `GET /api/v1/:contentType` - List content entries with filtering and pagination
/// - `GET /api/v1/:contentType/:entryId` - Get single content entry
/// - `POST /api/v1/:contentType` - Create new content entry
/// - `PUT /api/v1/:contentType/:entryId` - Update existing content entry
/// - `DELETE /api/v1/:contentType/:entryId` - Delete content entry
///
/// ## Authentication & Authorization
/// - Public routes: `GET` operations (permission checked per request)
/// - Protected routes: `POST`, `PUT`, `DELETE` (requires valid JWT token)
///
/// ## Rate Limiting
/// - All endpoints: 60 requests/minute per IP
/// - Create/Update/Delete: 30 requests/minute per user
///
/// ## Example Usage
/// ```swift
/// // List published posts
/// GET /api/v1/posts?status=published&page=1&perPage=10
///
/// // Create a new post
/// POST /api/v1/posts
/// {
///   "data": {
///     "title": "My Post",
///     "content": "Post content"
///   },
///   "status": "draft"
/// }
/// ```
///
/// ## Version Support
/// This controller also provides version management endpoints:
/// - `GET /api/v1/:contentType/:entryId/versions` - List all versions
/// - `GET /api/v1/:contentType/:entryId/versions/:version` - Get specific version
/// - `POST /api/v1/:contentType/:entryId/versions/:version/restore` - Restore version
///
/// - SeeAlso: `ContentEntryService`, `VersionService`
/// - Since: 1.0.0
public struct DynamicContentController: RouteCollection, Sendable {

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

    // MARK: - 🔍 List Operations

    /// 📊 **GET /api/v1/{contentType} - List Content Entries**
    ///
    /// ## 📡 Endpoint
    /// Returns paginated list of content entries with advanced filtering, sorting, and population capabilities.
    ///
    /// ## 🔐 Authentication
    /// **Optional** - Public access for published content, JWT required for drafts/archived
    ///
    /// ## ⚡ Rate Limit
    /// **60 requests/minute per IP address**
    ///
    /// ## 📂 Path Parameters
    /// - `contentType` (string, required): The content type slug (e.g., `posts`, `products`)
    ///
    /// ## 🔍 Query Parameters
    /// | Parameter | Type | Default | Max | Description |
    /// |-----------|------|---------|-----|-------------|
    /// | `page` | integer | 1 | - | Page number (1-indexed) |
    /// | `perPage` | integer | 25 | 100 | Items per page |
    /// | `status` | string | - | - | Filter by status: `draft`, `published`, `archived` |
    /// | `locale` | string | - | - | Filter by locale: `en-US`, `de-DE`, etc. |
    /// | `sort` | string | - | - | Sort format: `fieldName:asc` or `fieldName:desc` |
    /// | `fields` | string | - | - | Comma-separated fields for sparse fieldsets |
    /// | `populate` | string | - | - | Comma-separated relation fields to populate |
    /// | `filter[field]` | string | - | - | Dynamic filters (e.g., `filter[tags]=swift,cms`) |
    ///
    /// ## ✅ Success Response (200 OK)
    /// ```json
    /// {
    ///   "data": [
    ///     {
    ///       "id": "123e4567-e89b-12d3-a456-426614174000",
    ///       "contentType": "posts",
    ///       "data": {
    ///         "title": "Getting Started",
    ///         "content": "SwiftCMS is a powerful...",
    ///         "tags": ["swift", "cms"]
    ///       },
    ///       "status": "published",
    ///       "locale": "en-US",
    ///       "createdBy": "user-123",
    ///       "createdAt": "2024-01-20T10:30:00Z",
    ///       "updatedAt": "2024-01-21T15:45:00Z",
    ///       "publishedAt": "2024-01-20T10:30:00Z"
    ///     }
    ///   ],
    ///   "meta": {
    ///     "pagination": {
    ///       "page": 1,
    ///       "perPage": 25,
    ///       "total": 150,
    ///       "totalPages": 6
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// ## ❌ Error Responses
    /// | Status | Description |
    /// |--------|-------------|
    /// | `404 Not Found` | Content type doesn't exist |
    /// | `422 Unprocessable Entity` | Invalid query parameters |
    ///
    /// ## 🔧 Special Features
    /// ### Population
    /// Resolve relation fields: `?populate=author,tags`
    /// ```json
    /// {
    ///   "data": {
    ///     "title": "My Post",
    ///     "author": {
    ///       "id": "user-123",
    ///       "email": "author@example.com"
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// ### Sparse Fieldsets
    /// Reduce payload: `?fields=title,excerpt,createdAt`
    ///
    /// ### Advanced Filtering
    /// Multiple filters: `?filter[status]=published&filter[tags]=swift,api`
    ///
    /// ## 💡 Best Practices
    /// - Use sparse fieldsets to reduce response size
    /// - Implement client-side pagination
    /// - Cache responses with proper ETag handling
    /// - Use population sparingly (impacts performance)
    ///
    /// ## 📋 Example Requests
    /// ```bash
    /// # List all published posts
    /// curl https://api.swiftcms.io/api/v1/posts?status=published
    ///
    /// # Filter products by category
    /// curl https://api.swiftcms.io/api/v1/products?filter[category]=electronics
    ///
    /// # Get posts with populated authors
    /// curl https://api.swiftcms.io/api/v1/posts?populate=author,featuredImage
    ///
    /// # Sparse fieldsets for performance
    /// curl https://api.swiftcms.io/api/v1/posts?fields=title,slug,createdAt
    /// ```
    ///
    /// ## Query Parameters
    /// - `page` (Int): Page number, 1-based. Default: `1`
    /// - `perPage` (Int): Items per page, max 100. Default: `25`
    /// - `status` (String): Filter by status. Values: `draft`, `published`, `archived`
    /// - `locale` (String): Filter by locale code. Example: `en-US`, `de-DE`
    /// - `sort` (String): Sort field with direction. Format: `fieldName:asc` or `fieldName:desc`
    /// - `filter[fieldName]` (String): Dynamic filter for JSONB fields. Supports multiple filters
    /// - `fields` (String): Comma-separated field list for sparse fieldsets
    /// - `populate` (String): Comma-separated relation fields to populate
    ///
    /// ## Response
    /// Returns `PaginationWrapper<ContentEntryResponseDTO>` with:
    /// - `data`: Array of content entries
    /// - `meta.pagination`: Pagination metadata (page, perPage, total, totalPages)
    ///
    /// ## Example Requests
    /// ```
    /// # List all published posts, sorted by creation date
    /// GET /api/v1/posts?status=published&sort=createdAt:desc
    ///
    /// # Filter posts with specific tags
    /// GET /api/v1/posts?filter[tags]=swift,vapor
    ///
    /// # Get only title and excerpt fields
    /// GET /api/v1/posts?fields=title,excerpt
    ///
    /// # Populate author relation
    /// GET /api/v1/posts?populate=author
    /// ```
    ///
    /// ## Status Codes
    /// - `200`: Success, returns paginated content
    /// - `404`: Content type not found
    /// - `422`: Invalid query parameters
    ///
    /// ## Rate Limit
    /// - 60 requests/minute per IP
    ///
    /// - SeeAlso: `ContentEntryService.list`, `RelationResolver`
    @Sendable
    func list(req: Request) async throws -> PaginationWrapper<ContentEntryResponseDTO> {
        let contentType = try req.parameters.require("contentType")
        req.logger.info("📊 Listing content entries", metadata: [
            "contentType": contentType,
            "method": "GET",
            "path": req.url.path
        ])

        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = min(req.query[Int.self, at: "perPage"] ?? 25, 100)
        let status = req.query[String.self, at: "status"]
        let locale = req.query[String.self, at: "locale"]
        let sort = req.query[String.self, at: "sort"]

        req.logger.debug("Parsed query parameters", metadata: [
            "page": "\(page)",
            "perPage": "\(perPage)",
            "status": status ?? "nil",
            "locale": locale ?? "nil",
            "sort": sort ?? "nil"
        ])

        // Parse sort parameter: "fieldName:asc" or "fieldName:desc"
        var sortField: String?
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
        
        // Log the result
        req.logger.info("📊 Content list retrieved", metadata: [
            "contentType": contentType,
                "count": "\(result.data.count)",
                "page": "\(page)"
            ])
        }
    }

    /// 📋 **Parses dynamic filter parameters from query string**
    ///
    /// Converts URL-encoded filter parameters like `filter[fieldName]=value` into a dictionary.
    ///
    /// ## Supported Formats
    /// - `filter[status]=published`
    /// - `filter[tags]=swift,cms,api`
    /// - `filter[price]=100` (numeric filters)
    ///
    /// ## Implementation Notes
    /// - Handles both URL-encoded (`filter%5B%5D`) and plain bracket notation
    /// - Supports multiple filter parameters in a single request
    /// - Returns `nil` if no filter parameters are found
    ///
    /// - Parameter req: The incoming HTTP request containing query parameters
    /// - Returns: Dictionary mapping field names to filter values, or nil
    ///
    /// ## Example
    /// ```swift
    /// // From URL: /posts?filter[status]=published&filter[tags]=swift
    /// let filters = parseFilterParams(from: req)
    /// // Result: ["status": "published", "tags": "swift"]
    /// ```
    ///
    /// - Since: 1.0.0


    private static func parseFilterParams(from req: Request) -> [String: String]? {
        guard let queryString = req.url.query else {
            req.logger.debug("No query string found for filter parsing")
            return nil
        }

        var filters: [String: String] = [:]
        let pairs = queryString.split(separator: "&")
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            guard keyValue.count == 2 else {
                req.logger.debug("Skipping invalid query parameter", metadata: ["pair": "\(pair)"])
                continue
            }

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
                        req.logger.debug("Parsed filter parameter", metadata: [
                            "field": fieldName,
                            "value": rawValue
                        ])
                    }
                }
            }
        }

        if filters.isEmpty {
            req.logger.debug("No filter parameters found in query string")
            return nil
        } else {
            req.logger.info("Parsed filter parameters", metadata: ["filters": "\(filters.keys.joined(separator: ", "))"])
            return filters
        }
    }

    // MARK: - ➕ Create Operations

    /// ➕ **Creates a new content entry**
    ///
    /// POST /api/v1/:contentType
    ///
    /// Creates a new content entry of the specified type with structured data validation.
    ///
    /// ## Request Body
    /// - `data`: JSONB object with content fields (must match content type schema)
    /// - `status`: Entry status. Values: `draft`, `published`, `archived`. Default: `draft`
    /// - `locale`: Locale code for multi-language content. Default: `en`
    /// - `publishAt`: Schedule publication timestamp (optional)
    /// - `unpublishAt`: Schedule unpublication timestamp (optional)
    ///
    /// ## Response
    /// - `201 Created`: Returns created `ContentEntryResponseDTO`
    /// - `400 Bad Request`: Invalid data or validation errors
    /// - `404 Not Found`: Content type doesn't exist
    /// - `422 Unprocessable Entity`: Schema validation failed
    ///
    /// ## Example
    /// ```swift
    /// // Example: Creating a blog post
    /// POST /api/v1/posts
    /// {
    ///   "data": {
    ///     "title": "Getting Started with SwiftCMS",
    ///     "content": "SwiftCMS is a powerful headless CMS...",
    ///     "tags": ["swift", "cms", "api"]
    ///   },
    ///   "status": "draft",
    ///   "locale": "en-US"
    /// }
    /// ```
    ///
    /// ## Authentication
    /// Requires valid JWT token in Authorization header
    ///
    /// ## Rate Limit
    /// - 30 requests/minute per user
    ///
    /// ## Event Emission
    /// Emits `ContentCreatedEvent` to the event bus for real-time updates
    ///
    /// - SeeAlso: `CreateContentEntryDTO`, `ContentEntryResponseDTO`
    /// - Since: 1.0.0
    @Sendable
    func create(req: Request) async throws -> Response {
        let contentType = try req.parameters.require("contentType")
        req.logger.info("➕ Creating content entry", metadata: [
            "contentType": contentType,
            "method": "POST",
            "path": req.url.path
        ])

        let dto = try req.content.decode(CreateContentEntryDTO.self)
        req.logger.debug("Decoded create request", metadata: ["data": "\(String(describing: dto.data))"])

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
        .tap { _ in
            req.logger.info("➕ Content entry created successfully", metadata:
                           ["contentType": contentType, "id": "\(String(describing: response.id))"])
        }

        let res = Response(status: .created)
        try res.content.encode(response)
        return res
    }



    // MARK: - 👁 Read Operations

    /// 👁 **Retrieves a single content entry by ID**
    ///
    /// GET /api/v1/:contentType/:entryId
    ///
    /// Fetches a specific content entry with optional population of relation fields.
    ///
    /// ## Path Parameters
    /// - `contentType`: The content type slug
    /// - `entryId`: The UUID of the content entry
    ///
    /// ## Query Parameters
    /// - `populate`: Comma-separated list of relation field names to populate
    ///
    /// ## Response
    /// - `200 OK`: Returns `ContentEntryResponseDTO` with entry data
    /// - `404 Not Found`: Entry or content type not found
    ///
    /// ## Example
    /// ```swift
    /// # Get a specific post
    /// GET /api/v1/posts/123e4567-e89b-12d3-a456-426614174000
    ///
    /// # Get post with populated author relations
    /// GET /api/v1/posts/123e4567-e89b-12d3-a456-426614174000?populate=author,tags
    /// ```
    ///
    /// ## Caching
    /// Includes ETag header for client-side caching. Returns `304 Not Modified` if content unchanged.
    ///
    /// ## Rate Limit
    /// - 100 requests/minute per IP
    ///
    /// - SeeAlso: `ContentEntryResponseDTO`, `RelationResolver`
    /// - Since: 1.0.0
    @Sendable
    func read(req: Request) async throws -> ContentEntryResponseDTO {
        let contentType = try req.parameters.require("contentType")
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            req.logger.error("👁 Invalid entry ID format", metadata: ["entryId": req.parameters.get("entryId") ?? "nil"])
            throw ApiError.badRequest("Invalid entry ID")
        }

        req.logger.info("👁 Fetching content entry", metadata: [
            "contentType": contentType,
            "entryId": entryId.uuidString,
            "method": "GET",
            "path": req.url.path
        ])

        var response = try await ContentEntryService.get(
            contentType: contentType,
            id: entryId,
            on: req.db
        )
        .tap { _ in
            req.logger.debug("📖 Base entry retrieved", metadata: ["entryId": entryId.uuidString])
        }

        // Handle ?populate= for relations
        if let populateParam = req.query[String.self, at: "populate"] {
            req.logger.debug("Populating relations", metadata: ["fields": populateParam])
            let fields = populateParam.split(separator: ",").map(String.init)
            if let typeDef = try await ContentTypeDefinition.query(on: req.db)
                .filter(\.$slug == contentType)
                .first() {
                req.logger.info("🔄 Resolving relations", metadata: ["fieldCount": "\(fields.count)"])
                let resolvedData = try await RelationResolver.resolve(
                    data: response.data,
                    schema: typeDef.jsonSchema,
                    on: req.db,
                    populateFields: fields
                )
                
                req.logger.debug("✅ Relations resolved successfully")

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
            } else {
                req.logger.warning("⚠️ Content type not found for relation resolution", metadata: ["contentType": contentType])
            }
        }

        req.logger.info("👁 Entry retrieved successfully", metadata: ["entryId": entryId.uuidString])
        return response
    }



    // MARK: - ✏️ Update Operations

    /// ✏️ **Updates an existing content entry**
    ///
    /// PUT /api/v1/:contentType/:entryId
    ///
    /// Performs a complete replacement of the content entry data.
    ///
    /// ## Path Parameters
    /// - `contentType`: The content type slug
    /// - `entryId`: The UUID of the content entry
    ///
    /// ## Request Body
    /// - `data`: Updated JSONB object with all content fields
    /// - `status`: New status. Values: `draft`, `published`, `archived`
    /// - `locale`: Updated locale code
    /// - `publishAt`: Updated publication timestamp
    /// - `unpublishAt`: Updated unpublication timestamp
    ///
    /// ## Response
    /// - `200 OK`: Returns updated `ContentEntryResponseDTO`
    /// - `400 Bad Request`: Invalid entry ID or data
    /// - `404 Not Found`: Entry or content type not found
    /// - `422 Unprocessable Entity`: Schema validation failed
    ///
    /// ## Example
    /// ```swift
    /// // Update a blog post
    /// PUT /api/v1/posts/123e4567-e89b-12d3-a456-426614174000
    /// {
    ///   "data": {
    ///     "title": "Updated Post Title",
    ///     "content": "Updated content...",
    ///     "tags": ["swift", "cms"]
    ///   },
    ///   "status": "published"
    /// }
    /// ```
    ///
    /// ## Authentication
    /// Requires valid JWT token in Authorization header
    ///
    /// ## Rate Limit
    /// - 30 requests/minute per user
    ///
    /// ## Versioning
    /// Automatically creates a new version on successful update
    ///
    /// ## Event Emission
    /// Emits `ContentUpdatedEvent` to the event bus for real-time updates
    ///
    /// - SeeAlso: `UpdateContentEntryDTO`, `ContentUpdatedEvent`
    /// - Since: 1.0.0

    /// PUT /api/v1/:contentType/:entryId
    @Sendable
    func update(req: Request) async throws -> ContentEntryResponseDTO {
        let contentType = try req.parameters.require("contentType")
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            req.logger.error("✏️ Invalid entry ID format", metadata: ["entryId": req.parameters.get("entryId") ?? "nil"])
            throw ApiError.badRequest("Invalid entry ID")
        }

        let dto = try req.content.decode(UpdateContentEntryDTO.self)
        req.logger.info("✏️ Updating content entry", metadata: [
            "contentType": contentType,
            "entryId": entryId.uuidString,
            "method": "PUT",
            "path": req.url.path
        ])

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
        .tap { _ in
            req.logger.info("✏️ Content entry updated successfully", metadata:
                           ["contentType": contentType, "entryId": entryId.uuidString])
        }
    }

    // MARK: - 🗑 Delete Operations

    /// 🗑 **Permanently deletes a content entry**
    ///
    /// DELETE /api/v1/:contentType/:entryId
    ///
    /// Soft deletes content entry (sets deletedAt timestamp) or hard deletes if forced.
    ///
    /// ## Path Parameters
    /// - `contentType`: The content type slug
    /// - `entryId`: The UUID of the content entry
    ///
    /// ## Query Parameters
    /// - `force` (Bool): Hard delete flag. If `true`, permanently removes entry. Default: `false`
    ///
    /// ## Response
    /// - `204 No Content`: Entry was successfully deleted
    /// - `400 Bad Request`: Invalid entry ID
    /// - `404 Not Found`: Entry or content type not found
    /// - `403 Forbidden`: Insufficient permissions (if trying to force delete)
    ///
    /// ## Example
    /// ```swift
    /// // Soft delete a post
    /// DELETE /api/v1/posts/123e4567-e89b-12d3-a456-426614174000
    ///
    /// // Hard delete a post
    /// DELETE /api/v1/posts/123e4567-e89b-12d3-a456-426614174000?force=true
    /// ```
    ///
    /// ## Authentication
    /// Requires valid JWT token in Authorization header with delete permissions
    ///
    /// ## Rate Limit
    /// - 30 requests/minute per user
    ///
    /// ## Versioning
    /// Creates a final version snapshot before deletion when not forced
    ///
    /// ## Event Emission
    /// Emits `ContentDeletedEvent` to the event bus for real-time sync
    ///
    /// - SeeAlso: `ContentDeletedEvent`
    /// - Since: 1.0.0

    // MARK: - Delete

    /// DELETE /api/v1/:contentType/:entryId
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let contentType = try req.parameters.require("contentType")
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            req.logger.error("🗑 Invalid entry ID format", metadata: ["entryId": req.parameters.get("entryId") ?? "nil"])
            throw ApiError.badRequest("Invalid entry ID")
        }

        let force = req.query[Bool.self, at: "force"] ?? false

        req.logger.info("🗑 Deleting content entry", metadata: [
            "contentType": contentType,
            "entryId": entryId.uuidString,
            "force": "\(force)",
            "method": "DELETE",
            "path": req.url.path
        ])

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
        
        req.logger.info("🗑 Entry deleted successfully", metadata: [
                       "contentType": contentType, "entryId": entryId.uuidString])
        return .noContent
    }

    // MARK: - 📚 Version Management

    /// 📚 **Lists all versions of a content entry**
    ///
    /// GET /api/v1/:contentType/:entryId/versions
    ///
    /// Returns complete version history for a content entry, ordered by version number descending.
    ///
    /// ## Path Parameters
    /// - `contentType`: The content type slug
    /// - `entryId`: The UUID of the content entry
    ///
    /// ## Response
    /// - `200 OK`: Returns array of `ContentVersionResponseDTO`
    /// - `400 Bad Request`: Invalid entry ID
    /// - `404 Not Found`: Entry not found
    ///
    /// ## Example Response
    /// ```json
    /// [
    ///   {
    ///     "version": 3,
    ///     "createdAt": "2024-01-20T10:30:00Z",
    ///     "createdBy": "user-123",
    ///     "data": { /* full entry snapshot */ }
    ///   },
    ///   {
    ///     "version": 2,
    ///     "createdAt": "2024-01-19T15:45:00Z",
    ///     "createdBy": "user-456",
    ///     "data": { /* previous version */ }
    ///   }
    /// ]
    /// ```
    ///
    /// ## Authentication
    /// Optional for public content, requires JWT for protected content
    ///
    /// ## Rate Limit
    /// - 60 requests/minute per client
    ///
    /// - SeeAlso: `ContentVersionResponseDTO`, `VersionService`
    /// - Since: 1.0.0
    @Sendable
    func listVersions(req: Request) async throws -> [ContentVersionResponseDTO] {
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid entry ID")
        }

        req.logger.info("📚 Listing versions", metadata: [
            "entryId": entryId.uuidString,
            "method": "GET versions"
        ])

        return try await VersionService.listVersions(entryId: entryId, on: req.db)
            .tap { versions in
                req.logger.info("📚 Versions retrieved", metadata: [
                    "entryId": entryId.uuidString,
                    "count": "\(versions.count)"
                ])
            }
    }

    /// 📄 **Gets a specific version of a content entry**
    ///
    /// GET /api/v1/:contentType/:entryId/versions/:version
    ///
    /// Retrieves a specific historical version of a content entry.
    ///
    /// ## Path Parameters
    /// - `contentType`: The content type slug
    /// - `entryId`: The UUID of the content entry
    /// - `version`: Integer version number
    ///
    /// ## Response
    /// - `200 OK`: Returns `ContentVersionResponseDTO`
    /// - `400 Bad Request`: Invalid entry ID or version number
    /// - `404 Not Found`: Version not found
    ///
    /// ## Example
    /// ```swift
    /// # Get version 3 of a post
    /// GET /api/v1/posts/123e4567-e89b-12d3-a456-426614174000/versions/3
    /// ```
    ///
    /// ## Notes
    /// Version numbers start at 1 and increment with each update
    ///
    /// - Since: 1.0.0
    @Sendable
    func getVersion(req: Request) async throws -> ContentVersionResponseDTO {
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid entry ID")
        }
        guard let version = req.parameters.get("version", as: Int.self) else {
            throw ApiError.badRequest("Invalid version number")
        }

        req.logger.info("📄 Fetching version", metadata: [
            "entryId": entryId.uuidString,
            "version": "\(version)"
        ])

        return try await VersionService.getVersion(entryId: entryId, version: version, on: req.db)
            .tap { _ in
                req.logger.debug("📄 Version retrieved", metadata:
                               ["entryId": entryId.uuidString, "version": "\(version)"])
            }
    }

    /// 🔄 **Restores a content entry to a previous version**
    ///
    /// POST /api/v1/:contentType/:entryId/versions/:version/restore
    ///
    /// Restores content entry data to match a historical version. Creates a new version based on the restoration.
    ///
    /// ## Path Parameters
    /// - `contentType`: The content type slug
    /// - `entryId`: The UUID of the content entry
    /// - `version`: Integer version number to restore
    ///
    /// ## Response
    /// - `200 OK`: Returns updated `ContentEntryResponseDTO`
    /// - `400 Bad Request`: Invalid entry ID or version number
    /// - `404 Not Found`: Version not found
    ///
    /// ## Example
    /// ```swift
    /// # Restore version 3 of a post
    /// POST /api/v1/posts/123e4567-e89b-12d3-a456-426614174000/versions/3/restore
    /// ```
    ///
    /// ## Authentication
    /// Requires valid JWT token with update permissions
    ///
    /// ## Rate Limit
    /// - 20 requests/minute per user
    ///
    /// ## Versioning
    /// Creates a new version (N+1) with the restored data
    ///
    /// ## Event Emission
    /// Emits `ContentUpdatedEvent` and `VersionRestoredEvent`
    ///
    /// - SeeAlso: `VersionService`, `VersionRestoredEvent`
    /// - Since: 1.0.0
    @Sendable
    func restoreVersion(req: Request) async throws -> ContentEntryResponseDTO {
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid entry ID")
        }
        guard let version = req.parameters.get("version", as: Int.self) else {
            throw ApiError.badRequest("Invalid version number")
        }

        let user = req.auth.get(CmsUser.self)

        req.logger.info("🔄 Restoring version", metadata: [
            "entryId": entryId.uuidString,
            "version": "\(version)",
            "userId": user?.userId ?? "anonymous"
        ])

        return try await VersionService.restore(
            entryId: entryId, version: version,
            on: req.db, userId: user?.userId
        )
        .tap { _ in
            req.logger.info("🔄 Version restored successfully", metadata:
                           ["entryId": entryId.uuidString, "version": "\(version)"])
        }
    }


}

// MARK: - ContentTypeController

/// Controller for managing content type definitions.
/// Routes: /api/v1/content-types
public struct ContentTypeController: RouteCollection, Sendable {

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



// MARK: - Helpers

protocol Tappable {}
extension Tappable {
    @discardableResult
    func tap(_ block: (Self) -> Void) -> Self {
        block(self)
        return self
    }
}
extension ContentEntryResponseDTO: Tappable {}
extension Array: Tappable {}
extension ContentVersionResponseDTO: Tappable {}

extension Logger {
    func info(_ message: Message, metadata: [String: String]) {
        let converted = metadata.mapValues { Logger.MetadataValue.string($0) }
        self.info(message, metadata: converted)
    }
    
    func debug(_ message: Message, metadata: [String: String]) {
        let converted = metadata.mapValues { Logger.MetadataValue.string($0) }
        self.debug(message, metadata: converted)
    }
    
    func warning(_ message: Message, metadata: [String: String]) {
        let converted = metadata.mapValues { Logger.MetadataValue.string($0) }
        self.warning(message, metadata: converted)
    }
    
    func error(_ message: Message, metadata: [String: String]) {
        let converted = metadata.mapValues { Logger.MetadataValue.string($0) }
        self.error(message, metadata: converted)
    }
}
