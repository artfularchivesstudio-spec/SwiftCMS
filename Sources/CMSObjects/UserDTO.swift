import Vapor

// MARK: - User DTOs

/// DTO for user responses.
public struct UserResponseDTO: Content, Sendable {
    public let id: UUID
    public let email: String
    public let displayName: String?
    public let roleName: String?
    public let authProvider: String
    public let createdAt: Date?

    public init(
        id: UUID, email: String, displayName: String?,
        roleName: String?, authProvider: String, createdAt: Date?
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.roleName = roleName
        self.authProvider = authProvider
        self.createdAt = createdAt
    }
}

/// DTO for creating a user.
public struct CreateUserDTO: Content, Sendable, Validatable {
    public let email: String
    public let password: String?
    public let displayName: String?
    public let roleId: UUID?
    public let authProvider: String

    public static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
    }

    public init(
        email: String, password: String? = nil, displayName: String? = nil,
        roleId: UUID? = nil, authProvider: String = "local"
    ) {
        self.email = email
        self.password = password
        self.displayName = displayName
        self.roleId = roleId
        self.authProvider = authProvider
    }
}

/// DTO for updating a user.
public struct UpdateUserDTO: Content, Sendable {
    public let displayName: String?
    public let roleId: UUID?
    public let isActive: Bool?

    public init(displayName: String? = nil, roleId: UUID? = nil, isActive: Bool? = nil) {
        self.displayName = displayName
        self.roleId = roleId
        self.isActive = isActive
    }
}

// MARK: - Role DTOs

/// DTO for role responses.
public struct RoleResponseDTO: Content, Sendable {
    public let id: UUID
    public let name: String
    public let slug: String
    public let description: String?
    public let isSystem: Bool
    public let permissions: [PermissionDTO]?

    public init(
        id: UUID, name: String, slug: String, description: String?,
        isSystem: Bool, permissions: [PermissionDTO]? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.isSystem = isSystem
        self.permissions = permissions
    }
}

/// DTO for creating a role.
public struct CreateRoleDTO: Content, Sendable, Validatable {
    public let name: String
    public let slug: String
    public let description: String?
    public let permissions: [PermissionDTO]?

    public static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("slug", as: String.self, is: !.empty)
    }

    public init(name: String, slug: String, description: String? = nil, permissions: [PermissionDTO]? = nil) {
        self.name = name
        self.slug = slug
        self.description = description
        self.permissions = permissions
    }
}

// MARK: - Permission DTO

/// DTO for a single permission entry.
public struct PermissionDTO: Content, Sendable, Equatable {
    /// Content type slug this permission applies to, or "*" for all.
    public let contentTypeSlug: String
    /// The action: create, read, update, delete, publish, configure.
    public let action: String

    public init(contentTypeSlug: String, action: String) {
        self.contentTypeSlug = contentTypeSlug
        self.action = action
    }
}
