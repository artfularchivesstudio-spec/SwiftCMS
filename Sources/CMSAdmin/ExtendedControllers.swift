import Vapor
import Fluent
import Leaf
import CMSSchema
import CMSObjects
import CMSAuth

// MARK: - Roles Admin Controller

public struct RolesController: RouteCollection {
    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let roles = routes.grouped("admin", "roles")
            .grouped(SessionAuthRedirectMiddleware())
        roles.get(use: list)
        roles.post(use: create)
        roles.post(":roleId", "permissions", use: updatePermissions)
    }

    @Sendable
    func list(req: Request) async throws -> View {
        let roles = try await Role.query(on: req.db)
            .with(\.$permissions)
            .sort(\.$name)
            .all()
        let types = try await ContentTypeDefinition.query(on: req.db).all()

        struct Context: Encodable {
            let title: String
            let roles: [Role]
            let contentTypes: [ContentTypeDefinition]
            let activePage: String
        }
        return try await req.view.render("admin/roles/list", Context(
            title: "Roles & Permissions",
            roles: roles,
            contentTypes: types,
            activePage: "roles"
        ))
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        struct CreateRoleForm: Content {
            let name: String
            let slug: String
            let description: String?
        }
        let form = try req.content.decode(CreateRoleForm.self)
        let role = Role(name: form.name, slug: form.slug, description: form.description)
        try await role.save(on: req.db)
        return req.redirect(to: "/admin/roles")
    }

    @Sendable
    func updatePermissions(req: Request) async throws -> Response {
        guard let roleId = req.parameters.get("roleId", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        struct PermissionForm: Content {
            let contentTypeSlug: String
            let actions: [String]
        }
        let form = try req.content.decode(PermissionForm.self)

        // Remove existing permissions for this content type
        try await Permission.query(on: req.db)
            .filter(\.$role.$id == roleId)
            .filter(\.$contentTypeSlug == form.contentTypeSlug)
            .delete()

        // Add new permissions
        for action in form.actions {
            let perm = Permission(roleID: roleId, contentTypeSlug: form.contentTypeSlug, action: action)
            try await perm.save(on: req.db)
        }

        return req.redirect(to: "/admin/roles")
    }
}

// MARK: - Version Admin Controller

public struct VersionAdminController: RouteCollection {
    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let versions = routes.grouped("admin", "content", ":contentType", ":entryId", "versions")
            .grouped(SessionAuthRedirectMiddleware())
        versions.get(use: list)
    }

    @Sendable
    func list(req: Request) async throws -> View {
        let contentType = try req.parameters.require("contentType")
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        let versions = try await ContentVersion.query(on: req.db)
            .filter(\.$entry.$id == entryId)
            .sort(\.$version, .descending)
            .all()

        struct Context: Encodable {
            let title: String
            let contentType: String
            let entryId: String
            let versions: [ContentVersion]
            let activePage: String
        }
        return try await req.view.render("admin/content/versions", Context(
            title: "Version History",
            contentType: contentType,
            entryId: entryId.uuidString,
            versions: versions,
            activePage: "content"
        ))
    }
}

// MARK: - Bulk Operations Controller

