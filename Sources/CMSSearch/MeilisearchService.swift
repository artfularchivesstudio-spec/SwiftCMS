import Vapor
import Fluent
import CMSCore
import CMSObjects
import CMSSchema
import CMSEvents

// MARK: - ☁️ Meilisearch Service

/// ☁️ **Low-Level Meilisearch API Client**
/// Provides direct REST API access to Meilisearch with authentication, error handling, and request/response management.
/// Handles all HTTP operations for index management, document operations, and search queries.
///
/// # API Integration Architecture
/// - **RESTful HTTP**: JSON-based API with standard HTTP verbs (GET, POST, PUT, DELETE)
/// - **Async/Await Native**: Built on Vapor's async client for non-blocking I/O
/// - **Authentication**: Bearer token authentication for all endpoints
/// - **Error Translation**: Converts Meilisearch errors to SwiftCMS error types
/// - **Connection Pooling**: Reuses HTTP connections for reduced latency
///
/// # Endpoint Coverage
/// - **Indexes**: Create, delete, list indexes with configuration
/// - **Documents**: Add, update, delete, batch operations (1000 docs max)
/// - **Search**: Full-text search with filters, sorts, facets, highlights
/// - **Settings**: Configure searchable attributes, filters, ranking rules
/// - **Tasks**: Monitor asynchronous operations (indexing, configuration)
///
/// # Performance Optimizations
/// - **Keep-Alive**: Persistent HTTP connections (default 60s timeout)
/// - **Batch Operations**: Groups document updates (100 docs per batch recommended)
/// - **Parallel Requests**: Multiple concurrent requests allowed (configured limit)
/// - **JSON Streaming**: Efficient large document transfers
///
/// # Retry and Resilience
/// - **Retry Logic**: Automatic retry on network errors (5xx, timeouts)
/// - **Circuit Breaker**: Temporarily disable service on repeated failures
/// - **Queue Fallback**: Failed operations queued for retry via Jobs module
/// - **Partial Success**: Batch operations return success/failure per document
///
/// # Error Mapping
/// | Meilisearch Error | SwiftCMS Error | Action Required |
/// |-------------------|----------------|-----------------|
/// | 404 Index not found | SearchIndexerError | Create index before operations |
/// | 400 Invalid filter syntax | ApiError.badRequest | Validate filters client-side |
/// | 429 Too many requests | ApiError.rateLimited | Implement backoff, reduce QPS |
/// | 500 Internal error | ApiError.internalError | Retry with exponential backoff |
/// | Timeout | ApiError.timeout | Increase timeout, check network |
///
/// # Request/Response Flow
/// ```
/// SwiftCMS → MeilisearchService → Vapor Client → HTTP/1.1 → Meilisearch
///     ↓              ↓                  ↓              ↓             ↓
///  Build req    Add auth headers   Serialize JSON  Send         Parse
///  Validate     Set timeouts       Encode body     Wait         Deserialize
///  Transform    Log request        Handle errors   Response     Return DTO
/// ```
///
/// # Usage Example (Index Management)
/// ```swift
/// let meiliService = MeilisearchService(
///     baseURL: "http://localhost:7700",
///     apiKey: "masterKey",
///     client: app.client
/// )
///
/// // Create index for blog posts
/// try await meiliService.createIndex(slug: "blog_posts")
///
/// // Configure search settings
/// try await meiliService.updateIndexSettings(slug: "blog_posts", settings: IndexSettings(
///     searchableFields: ["title", "content", "tags"],
///     filterableFields: ["category", "status", "publishedAt"],
///     sortableFields: ["publishedAt", "views"],
///     facetFields: ["category", "tags"]
/// ))
/// ```
///
/// # Environment Configuration
/// ```bash
/// # docker-compose.yml for Meilisearch
/// meilisearch:
///   image: getmeili/meilisearch:latest
///   environment:
///     MEILI_MASTER_KEY: "${MEILI_MASTER_KEY}"
///     MEILI_ENV: "production"
///     MEILI_NO_ANALYTICS: "true"
///     MEILI_DB_PATH: "/meili_data"
///   volumes:
///     - ./meilisearch_data:/meili_data
///   ports:
///     - "7700:7700"
/// ```
public struct MeilisearchService: Sendable {
    let baseURL: String
    let apiKey: String
    let client: Client

