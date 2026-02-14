import Vapor
import Fluent
import Leaf
import CMSObjects
import CMSSchema
import CMSSearch
import CMSAuth

/// 🔍 **Admin Search Controller**
///
/// Provides comprehensive search functionality for the admin panel using Meilisearch.
/// Handles global search, content type-specific search, and search settings management.
///
/// ### Search Capabilities:
/// - 🌍 **Global Search**: Search across all content types simultaneously
/// - 🎯 **Type-specific Search**: Search within specific content types
/// - ⚡ **Autocomplete**: Real-time search suggestions and results
/// - 🔧 **Search Settings**: Configure searchable fields, filters, and sorting
///
/// ### UI Integration:
/// - Returns HTML partials for HTMX integration
/// - Supports command palette / global search UI
/// - Responsive search results with highlighting
/// - Search settings form for content type configuration
///
/// ### Performance Features:
/// - Meilisearch backend for fast full-text search
/// - Configurable pagination and result limits
/// - Asynchronous search operations
/// - Error handling with fallback responses
public struct AdminSearchController: RouteCollection, Sendable {

    public init() {}

    /// 🚀 **Boot**
    ///
    /// Registers search-related routes under `/admin/search`.
    /// Includes global search and content type-specific search settings.
    ///
    /// - Parameter routes: The routes builder to register endpoints on
    public func boot(routes: any RoutesBuilder) throws {
        let admin = routes.grouped("admin")

        // Global search endpoint for HTMX autocomplete
        admin.get("search", use: globalSearch)

        // Search settings UI
        admin.get("search", "settings", ":contentType", use: searchSettings)
        admin.post("search", "settings", ":contentType", use: updateSearchSettings)
    }

    // MARK: - Global Search

    /// 🔍 **Global Search**
    ///
    /// GET /admin/search?q=query
    ///
    /// Performs a global search across all content types using Meilisearch.
    /// Returns HTML partial for HTMX integration with styled search results.
    ///
    /// ### Search Flow:
    /// 1. Validates query length (minimum 2 characters)
    /// 2. Configures Meilisearch connection
    /// 3. Executes search across all content types
    /// 4. Renders HTML results with proper styling
    /// 5. Includes metadata (total hits, processing time)
    ///
    /// ### Response Format:
    /// - HTML div containing search results
    /// - Each result includes title, content type, status, and date
    /// - Links to edit content entry
    /// - Search metadata footer
    ///
    /// - Parameter req: Request containing search query
    /// - Returns: HTML response with search results or empty state
    @Sendable
    func globalSearch(req: Request) async throws -> Response {
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            req.logger.debug("🔍 Empty search query received, showing placeholder")
            return Response(
                status: .ok,
                body: .init(string: """
                <div class="p-4 text-center text-base-content/60">
                    Type to search content...
                </div>
                """)
            )
        }

        // Short-circuit if query is too short
        guard query.count >= 2 else {
            req.logger.debug("🔍 Query too short (< 2 chars), prompting to continue typing")
            return Response(
                status: .ok,
                body: .init(string: """
                <div class="p-4 text-center text-base-content/60">
                    Continue typing...
                </div>
                """)
            )
        }

        // Check Meilisearch configuration
        guard let meiliURL = Environment.get("MEILI_URL"),
              let meiliKey = Environment.get("MEILI_KEY") else {
            req.logger.warning("⚠️ Search not configured: MEILI_URL or MEILI_KEY not set")
            return Response(
                status: .ok,
                body: .init(string: "Search not available")
            )
        }

        req.logger.info("🔍 Performing global search for query: \(query)")

        let meilisearch = MeilisearchService(
            baseURL: meiliURL,
            apiKey: meiliKey,
            client: req.client
        )

        let searchService = SearchService(
            meilisearch: meilisearch,
            eventBus: req.eventBus
        )

