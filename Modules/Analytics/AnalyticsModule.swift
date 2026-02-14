import Vapor
import Fluent
import CMSCore
import CMSObjects

/// Analytics plugin: tracks API hits per content type per day.
public struct AnalyticsModule: CmsModule {
    public let name = "analytics"
    public let version = "1.0.0"
    public let priority = 90

    public init() {}

    public func boot(app: Application) throws {
        let admin = app.grouped("admin", "plugins", "analytics")
        admin.get(use: analyticsPage)

        // API endpoint for chart data
        app.get("api", "v1", "plugins", "analytics", "stats", use: stats)

        app.logger.info("Analytics module: routes registered")
    }

    @Sendable
    func analyticsPage(req: Request) async throws -> View {
        struct Context: Encodable {
            let title: String
            let activePage: String
        }
        return try await req.view.render("admin/plugins/analytics", Context(
            title: "Analytics",
            activePage: "analytics"
        ))
    }

    @Sendable
    func stats(req: Request) async throws -> [ContentTypeStat] {
        let types = try await ContentTypeDefinition.query(on: req.db).all()
        var stats: [ContentTypeStat] = []
        for typeDef in types {
            let count = try await ContentEntry.query(on: req.db)
                .filter(\.$contentType == typeDef.slug)
                .filter(\.$deletedAt == nil)
                .count()
            stats.append(ContentTypeStat(slug: typeDef.slug, name: typeDef.displayName, count: count))
        }
        return stats
    }
}

struct ContentTypeStat: Content {
    let slug: String
    let name: String
    let count: Int
}
