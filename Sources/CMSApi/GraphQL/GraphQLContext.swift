import Vapor
import Fluent
import CMSObjects
import CMSSchema
import CMSAuth
import Graphiti

// MARK: - GraphQL Context

/// Context passed to all GraphQL resolvers.
/// Provides access to the Vapor Request, database, and authenticated user.
public struct GraphQLContext: Sendable {
    /// The Vapor request
    public let request: Request

    /// The authenticated user (if any)
    public let user: AuthenticatedUser?

    /// Content type definitions cache
    public let contentTypeDefinitions: [String: ContentTypeDefinition]

    /// Initialize with Vapor request and optional user
    public init(
        request: Request,
        user: AuthenticatedUser? = nil,
        contentTypeDefinitions: [String: ContentTypeDefinition] = [:]
    ) {
        self.request = request
        self.user = user
        self.contentTypeDefinitions = contentTypeDefinitions
    }

    /// Check if user has a role
    public func hasRole(_ role: String) -> Bool {
        guard let user = user else { return false }
        return user.roles.contains(role)
    }

    /// Require authentication, throws if not authenticated
    public func requireAuth() throws -> AuthenticatedUser {
        guard let user = user else {
            throw Abort(.unauthorized, reason: "Authentication required")
        }
        return user
    }

    /// Require a specific role, throws if not authorized
    public func requireRole(_ role: String) throws {
        guard hasRole(role) else {
            throw Abort(.forbidden, reason: "Role required: \(role)")
        }
    }

    /// Database accessor
    public var db: Database {
        request.db
    }

    /// Logger accessor
    public var logger: Logger {
        request.logger
    }
}