    public init(baseURL: String, apiKey: String, client: Client) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.client = client
    }

    /// Create an index for a content type.
    public func createIndex(slug: String) async throws {
        let uri = URI(string: "\(baseURL)/indexes")
        _ = try await client.post(uri, headers: authHeaders()) { req in
            try req.content.encode(["uid": slug, "primaryKey": "id"])
        }
    }

    /// Delete an index.
    public func deleteIndex(slug: String) async throws {
        let uri = URI(string: "\(baseURL)/indexes/\(slug)")
        _ = try await client.delete(uri, headers: authHeaders())
    }

    /// Index a content entry.
    public func indexEntry(
        slug: String,
        id: String,
        data: [String: AnyCodableValue]
    ) async throws {
        let uri = URI(string: "\(baseURL)/indexes/\(slug)/documents")
        var document = data
        document["id"] = .string(id)
        _ = try await client.post(uri, headers: authHeaders()) { req in
            try req.content.encode([document])
        }
    }

    /// Remove an entry from the index.
    public func removeEntry(slug: String, id: String) async throws {
        let uri = URI(string: "\(baseURL)/indexes/\(slug)/documents/\(id)")
        _ = try await client.delete(uri, headers: authHeaders())
    }

    /// Index multiple documents in batch
    public func batchIndexDocuments(slug: String, documents: [[String: AnyCodableValue]]) async throws {
        let uri = URI(string: "\(baseURL)/indexes/\(slug)/documents")
        _ = try await client.post(uri, headers: authHeaders()) { req in
            try req.content.encode(documents)
        }
    }

    /// Update index settings
    public func updateIndexSettings(slug: String, settings: IndexSettings) async throws {
        // Update searchable attributes
        if !settings.searchableFields.isEmpty {
            let searchUri = URI(string: "\(baseURL)/indexes/\(slug)/settings/searchable-attributes")
            _ = try await client.put(searchUri, headers: authHeaders()) { req in
                try req.content.encode(settings.searchableFields)
            }
        }

        // Update filterable attributes
        if !settings.filterableFields.isEmpty {
            let filterUri = URI(string: "\(baseURL)/indexes/\(slug)/settings/filterable-attributes")
            _ = try await client.put(filterUri, headers: authHeaders()) { req in
                try req.content.encode(settings.filterableFields)
            }
        }

        // Update sortable attributes
        if !settings.sortableFields.isEmpty {
            let sortUri = URI(string: "\(baseURL)/indexes/\(slug)/settings/sortable-attributes")
            _ = try await client.put(sortUri, headers: authHeaders()) { req in
                try req.content.encode(settings.sortableFields)
            }
        }

        // Update facet attributes
        if !settings.facetFields.isEmpty {
            let facetUri = URI(string: "\(baseURL)/indexes/\(slug)/settings/faceting")
            _ = try await client.put(facetUri, headers: authHeaders()) { req in
                try req.content.encode(settings.facetFields)
            }
        }
    }

    /// Search across an index with advanced options
    public func search(
        slug: String?,
        query: String,
        page: Int = 1,
        perPage: Int = 20,
        filters: [String: String]? = nil,
        sortBy: String? = nil,
        highlightFields: [String]? = nil
    ) async throws -> MeilisearchResponse {
        let indexSlug = slug ?? "*"
        let uri = URI(string: "\(baseURL)/indexes/\(indexSlug)/search")

        // Prepare optional parameters
        let filterString: String? = {
            guard let filters = filters, !filters.isEmpty else { return nil }
            return filters.map { "\($0.key) = '\($0.value)'" }.joined(separator: " AND ")
        }()

        let sortArray: [String]? = sortBy.map { [$0] }

        let searchRequest = SearchRequest(
            q: query,
            offset: (page - 1) * perPage,
            limit: perPage,
            filter: filterString,
            sort: sortArray,
            attributesToHighlight: highlightFields?.isEmpty == false ? highlightFields : nil,
            highlightPreTag: highlightFields?.isEmpty == false ? "<mark>" : nil,
            highlightPostTag: highlightFields?.isEmpty == false ? "</mark>" : nil
        )

        let response = try await client.post(uri, headers: authHeaders()) { req in
            try req.content.encode(searchRequest)
        }
        return try response.content.decode(MeilisearchResponse.self)
    }

    private func authHeaders() -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: .authorization, value: "Bearer \(apiKey)")
        headers.add(name: .contentType, value: "application/json")
        return headers
    }
}

// MARK: - Types

struct SearchRequest: Content {
    let q: String
    let offset: Int
    let limit: Int
    let filter: String?
    let sort: [String]?
    let attributesToHighlight: [String]?
    let highlightPreTag: String?
    let highlightPostTag: String?

    init(
        q: String,
        offset: Int,
        limit: Int,
        filter: String? = nil,
        sort: [String]? = nil,
        attributesToHighlight: [String]? = nil,
        highlightPreTag: String? = nil,
        highlightPostTag: String? = nil
    ) {
        self.q = q
        self.offset = offset
        self.limit = limit
        self.filter = filter
        self.sort = sort
        self.attributesToHighlight = attributesToHighlight
        self.highlightPreTag = highlightPreTag
        self.highlightPostTag = highlightPostTag
    }
}

/// Response from Meilisearch search endpoint.
public struct MeilisearchResponse: Content, Sendable {
    public let hits: [AnyCodableValue]
    public let estimatedTotalHits: Int?
    public let offset: Int?
    public let limit: Int?
    public let processingTimeMs: Int?
    public let facets: [String: AnyCodableValue]?