public struct BulkOperationsController: RouteCollection {
    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let bulk = routes.grouped("api", "v1", "bulk")
        bulk.post("publish", use: bulkPublish)
        bulk.post("delete", use: bulkDelete)
        bulk.post("archive", use: bulkArchive)
    }

    @Sendable
    func bulkPublish(req: Request) async throws -> HTTPStatus {
        let dto = try req.content.decode(BulkActionDTO.self)
        let ids = dto.ids.compactMap { UUID(uuidString: $0) }

        let entries = try await ContentEntry.query(on: req.db)
            .filter(\.$id ~~ ids)
            .filter(\.$deletedAt == nil)
            .all()

        for entry in entries {
            entry.status = ContentStatus.published.rawValue
            entry.publishedAt = Date()
            try await entry.save(on: req.db)
        }

        return .ok
    }

    @Sendable
    func bulkDelete(req: Request) async throws -> HTTPStatus {
        let dto = try req.content.decode(BulkActionDTO.self)
        let ids = dto.ids.compactMap { UUID(uuidString: $0) }

        let entries = try await ContentEntry.query(on: req.db)
            .filter(\.$id ~~ ids)
            .filter(\.$deletedAt == nil)
            .all()

        for entry in entries {
            entry.deletedAt = Date()
            try await entry.save(on: req.db)
        }

        return .ok
    }

    @Sendable
    func bulkArchive(req: Request) async throws -> HTTPStatus {
        let dto = try req.content.decode(BulkActionDTO.self)
        let ids = dto.ids.compactMap { UUID(uuidString: $0) }

        let entries = try await ContentEntry.query(on: req.db)
            .filter(\.$id ~~ ids)
            .filter(\.$deletedAt == nil)
            .all()

        for entry in entries {
            entry.status = ContentStatus.archived.rawValue
            try await entry.save(on: req.db)
        }

        return .ok
    }
}

struct BulkActionDTO: Content {
    let ids: [String]
}

// MARK: - Content Type Import/Export Controller

public struct ContentTypeImportExportController: RouteCollection {
    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let types = routes.grouped("api", "v1", "content-types")
        types.get(":slug", "export", use: exportType)
        types.post("import", use: importType)
    }

    /// Export a content type definition as JSON.
    @Sendable
    func exportType(req: Request) async throws -> Response {
        let slug = try req.parameters.require("slug")
        guard let typeDef = try await ContentTypeDefinition.query(on: req.db)
            .filter(\.$slug == slug)
            .first()
        else {
            throw ApiError.notFound("Content type '\(slug)' not found")
        }

        let exportData = ContentTypeExport(
            name: typeDef.name,
            slug: typeDef.slug,
            displayName: typeDef.displayName,
            description: typeDef.description,
            kind: typeDef.kind,
            jsonSchema: typeDef.jsonSchema,
            fieldOrder: typeDef.fieldOrder,
            settings: typeDef.settings
        )

        let res = Response(status: .ok)
        try res.content.encode(exportData)
        res.headers.contentType = .json
        res.headers.add(name: "Content-Disposition", value: "attachment; filename=\"\(slug).json\"")
        return res
    }

    /// Import a content type definition from JSON.
    @Sendable
    func importType(req: Request) async throws -> Response {
        let importData = try req.content.decode(ContentTypeExport.self)

        // Check slug uniqueness
        let existing = try await ContentTypeDefinition.query(on: req.db)
            .filter(\.$slug == importData.slug)
            .first()
        if existing != nil {
            throw ApiError.conflict("Content type '\(importData.slug)' already exists")
        }

        let kind = ContentTypeKind(rawValue: importData.kind) ?? .collection
        let fieldOrder = importData.fieldOrder ?? .array([])

        let definition = ContentTypeDefinition(
            name: importData.name,
            slug: importData.slug,
            displayName: importData.displayName,
            description: importData.description,
            kind: kind,
            jsonSchema: importData.jsonSchema,
            fieldOrder: fieldOrder
        )
        if let settings = importData.settings {
            definition.settings = settings
        }

        try await definition.save(on: req.db)

        let res = Response(status: .created)
        try res.content.encode(definition.toResponseDTO())
        return res
    }
}

struct ContentTypeExport: Content {
    let name: String
    let slug: String
    let displayName: String
    let description: String?
    let kind: String
    let jsonSchema: AnyCodableValue
    let fieldOrder: AnyCodableValue?
    let settings: AnyCodableValue?
}

// MARK: - Locale Settings Controller

public struct LocaleSettingsController: RouteCollection {
    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let locales = routes.grouped("admin", "settings", "locales")
            .grouped(SessionAuthRedirectMiddleware())
        locales.get(use: localesPage)
    }

    @Sendable
    func localesPage(req: Request) async throws -> View {
        struct Context: Encodable {
            let title: String
            let activePage: String
        }
        return try await req.view.render("admin/settings/locales", Context(
            title: "Locale Management",
            activePage: "settings"
        ))
    }
}
