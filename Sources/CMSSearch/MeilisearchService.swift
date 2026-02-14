import Vapor
import Fluent
import CMSCore
import CMSObjects
import CMSSchema
import CMSEvents

/// Service wrapping Meilisearch operations.
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

    /// Search across an index.
    public func search(
        slug: String?,
        query: String,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> MeilisearchResponse {
        let indexSlug = slug ?? "*"
        let uri = URI(string: "\(baseURL)/indexes/\(indexSlug)/search")
        let response = try await client.post(uri, headers: authHeaders()) { req in
            try req.content.encode(SearchRequest(
                q: query,
                offset: (page - 1) * perPage,
                limit: perPage
            ))
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
}

/// Response from Meilisearch search endpoint.
public struct MeilisearchResponse: Content, Sendable {
    public let hits: [AnyCodableValue]
    public let estimatedTotalHits: Int?
    public let offset: Int?
    public let limit: Int?
    public let processingTimeMs: Int?
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
            let service = MeilisearchService(
                baseURL: meiliURL, apiKey: meiliKey,
                client: app.client
            )
            switch event.action {
            case "created":
                try await service.createIndex(slug: event.contentTypeSlug)
                context.logger.info("Search: Created index for \(event.contentTypeSlug)")
            case "deleted":
                try await service.deleteIndex(slug: event.contentTypeSlug)
                context.logger.info("Search: Deleted index for \(event.contentTypeSlug)")
            default:
                break
            }
        }

        // Subscribe to content events for document sync
        app.eventBus.subscribe(ContentCreatedEvent.self) { event, _ in
            let service = MeilisearchService(
                baseURL: meiliURL, apiKey: meiliKey,
                client: app.client
            )
            try await service.indexEntry(
                slug: event.contentType,
                id: event.entryId.uuidString,
                data: event.data.mapValues { .string($0) }
            )
        }

        // Subscribe to content update events for re-indexing
        app.eventBus.subscribe(ContentUpdatedEvent.self) { event, context in
            let service = MeilisearchService(
                baseURL: meiliURL, apiKey: meiliKey,
                client: app.client
            )
            // Fetch the updated entry from the database to get its current data
            if let entry = try await ContentEntry.find(event.entryId, on: app.db) {
                let dataDict = entry.data.dictionaryValue ?? [:]
                try await service.indexEntry(
                    slug: event.contentType,
                    id: event.entryId.uuidString,
                    data: dataDict
                )
                context.logger.info("Search: Re-indexed \(event.entryId) in \(event.contentType)")
            }
        }

        app.eventBus.subscribe(ContentDeletedEvent.self) { event, _ in
            let service = MeilisearchService(
                baseURL: meiliURL, apiKey: meiliKey,
                client: app.client
            )
            try await service.removeEntry(
                slug: event.contentType,
                id: event.entryId.uuidString
            )
        }
    }
}