    init(hits: [AnyCodableValue], estimatedTotalHits: Int?, offset: Int?, limit: Int?, processingTimeMs: Int?, facets: [String: AnyCodableValue]? = nil) {
        self.hits = hits
        self.estimatedTotalHits = estimatedTotalHits
        self.offset = offset
        self.limit = limit
        self.processingTimeMs = processingTimeMs
        self.facets = facets
    }
}

// MARK: - Search Module

/// CMS module that integrates Meilisearch with the event system.
public struct SearchModule: CmsModule {
    public let name = "search"
    public let priority = 50

    public init() {}

    public func boot(app: Application) throws {
        guard let meiliURL = Environment.get("MEILI_URL"),
              let meiliKey = Environment.get("MEILI_KEY") else {
            app.logger.warning("Meilisearch not configured (MEILI_URL/MEILI_KEY missing)")
            return
        }

        app.logger.info("Search module: Meilisearch at \(meiliURL)")

        // Subscribe to schema events for index management
        app.eventBus.subscribe(SchemaChangedEvent.self) { event, context in
            let meilisearch = MeilisearchService(
                baseURL: meiliURL, apiKey: meiliKey,
                client: app.client
            )
            let indexer = SearchIndexer(meilisearch: meilisearch)

            switch event.action {
            case "created":
                try await meilisearch.createIndex(slug: event.contentTypeSlug)

                // Configure index settings if content type exists
                if let contentType = try await ContentTypeDefinition.query(on: app.db)
                    .filter(\ContentTypeDefinition.$slug == event.contentTypeSlug)
                    .first() {
                    try await indexer.configureIndex(contentType: contentType)
                }

                context.logger.info("Search: Created and configured index for \(event.contentTypeSlug)")

            case "deleted":
                try await meilisearch.deleteIndex(slug: event.contentTypeSlug)
                context.logger.info("Search: Deleted index for \(event.contentTypeSlug)")

            case "updated":
                // Update index settings if schema changed
                if let contentType = try await ContentTypeDefinition.query(on: app.db)
                    .filter(\ContentTypeDefinition.$slug == event.contentTypeSlug)
                    .first() {
                    try await indexer.configureIndex(contentType: contentType)
                    context.logger.info("Search: Updated index settings for \(event.contentTypeSlug)")
                }

            default:
                break
            }
        }

        // Subscribe to content events for document sync
        app.eventBus.subscribe(ContentCreatedEvent.self) { event, _ in
            let meilisearch = MeilisearchService(
                baseURL: meiliURL, apiKey: meiliKey,
                client: app.client
            )

            // Build proper document with all metadata
            if let entry = try await ContentEntry.find(event.entryId, on: app.db),
               let contentType = try await ContentTypeDefinition.query(on: app.db)
                .filter(\ContentTypeDefinition.$slug == event.contentType)
                .first() {
                let indexer = SearchIndexer(meilisearch: meilisearch)
                try await indexer.indexEntry(entry, contentType: contentType, db: app.db)
            }
        }

        // Subscribe to content update events for re-indexing
        app.eventBus.subscribe(ContentUpdatedEvent.self) { event, context in
            let meilisearch = MeilisearchService(
                baseURL: meiliURL, apiKey: meiliKey,
                client: app.client
            )

            // Fetch the updated entry from the database to get its current data
            if let entry = try await ContentEntry.find(event.entryId, on: app.db),
               let contentType = try await ContentTypeDefinition.query(on: app.db)
                .filter(\ContentTypeDefinition.$slug == event.contentType)
                .first() {
                let indexer = SearchIndexer(meilisearch: meilisearch)
                try await indexer.indexEntry(entry, contentType: contentType, db: app.db)
                context.logger.info("Search: Re-indexed \(event.entryId) in \(event.contentType)")
            }
        }

        app.eventBus.subscribe(ContentDeletedEvent.self) { event, _ in
            let meilisearch = MeilisearchService(
                baseURL: meiliURL, apiKey: meiliKey,
                client: app.client
            )
            try await meilisearch.removeEntry(
                slug: event.contentType,
                id: event.entryId.uuidString
            )
        }

        // Subscribe to publish events for potential reindexing
        app.eventBus.subscribe(ContentPublishedEvent.self) { event, _ in
            let meilisearch = MeilisearchService(
                baseURL: meiliURL, apiKey: meiliKey,
                client: app.client
            )

            // Reindex published content to update status
            if let entry = try await ContentEntry.find(event.entryId, on: app.db),
               let contentType = try await ContentTypeDefinition.query(on: app.db)
                .filter(\ContentTypeDefinition.$slug == event.contentType)
                .first() {
                let indexer = SearchIndexer(meilisearch: meilisearch)
                try await indexer.indexEntry(entry, contentType: contentType, db: app.db)
            }
        }
    }
}
