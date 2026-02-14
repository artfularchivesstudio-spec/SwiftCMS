import Vapor
import Fluent
import CMSObjects
import CMSSchema
import Graphiti

// MARK: - GraphQL Types

/// Pagination meta information for GraphQL connections
public struct GraphQLPageInfo: Codable, Sendable {
    public let page: Int
    public let perPage: Int
    public let total: Int
    public let totalPages: Int
    public let hasNextPage: Bool
    public let hasPreviousPage: Bool

    public init(
        page: Int,
        perPage: Int,
        total: Int
    ) {
        self.page = page
        self.perPage = perPage
        self.total = total
        self.totalPages = perPage > 0 ? (total + perPage - 1) / perPage : 0
        self.hasNextPage = page < totalPages
        self.hasPreviousPage = page > 1
    }
}

/// Generic connection type for paginated GraphQL results
public struct GraphQLConnection<T: Codable & Sendable>: Codable, Sendable {
    public let data: [T]
    public let pageInfo: GraphQLPageInfo

    public init(data: [T], pageInfo: GraphQLPageInfo) {
        self.data = data
        self.pageInfo = pageInfo
    }
}

/// GraphQL representation of a content entry
public struct GraphQLContentEntry: Codable, Sendable {
    public let id: UUID
    public let contentType: String
    public let status: String
    public let data: AnyCodableValue
    public let createdAt: Date?
    public let updatedAt: Date?
    public let publishedAt: Date?
    public let createdBy: String?

    public init(from entry: ContentEntry) {
        self.id = entry.id ?? UUID()
        self.contentType = entry.contentType
        self.status = entry.status
        self.data = entry.data
        self.createdAt = entry.createdAt
        self.updatedAt = entry.updatedAt
        self.publishedAt = entry.publishedAt
        self.createdBy = entry.createdBy
    }
}

/// GraphQL representation of a content type definition
public struct GraphQLContentType: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let slug: String
    public let displayName: String
    public let description: String?
    public let kind: String
    public let jsonSchema: AnyCodableValue
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(from typeDef: ContentTypeDefinition) {
        self.id = typeDef.id ?? UUID()
        self.name = typeDef.name
        self.slug = typeDef.slug
        self.displayName = typeDef.displayName
        self.description = typeDef.description
        self.kind = typeDef.kind
        self.jsonSchema = typeDef.jsonSchema
        self.createdAt = typeDef.createdAt
        self.updatedAt = typeDef.updatedAt
    }
}

/// GraphQL representation of a user
public struct GraphQLUser: Codable, Sendable {
    public let id: UUID
    public let email: String
    public let displayName: String?
    public let authProvider: String
    public let roles: [String]

    public init(from user: User) {
        self.id = user.id ?? UUID()
        self.email = user.email
        self.displayName = user.displayName
        self.authProvider = user.authProvider
        self.roles = [] // Roles would need to be loaded separately
    }
}

// MARK: - Input Types

/// Input for creating a content entry
public struct CreateContentEntryInput: Codable, Sendable {
    public let contentType: String
    public let data: [String: AnyCodableValue]
    public let status: String?
    public let publishAt: Date?

    public init(
        contentType: String,
        data: [String: AnyCodableValue],
        status: String? = nil,
        publishAt: Date? = nil
    ) {
        self.contentType = contentType
        self.data = data
        self.status = status
        self.publishAt = publishAt
    }
}

/// Input for updating a content entry
public struct UpdateContentEntryInput: Codable, Sendable {
    public let id: UUID
    public let data: [String: AnyCodableValue]?
    public let status: String?
    public let publishAt: Date?
    public let unpublishAt: Date?

    public init(
        id: UUID,
        data: [String: AnyCodableValue]? = nil,
        status: String? = nil,
        publishAt: Date? = nil,
        unpublishAt: Date? = nil
    ) {
        self.id = id
        self.data = data
        self.status = status
        self.publishAt = publishAt
        self.unpublishAt = unpublishAt
    }
}

/// Input for pagination
public struct PaginationInput: Codable, Sendable {
    public let page: Int?
    public let perPage: Int?
    public let sort: String?
    public let filter: [String: AnyCodableValue]?

    public init(
        page: Int? = nil,
        perPage: Int? = nil,
        sort: String? = nil,
        filter: [String: AnyCodableValue]? = nil
    ) {
        self.page = page
        self.perPage = perPage
        self.sort = sort
        self.filter = filter
    }

    public var resolvedPage: Int { page ?? 1 }
    public var resolvedPerPage: Int { min(perPage ?? 20, 100) }
}

/// Input for creating a content type definition
public struct CreateContentTypeInput: Codable, Sendable {
    public let name: String
    public let slug: String
    public let description: String?
    public let jsonSchema: [String: AnyCodableValue]

    public init(
        name: String,
        slug: String,
        description: String? = nil,
        jsonSchema: [String: AnyCodableValue]
    ) {
        self.name = name
        self.slug = slug
        self.description = description
        self.jsonSchema = jsonSchema
    }
}
