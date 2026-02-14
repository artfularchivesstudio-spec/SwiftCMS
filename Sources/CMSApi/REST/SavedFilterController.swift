import Vapor
import Fluent
import CMSObjects
import CMSAuth
import CMSSchema

// MARK: - SavedFilterController

public struct SavedFilterController: RouteCollection, Sendable {
    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        // Register saved filter routes within admin
        try routes.grouped("saved-filters").register(collection: AdminSavedFilterController())

        // Register API routes
        try routes.register(collection: SavedFilterAPIController())
    }
}

// MARK: - Admin SavedFilter Controller

struct AdminSavedFilterController: RouteCollection, Sendable {
    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let protected = routes.grouped(SessionAuthRedirectMiddleware())
        protected.get(use: list)
        protected.post(use: create)
        protected.delete(":filterId", use: delete)
    }

    @Sendable
    func list(req: Request) async throws -> View {
        let contentType = try req.query.get(String.self, at: "contentType")
        let user = try req.auth.require(User.self)
        try await user.$role.load(on: req.db)

        // Get filters accessible to the user (own filters or public filters)
        let filters = try await SavedFilter.query(on: req.db)
            .group(.or) { or in
                or.filter(\.$user.$id == user.id)
                or.filter(\.$isPublic == true)
            }
            .filter(\.$contentType == contentType)
            .sort(\.$name)
            .all()

        struct Context: Encodable {
            let filters: [SavedFilter]
        }

        return try await req.view.render("admin/partials/saved-filters-list", Context(
            filters: filters
        ))
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        let user = try req.auth.require(User.self)
        let dto = try req.content.decode(CreateSavedFilterDTO.self)

        let savedFilter = SavedFilter(
            userID: user.id,
            name: dto.name,
            contentType: dto.contentType,
            filterJSON: dto.filterJSON,
            sortJSON: dto.sortJSON,
            isPublic: dto.isPublic
        )

        try await savedFilter.save(on: req.db)

        return req.redirect(to: "/admin/content/\(dto.contentType)")
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let filterId = req.parameters.get("filterId", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        guard let filter = try await SavedFilter.find(filterId, on: req.db) else {
            throw Abort(.notFound)
        }

        // Ensure user owns the filter or has admin rights
        let user = try req.auth.require(User.self)
        if filter.$user.id != user.id {
            throw Abort(.forbidden)
        }

        try await filter.delete(on: req.db)

        return .ok
    }
}

// MARK: - SavedFilter API Controller

struct SavedFilterAPIController: RouteCollection, Sendable {
    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        routes.group("api", "v1") { api in
            let protected = api.grouped(ApiKeyMiddleware())
            protected.get("saved-filters", use: api_list)
            protected.post("saved-filters", use: api_create)
            protected.delete("saved-filters", ":filterId", use: api_delete)
        }
    }

    @Sendable
    func api_list(req: Request) async throws -> [SavedFilter] {
        let user = try req.auth.require(User.self)
        let contentType = try req.query.get(String.self, at: "contentType")

        return try await SavedFilter.query(on: req.db)
            .group(.or) { or in
                or.filter(\.$user.$id == user.id)
                or.filter(\.$isPublic == true)
            }
            .filter(\.$contentType == contentType)
            .sort(\.$name)
            .all()
    }

    @Sendable
    func api_create(req: Request) async throws -> SavedFilter {
        let user = try req.auth.require(User.self)
        let dto = try req.content.decode(CreateSavedFilterDTO.self)

        let savedFilter = SavedFilter(
            userID: user.id,
            name: dto.name,
            contentType: dto.contentType,
            filterJSON: dto.filterJSON,
            sortJSON: dto.sortJSON,
            isPublic: dto.isPublic
        )

        try await savedFilter.save(on: req.db)

        return savedFilter
    }

    @Sendable
    func api_delete(req: Request) async throws -> HTTPStatus {
        guard let filterId = req.parameters.get("filterId", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        guard let filter = try await SavedFilter.find(filterId, on: req.db) else {
            throw Abort(.notFound)
        }

        // Ensure user owns the filter
        let currentUser = try req.auth.require(User.self)
        if filter.$user.id != currentUser.id {
            throw Abort(.forbidden)
        }

        try await filter.delete(on: req.db)

        return .ok
    }
}
