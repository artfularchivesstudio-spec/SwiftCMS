import Vapor
import Fluent
import Leaf
import CMSCore
import CMSSchema
import CMSObjects
import CMSAuth
import CMSEvents

// MARK: - Admin Controller

/// Main admin panel controller.
/// Routes: /admin
public struct AdminController: RouteCollection {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let admin = routes.grouped("admin")

        // Public routes
        admin.get("login", use: loginPage)
        admin.post("login", use: loginAction)
        admin.get("logout", use: logout)

        // Protected routes
        let protected = admin.grouped(SessionAuthRedirectMiddleware())
        protected.get(use: dashboard)
        protected.get("content-types", use: contentTypes)
        protected.get("content-types", "new", use: contentTypeBuilder)
        protected.get("content", ":contentType", use: contentList)
        protected.get("content", ":contentType", "new", use: contentEdit)
        protected.get("content", ":contentType", ":entryId", use: contentEdit)
        protected.get("media", use: mediaLibrary)
        protected.get("users", use: userList)
        protected.get("webhooks", use: webhookList)
        protected.get("settings", use: settings)
        protected.get("system", "dlq", use: deadLetterQueue)
    }

    // MARK: - Dashboard

    @Sendable
    func dashboard(req: Request) async throws -> View {
        let typeCount = try await ContentTypeDefinition.query(on: req.db).count()
        let entryCount = try await ContentEntry.query(on: req.db)
            .filter(\.$deletedAt == nil).count()
        let recentEntries = try await ContentEntry.query(on: req.db)
            .filter(\.$deletedAt == nil)
            .sort(\.$createdAt, .descending)
            .limit(10)
            .all()

        struct DashboardContext: Encodable {
            let title: String
            let typeCount: Int
            let entryCount: Int
            let recentEntries: [ContentEntry]
            let activePage: String
        }

        return try await req.view.render("admin/dashboard", DashboardContext(
            title: "Dashboard",
            typeCount: typeCount,
            entryCount: entryCount,
            recentEntries: recentEntries,
            activePage: "dashboard"
        ))
    }

    // MARK: - Content Types

    @Sendable
    func contentTypes(req: Request) async throws -> View {
        let types = try await ContentTypeDefinition.query(on: req.db)
            .sort(\.$name)
            .all()

        struct Context: Encodable {
            let title: String
            let contentTypes: [ContentTypeDefinition]
            let activePage: String
        }

        return try await req.view.render("admin/content/types", Context(
            title: "Content Types",
            contentTypes: types,
            activePage: "content-types"
        ))
    }

    @Sendable
    func contentTypeBuilder(req: Request) async throws -> View {
        struct Context: Encodable {
            let title: String
            let fieldTypes: [String]
            let activePage: String
        }

        return try await req.view.render("admin/content/builder", Context(
            title: "New Content Type",
            fieldTypes: FieldTypeRegistry.allFieldTypes,
            activePage: "content-types"
        ))
    }

    // MARK: - Content List & Edit

    @Sendable
    func contentList(req: Request) async throws -> View {
        let contentType = try req.parameters.require("contentType")
        let page = req.query[Int.self, at: "page"] ?? 1

        guard let typeDef = try await ContentTypeDefinition.query(on: req.db)
            .filter(\.$slug == contentType)
            .first()
        else {
            throw Abort(.notFound)
        }

        let entries = try await ContentEntry.query(on: req.db)
            .filter(\.$contentType == contentType)
            .filter(\.$deletedAt == nil)
            .sort(\.$createdAt, .descending)
            .limit(25)
            .offset((page - 1) * 25)
            .all()

        let total = try await ContentEntry.query(on: req.db)
            .filter(\.$contentType == contentType)
            .filter(\.$deletedAt == nil)
            .count()

        struct Context: Encodable {
            let title: String
            let contentType: ContentTypeDefinition
            let entries: [ContentEntry]
            let page: Int
            let totalPages: Int
            let activePage: String
        }

        return try await req.view.render("admin/content/list", Context(
            title: typeDef.displayName,
            contentType: typeDef,
            entries: entries,
            page: page,
            totalPages: max(1, Int(ceil(Double(total) / 25.0))),
            activePage: "content"
        ))
    }

    @Sendable
    func contentEdit(req: Request) async throws -> View {
        let contentType = try req.parameters.require("contentType")
        let entryId = req.parameters.get("entryId", as: UUID.self)

        guard let typeDef = try await ContentTypeDefinition.query(on: req.db)
            .filter(\.$slug == contentType)
            .first()
        else {
            throw Abort(.notFound)
        }

        let entry: ContentEntry? = if let id = entryId {
            try await ContentEntry.find(id, on: req.db)
        } else {
            nil
        }

        struct Context: Encodable {
            let title: String
            let contentType: ContentTypeDefinition
            let entry: ContentEntry?
            let activePage: String
        }

        return try await req.view.render("admin/content/edit", Context(
            title: entry != nil ? "Edit Entry" : "New Entry",
            contentType: typeDef,
            entry: entry,
            activePage: "content"
        ))
    }

    // MARK: - Media

    @Sendable
    func mediaLibrary(req: Request) async throws -> View {
        let files = try await MediaFile.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .limit(50)
            .all()

        struct Context: Encodable {
            let title: String
            let files: [MediaFile]
            let activePage: String
        }

        return try await req.view.render("admin/media/library", Context(
            title: "Media Library",
            files: files,
            activePage: "media"
        ))
    }

    // MARK: - Users

    @Sendable
    func userList(req: Request) async throws -> View {
        let users = try await User.query(on: req.db)
            .with(\.$role)
            .sort(\.$email)
            .all()

        struct Context: Encodable {
            let title: String
            let users: [User]
            let activePage: String
        }

        return try await req.view.render("admin/users/list", Context(
            title: "Users",
            users: users,
            activePage: "users"
        ))
    }

    // MARK: - Webhooks

    @Sendable
    func webhookList(req: Request) async throws -> View {
        let webhooks = try await Webhook.query(on: req.db)
            .sort(\.$name)
            .all()

        struct Context: Encodable {
            let title: String
            let webhooks: [Webhook]
            let activePage: String
        }

        return try await req.view.render("admin/webhooks/list", Context(
            title: "Webhooks",
            webhooks: webhooks,
            activePage: "webhooks"
        ))
    }

    // MARK: - Settings

    @Sendable
    func settings(req: Request) async throws -> View {
        struct Context: Encodable {
            let title: String
            let activePage: String
        }
        return try await req.view.render("admin/settings/index", Context(
            title: "Settings",
            activePage: "settings"
        ))
    }

    // MARK: - Dead Letter Queue

    @Sendable
    func deadLetterQueue(req: Request) async throws -> View {
        let entries = try await DeadLetterEntry.query(on: req.db)
            .sort(\.$lastFailedAt, .descending)
            .limit(50)
            .all()

        struct Context: Encodable {
            let title: String
            let entries: [DeadLetterEntry]
            let activePage: String
        }

        return try await req.view.render("admin/system/dlq", Context(
            title: "Dead Letter Queue",
            entries: entries,
            activePage: "system"
        ))
    }

    // MARK: - Auth

    @Sendable
    func loginPage(req: Request) async throws -> View {
        struct Context: Encodable {
            let title: String
            let error: String?
        }
        return try await req.view.render("admin/login", Context(
            title: "Login", error: nil
        ))
    }

    @Sendable
    func loginAction(req: Request) async throws -> Response {
        let dto = try req.content.decode(LoginDTO.self)

        guard let user = try await User.query(on: req.db)
            .filter(\.$email == dto.email)
            .first(),
              let passwordHash = user.passwordHash,
              try Bcrypt.verify(dto.password, created: passwordHash)
        else {
            return req.redirect(to: "/admin/login?error=invalid")
        }

        req.auth.login(user)
        req.session.authenticate(user)
        return req.redirect(to: "/admin")
    }

    @Sendable
    func logout(req: Request) async throws -> Response {
        req.auth.logout(User.self)
        req.session.unauthenticate(User.self)
        return req.redirect(to: "/admin/login")
    }
}