        do {
            let results = try await searchService.search(
                contentType: nil,
                query: query,
                page: 1,
                perPage: 10,
                db: req.db
            )

            req.logger.info("✅ Search completed: \(results.hits.count) results in \(results.processingTimeMs)ms")

            return try await renderSearchResults(results, query: query, req: req)
        } catch {
            req.logger.error("❌ Search failed: \(error)")
            return Response(
                status: .ok,
                body: .init(string: """
                <div class=\"p-4 text-center text-error\">
                    Search error occurred
                </div>
                """)
            )
        }
    }

    // MARK: - Search Settings UI

    /// ⚙️ **Search Settings Page**
    ///
    /// GET /admin/search/settings/:contentType
    ///
    /// Displays the search configuration interface for a specific content type.
    /// Shows current settings and available field options.
    ///
    /// ### Configuration Options:
    /// - 🔍 **Searchable Fields**: Fields included in full-text search
    /// - 🎯 **Filterable Fields**: Fields available as filters
    /// - 📊 **Sortable Fields**: Fields available for sorting
    /// - 📈 **Facet Fields**: Fields for faceted navigation
    ///
    /// ### UI Features:
    /// - Multi-select field lists
    /// - Current settings display
    /// - Available field detection
    /// - Real-time settings preview
    ///
    /// - Parameter req: Request containing content type slug
    /// - Returns: Rendered search settings view
    @Sendable
    func searchSettings(req: Request) async throws -> View {
        let contentType = try req.parameters.require("contentType", as: String.self)

        req.logger.info("⚙️ Loading search settings for content type: \(contentType)")

        guard let typeDef = try await ContentTypeDefinition.query(on: req.db)
            .filter(\.$slug == contentType)
            .first() else {
            req.logger.warning("❌ Content type not found: \(contentType)")
            throw Abort(.notFound, reason: "Content type not found")
        }

        guard let meiliURL = Environment.get("MEILI_URL"),
              let meiliKey = Environment.get("MEILI_KEY") else {
            req.logger.warning("⚠️ Meilisearch not configured")
            throw Abort(.internalServerError, reason: "Search service not configured")
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

        let settings = try await searchService.getIndexSettings(slug: contentType, db: req.db)
        let allFields = extractAllFields(from: typeDef.jsonSchema)

        req.logger.debug("📋 Found \(allFields.count) available fields for content type: \(contentType)")

        let viewModel = SearchSettingsPage(
            contentType: typeDef.toResponseDTO(),
            settings: settings ?? IndexSettings(),
            availableFields: allFields
        )

        return try await req.view.render("admin/search/settings", viewModel)
    }

    /// 💾 **Update Search Settings**
    ///
    /// POST /admin/search/settings/:contentType
    ///
    /// Saves search configuration for a content type to Meilisearch.
    /// Updates index settings and returns success confirmation.
    ///
    /// ### Settings Updated:
    /// - 🔍 Searchable fields configuration
    /// - 🎯 Filterable fields configuration
    /// - 📊 Sortable fields configuration
    /// - 📈 Facet fields configuration
    ///
    /// ### Process:
    /// - Validates content type exists
    /// - Parses form data for field selections
    /// - Adds default fields (status, createdAt, updatedAt)
    /// - Updates Meilisearch index settings
    /// - Returns success HTML to replace form
    ///
    /// - Parameter req: Request with content type slug and form data
    /// - Returns: Success HTML response for HTMX
    @Sendable
    func updateSearchSettings(req: Request) async throws -> Response {
        let contentType = try req.parameters.require("contentType", as: String.self)
        let formData = try req.content.decode(SearchSettingsFormData.self)

        req.logger.info("💾 Updating search settings for content type: \(contentType)")

        guard let typeDef = try await ContentTypeDefinition.query(on: req.db)
            .filter(\.$slug == contentType)
            .first() else {
            req.logger.warning("❌ Content type not found: \(contentType)")
            throw Abort(.notFound, reason: "Content type not found")
        }

        guard let meiliURL = Environment.get("MEILI_URL"),
              let meiliKey = Environment.get("MEILI_KEY") else {
            req.logger.warning("⚠️ Meilisearch not configured")
            throw Abort(.internalServerError, reason: "Search service not configured")
        }

        let settings = IndexSettings(
            searchableFields: Array(Set(formData.searchableFields)),
            filterableFields: Array(Set(formData.filterableFields)) + ["status", "createdAt", "updatedAt"],
            sortableFields: Array(Set(formData.sortableFields)) + ["createdAt", "updatedAt"],
            facetFields: Array(Set(formData.facetFields))
        )

        req.logger.debug("📋 Settings updated: \(settings.searchableFields.count) searchable, \(settings.filterableFields.count) filterable fields")

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

        req.logger.info("✅ Search settings saved successfully for content type: \(contentType)")

        return Response(
            status: .ok,
            body: .init(string: """
            <div class=\"alert alert-success\">
                <svg xmlns=\"http://www.w3.org/2000/svg\" class=\"stroke-current shrink-0 h-6 w-6\" fill=\"none\" viewBox=\"0 0 24 24\">
                    <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z\" />
                </svg>
                <span>Search settings updated successfully!</span>
            </div>
            """)
        )
    }

    // MARK: - Rendering

    /// 🎨 **Render Search Results**
    ///
    /// Transforms search results into HTML for admin UI display.
    /// Generates styled results with links, metadata, and proper formatting.
    ///
    /// ### HTML Structure:
    /// - Container div with scrollable area
    /// - Individual result cards with hover effects
    /// - Content type and status badges
    /// - Timestamps and metadata
    /// - Footer with result count and processing time
    ///
    /// ### Empty State:
    /// - Friendly message when no results found
    /// - Search tips and suggestions
    /// - Visual icon for better UX
    ///
    /// - Parameters:
    ///   - results: SearchResponse from Meilisearch
    ///   - query: The original search query
    ///   - req: Current request for context
    /// - Returns: HTML response with formatted search results
    private func renderSearchResults(_ results: SearchResponse, query: String, req: Request) async throws -> Response {
        guard !results.hits.isEmpty else {
            return Response(
                status: .ok,
                body: .init(string: """
                <div class="p-8 text-center text-base-content/60">
                    <svg class="w-16 h-16 mx-auto mb-4 text-base-content/30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 12h6m-6-4h6m2 5.291A7.962 7.962 0 0112 15c-2.34 0-4.467-.881-6.08-2.33"></path>
                    </svg>
                    <p>No results found for "<strong>\(query)</strong>"</p>
                    <p class="text-sm mt-2">Try different keywords or check your spelling</p>
                </div>
                """)
            )
        }

        let items = results.hits.compactMap { hit -> SearchResultItem? in
            guard let dict = hit.dictionaryValue,
                  let id = dict["id"]?.stringValue,
                  let contentType = dict["contentType"]?.stringValue else {
                return nil
            }
            let title = extractTitle(from: dict, contentType: contentType)

            let status = dict["status"]?.stringValue ?? "draft"
            let createdAt = dict["createdAt"]?.stringValue.flatMap { ISO8601DateFormatter().date(from: $0) }

            return SearchResultItem(
                id: id,
                contentType: contentType,
                title: title,
                status: status,
                createdAt: createdAt
            )
        }

        let html = items.map { item in
            """
            <a href="/admin/content/\(item.contentType)/\(item.id)/edit"
               class="block p-4 hover:bg-base-200 transition-colors border-b border-base-200 last:border-b-0">
                <div class="flex items-start justify-between">
                    <div class="flex-1">
                        <h4 class="font-medium text-base-content">\(item.title)</h4>
                        <div class="flex items-center gap-2 mt-1 text-sm text-base-content/60">
                            <span class="badge badge-sm badge-ghost">\(item.contentType)</span>
                            <span class="badge badge-sm \(statusBadgeClass(item.status))">\(item.status)</span>
                            <span>•</span>
                            <time>\(item.createdAt.map { formatDate($0) } ?? "Unknown date")</time>
                        </div>
                    </div>
                    <svg class="w-5 h-5 text-base-content/40 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
                    </svg>
                </div>
            </a>
            """
        }.joined(separator: "")

        return Response(
            status: .ok,
            body: .init(string: """
            <div class="max-h-96 overflow-y-auto">
                \(html)
            </div>
            <div class="p-4 bg-base-100 border-t border-base-200 text-center text-sm text-base-content/60">
                Found \(results.estimatedTotalHits) results in \(results.processingTimeMs)ms
                \(results.estimatedTotalHits > 10 ? "<a href=\"/admin/search/results?q=\(query)\" class=\"link link-primary\">View all results →</a>" : "")
            </div>
            """)
        )
    }

    // MARK: - Helpers

    private func extractTitle(from dict: [String: AnyCodableValue], contentType: String) -> String {
        // Try common title fields
        let titleFields = ["title", "name", "heading", "subject", "headline"]
        for field in titleFields {
            if let title = dict[field]?.stringValue, !title.isEmpty {
                return title
            }
        }

        // Fallback to ID
        return dict["id"]?.stringValue ?? "Untitled \(contentType)"
    }

    private func extractAllFields(from jsonSchema: AnyCodableValue) -> [String] {
        guard let schema = jsonSchema.dictionaryValue,
              let properties = schema["properties"]?.dictionaryValue else {
            return []
        }

        return Array(properties.keys)
    }

    private func statusBadgeClass(_ status: String) -> String {
        switch status {
        case "published":
            return "badge-success"
        case "draft":
            return "badge-ghost"
        case "archived":
            return "badge-warning"
        default:
            return "badge-ghost"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - DTOs

struct SearchResultItem {
    let id: String
    let contentType: String
    let title: String
    let status: String
    let createdAt: Date?
}

struct SearchSettingsPage: Content {
    let contentType: ContentTypeResponseDTO
    let settings: IndexSettings
    let availableFields: [String]
}

struct SearchSettingsFormData: Content {
    let searchableFields: [String]
    let filterableFields: [String]
    let sortableFields: [String]
    let facetFields: [String]
}
