import Vapor
import Fluent
import CMSObjects
import CMSSchema

/// Controller for version-related endpoints.
public struct VersionController: RouteCollection, Sendable {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let api = routes.grouped("api", "v1", ":contentType")
        api.get(":id", "versions", ":from", ":to", "diff", use: diff)
    }

    /// GET /api/v1/:contentType/:id/versions/:from/:to/diff
    /// Compute and return diff between two versions of a content entry.
    @Sendable
    func diff(req: Request) async throws -> AnyCodableValue {
        guard let entryId = req.parameters.get("id", as: UUID.self) else {
            throw ApiError.badRequest("Invalid entry ID")
        }

        guard let fromVersion = req.parameters.get("from", as: Int.self) else {
            throw ApiError.badRequest("Invalid from version number")
        }

        guard let toVersion = req.parameters.get("to", as: Int.self) else {
            throw ApiError.badRequest("Invalid to version number")
        }

        return try await VersionService.diff(
            entryId: entryId,
            fromVersion: fromVersion,
            toVersion: toVersion,
            on: req.db
        )
    }
}
