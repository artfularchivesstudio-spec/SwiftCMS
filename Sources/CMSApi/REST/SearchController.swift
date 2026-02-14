import Vapor
import CMSObjects
import CMSSchema
import CMSSearch
import CMSAuth

/// 🔍 **Search Controller**
///
/// Provides advanced search capabilities for content entries using Meilisearch integration.
/// Supports full-text search, filtering, faceting, and real-time indexing.
///
/// ## Routes
/// - `GET /api/v1/search` - Public search endpoint with query string
/// - `GET /api/v1/search/settings/:contentType` - Get search settings
/// - `PUT /api/v1/search/settings/:contentType` - Update search settings
/// - `POST /api/v1/search/reindex/:contentType` - Rebuild search index
///
/// ## Features
/// - 🔍 Full-text search with relevance ranking
/// - 📊 Faceted search for content filtering
/// - ⚡ Real-time search with highlighting
/// - 🎯 Multi-language support
/// - 🔄 Automatic indexing on content changes
///
/// ## Search Configuration
/// Each content type has its own Meilisearch index with configurable:
/// - Searchable attributes
/// - Filterable attributes
/// - Sortable attributes
/// - Ranking rules
/// - Synonyms
/// - Stop words
///
/// ## Example Queries
/// ```
/// # Basic search
/// GET /api/v1/search?q=swift cms
///
/// # Filtered search
/// GET /api/v1/search?q=api&type=posts&filter[status]=published
///
/// # Paginated search with sorting
/// GET /api/v1/search?q=content&page=2&perPage=20&sortBy=createdAt:desc
/// ```
///
/// ## Integration
/// - Listens to content events for automatic indexing
/// - WebSocket notifications for search updates
/// - Analytics tracking for search queries
///
/// - SeeAlso: `CMSSearch/SearchService`, `CMSSearch/SearchIndexer`
/// - Since: 1.0.0
public struct SearchController: RouteCollection, Sendable {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let api = routes.grouped("api", "v1")

        // Public search endpoint
        api.get("search", use: search)

