import Vapor
import Fluent
import CMSCore
import CMSSchema
import CMSObjects
import CMSEvents

/// SEO plugin: sitemap, robots.txt, meta tag management.
public struct SEOModule: CmsModule {
    public let name = "seo"
    public let priority = 100

    public init() {}

    public func boot(app: Application) throws {
        // Routes
        app.get("sitemap.xml", use: sitemap)
        app.get("robots.txt", use: robots)

        // Admin page
        let admin = app.grouped("admin", "plugins", "seo")
        admin.get(use: seoAdmin)

        // Hook: auto-generate meta description on save
        app.eventBus.subscribe(ContentCreatedEvent.self) { event, context in
            context.logger.info("SEO: Processing new entry \(event.entryId)")
        }

        app.logger.info("SEO module: routes registered (sitemap.xml, robots.txt)")
    }

    @Sendable
    func sitemap(req: Request) async throws -> Response {
        let entries = try await ContentEntry.query(on: req.db)
            .filter(\.$status == "published")
            .filter(\.$deletedAt == nil)
            .sort(\.$updatedAt, .descending)
            .all()

        let baseURL = Environment.get("APP_URL") ?? "http://localhost:8080"
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n"

        for entry in entries {
            let lastMod = entry.updatedAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            xml += "  <url>\n"
            xml += "    <loc>\(baseURL)/api/v1/\(entry.contentType)/\(entry.id?.uuidString ?? "")</loc>\n"
            xml += "    <lastmod>\(lastMod)</lastmod>\n"
            xml += "  </url>\n"
        }

        xml += "</urlset>"

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/xml")
        return Response(status: .ok, headers: headers, body: .init(string: xml))
    }

    @Sendable
    func robots(req: Request) async throws -> Response {
        let baseURL = Environment.get("APP_URL") ?? "http://localhost:8080"
        let body = """
        User-agent: *
        Allow: /api/v1/
        Disallow: /admin/
        Disallow: /api/v1/auth/
        Sitemap: \(baseURL)/sitemap.xml
        """
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/plain")
        return Response(status: .ok, headers: headers, body: .init(string: body))
    }

    @Sendable
    func seoAdmin(req: Request) async throws -> View {
        let totalEntries = try await ContentEntry.query(on: req.db)
            .filter(\.$status == "published")
            .filter(\.$deletedAt == nil)
            .count()

        struct Context: Encodable {
            let title: String
            let totalPublished: Int
            let activePage: String
        }
        return try await req.view.render("admin/plugins/seo", Context(
            title: "SEO Dashboard",
            totalPublished: totalEntries,
            activePage: "seo"
        ))
    }
}