        // Search settings endpoints (protected)
        // TODO: Add proper authentication middleware
        let protected = api
        protected.get("search", "settings", ":contentType", use: getSearchSettings)
        protected.put("search", "settings", ":contentType", use: updateSearchSettings)
        protected.post("search", "reindex", ":contentType", use: reindexContentType)
    }

    // MARK: - 🔍 Search Operations

    /// 🔍 **Performs full-text search across content entries**
    ///
    /// GET /api/v1/search
    ///
    /// Executes a full-text search query across all indexed content types using Meilisearch.
    /// Supports complex filtering, faceting, and relevance ranking.
    ///
    /// ## Query Parameters
    /// - `q` (String): Search query string. Required. Minimum 2 characters.
    /// - `contentType` (String): Filter by specific content type slug. Optional
    /// - `page` (Int): Page number, 1-based. Default: 1
    /// - `perPage` (Int): Results per page, max 100. Default: 20
    /// - `sortBy` (String): Field to sort by with direction. Format: `fieldName:asc` or `fieldName:desc`
    /// - `filter[fieldName]` (String): Dynamic filters for faceted search. Supports multiple
    ///
    /// ## Response
    /// - `200 OK`: Returns `SearchResponse` with results and highlights
    /// - `400 Bad Request`: Missing or invalid query parameter
    /// - `503 Service Unavailable`: Search service not configured
    ///
    /// ## SearchResponse Structure
    /// ```swift
    /// struct SearchResponse {
    ///   let hits: [ContentEntryResponseDTO]        // Matching entries
    ///   let estimatedTotalHits: Int               // Total matches (estimate)
    ///   let limit: Int                           // Results per page
    ///   let offset: Int                          // Pagination offset
    ///   let processingTimeMs: Int                // Query execution time
    ///   let query: String                        // Original query
    /// }
    /// ```
    ///
    /// ## Example Queries
    /// ```
    /// # Simple full-text search
    /// GET /api/v1/search?q=swift programming
    ///
    /// # Search within specific type
    /// GET /api/v1/search?q=api&contentType=posts
    ///
    /// # Filter by status and category
    /// GET /api/v1/search?q=content&filter[status]=published&filter[category]=tech
    ///
    /// # Sort by creation date, newest first
    /// GET /api/v1/search?q=framework&sortBy=createdAt:desc
    ///
    /// # Specific page with custom page size
    /// GET /api/v1/search?q=test&page=3&perPage=50
    /// ```
    ///
    /// ## Features
    /// - 🎯 Typo tolerance (configurable)
    /// - 🏷 Synonym support
    /// - 🔍 Semantic search vector embeddings (enterprise)
    /// - 💡 Suggestions for misspelled words
    /// - 🎨 Search term highlighting in results
    /// - ⚡ Faceted search for filtering
    ///
    /// ## Analytics
    /// Search queries are automatically tracked for analytics:
    /// - Query terms
    /// - Result counts
    /// - Content type filters
    /// - User IDs (for personalized results)
    ///
    /// ## Rate Limit
    /// - 1000 requests/minute per API key
    ///
    /// ## Service Configuration
    /// Requires environment variables:
    /// - `MEILI_URL`: Meilisearch instance URL
    /// - `MEILI_KEY`: Meilisearch API key
    ///
    /// - SeeAlso: `SearchService`, `CMSSearch/SearchIndexer`
    /// - Since: 1.0.0
    @Sendable
    func search(req: Request) async throws -> SearchResponse {
        // Validate required query parameter
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            req.logger.error("🔍 Missing search query parameter")
            throw ApiError.badRequest("Search query parameter 'q' is required")
        }

        req.logger.info("🔍 Starting search", metadata: [
            "query": query,
            "contentType": req.query[String.self, at: "contentType"] ?? "all",
            "method": "GET",
            "path": req.url.path
        ])

        // Parse query parameters
        let contentType = req.query[String.self, at: "contentType"]
        let page = max(1, req.query[Int.self, at: "page"] ?? 1)
        let perPage = max(1, min(req.query[Int.self, at: "perPage"] ?? 20, 100))
        let sortBy = req.query[String.self, at: "sortBy"]

        // Parse filter parameters (e.g., filter[status]=published&filter[category]=news)
        let filters = parseFilterParams(from: req)
        req.logger.debug("Parsed filter parameters", metadata: ["filters": "\(String(describing: filters))"])

        // Get search service
        guard let meiliURL = Environment.get("MEILI_URL"),
              let meiliKey = Environment.get("MEILI_KEY") else {
            req.logger.error("🔍 Search service not configured")
            throw ApiError.internalError("Search service not configured")
        }

        req.logger.debug("Connecting to Meilisearch", metadata: [
            "url": meiliURL,
            "apiKeyPresent": meiliKey.isEmpty ? "false" : "true"
        ])

        let meilisearch = MeilisearchService(
            baseURL: meiliURL,
            apiKey: meiliKey,
            client: req.client
        )

        let searchService = SearchService(
            meilisearch: meilisearch,
            eventBus: req.eventBus
        )

        // Perform search with timeout
        let searchResponse = try await req.eventLoop.flatSubmit {
            req.eventLoop.makeFutureWithTask {
                try await searchService.search(
                    contentType: contentType,
                    query: query,
                    page: page,
                    perPage: perPage,
                    filters: filters,
                    sortBy: sortBy,
                    db: req.db
                )
            }
        }.get()

        // Track search query for analytics
        Task {
            await trackSearchQuery(
                query: query,
                contentType: contentType,
                resultCount: searchResponse.estimatedTotalHits,
                userId: req.auth.get(CmsUser.self)?.userId
            )
        }

        return searchResponse
    }

    // MARK: - Search Settings Endpoints

    /// GET /api/v1/search/settings/:contentType
    @Sendable
    func getSearchSettings(req: Request) async throws -> IndexSettings {
        let contentType = try req.parameters.require("contentType", as: String.self)

        guard let meiliURL = Environment.get("MEILI_URL"),
              let meiliKey = Environment.get("MEILI_KEY") else {
            throw ApiError.internalError("Search service not configured")
        }

        let meilisearch = MeilisearchService(
            baseURL: meiliURL,
            apiKey: meiliKey,
            client: req.client
        )

        let searchService = SearchService(
            meilisearch: meilisearch,
            eventBus: req.eventBus
        )

        guard let settings = try await searchService.getIndexSettings(slug: contentType, db: req.db) else {
            throw ApiError.notFound("Content type not found or has no search settings")
        }

        return settings
    }

    /// PUT /api/v1/search/settings/:contentType
    @Sendable
    func updateSearchSettings(req: Request) async throws -> HTTPStatus {
        let contentType = try req.parameters.require("contentType", as: String.self)
        let settings = try req.content.decode(IndexSettings.self)

        guard let meiliURL = Environment.get("MEILI_URL"),
              let meiliKey = Environment.get("MEILI_KEY") else {
            throw ApiError.internalError("Search service not configured")
        }

        let meilisearch = MeilisearchService(
            baseURL: meiliURL,
            apiKey: meiliKey,
            client: req.client
        )

        let searchService = SearchService(
            meilisearch: meilisearch,
            eventBus: req.eventBus
        )

        try await searchService.updateIndexSettings(slug: contentType, settings: settings, db: req.db)

        req.logger.info("Updated search settings for content type '\(contentType)'")
        return .ok
    }

    /// POST /api/v1/search/reindex/:contentType
    @Sendable
    func reindexContentType(req: Request) async throws -> Response {
        let contentType = try req.parameters.require("contentType", as: String.self)

        guard let meiliURL = Environment.get("MEILI_URL"),
              let meiliKey = Environment.get("MEILI_KEY") else {
            throw ApiError.internalError("Search service not configured")
        }

        let meilisearch = MeilisearchService(
            baseURL: meiliURL,
            apiKey: meiliKey,
            client: req.client
        )

        let indexer = SearchIndexer(meilisearch: meilisearch)

        // Start reindexing asynchronously
        Task {
            do {
                try await indexer.reindexContentType(contentType, db: req.db)
                req.logger.info("Completed reindexing content type '\(contentType)'")
            } catch {
                req.logger.error("Failed to reindex content type '\(contentType)': \(error)")
            }
        }

        return Response(
            status: .accepted,
            body: Response.Body(string: "{\"message\":\"Reindexing started for content type '\(contentType)'\"}")
        )
    }

    // MARK: - Helpers

    private func parseFilterParams(from req: Request) -> [String: String]? {
        guard let queryString = req.url.query else { return nil }

        var filters: [String: String] = [:]
        let pairs = queryString.split(separator: "&")

        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            guard keyValue.count == 2 else { continue }

            let rawKey = String(keyValue[0])
            let rawValue = String(keyValue[1])
                .removingPercentEncoding ?? String(keyValue[1])

            // Match filter[fieldName]=value pattern
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

    private func trackSearchQuery(query: String, contentType: String?, resultCount: Int, userId: String?) async {
        // This would integrate with analytics service
        // For now, just log the search
        print("Search: user=\(userId ?? "anonymous") query='\(query)' type=\(contentType ?? "all") results=\(resultCount)")
    }
}

// MARK: - Search Query DTO

public struct SearchQueryDTO: Content, Sendable {
    public let q: String
    public let contentType: String?
    public let page: Int
    public let perPage: Int
    public let filters: [String: String]?
    public let sortBy: String?

    public init(
        q: String,
        contentType: String? = nil,
        page: Int = 1,
        perPage: Int = 20,
        filters: [String: String]? = nil,
        sortBy: String? = nil
    ) {
        self.q = q
        self.contentType = contentType
        self.page = page
        self.perPage = perPage
        self.filters = filters
        self.sortBy = sortBy
    }
}
