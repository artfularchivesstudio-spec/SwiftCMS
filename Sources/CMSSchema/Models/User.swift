import Fluent
import Vapor
import CMSObjects

// MARK: - User Model

/// Represents an admin or API user in the system.
public final class User: Model, Content, @unchecked Sendable {
    public static let schema = "users"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "email")
    public var email: String

    @OptionalField(key: "password_hash")
    public var passwordHash: String?

    @OptionalField(key: "display_name")
    public var displayName: String?

    @Parent(key: "role_id")
    public var role: Role

    @Field(key: "auth_provider")
    public var authProvider: String

    @OptionalField(key: "external_id")
    public var externalId: String?

    @OptionalField(key: "tenant_id")
    public var tenantId: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil, email: String, passwordHash: String? = nil,
        displayName: String? = nil, roleID: UUID, authProvider: String = "local",
        externalId: String? = nil, tenantId: String? = nil
    ) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.displayName = displayName
        self.$role.id = roleID
        self.authProvider = authProvider
        self.externalId = externalId
        self.tenantId = tenantId
    }

    /// Convert to response DTO.
    public func toResponseDTO(roleName: String? = nil) -> UserResponseDTO {
        UserResponseDTO(
            id: id ?? UUID(),
            email: email,
            displayName: displayName,
            roleName: roleName,
            authProvider: authProvider,
            createdAt: createdAt
        )
    }
}

// MARK: - ModelSessionAuthenticatable

extension User: ModelSessionAuthenticatable {}

// MARK: - Role Model

/// Represents an RBAC role.
public final class Role: Model, Content, @unchecked Sendable {
    public static let schema = "roles"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @Field(key: "slug")
    public var slug: String

    @OptionalField(key: "description")
    public var description: String?

    @Field(key: "is_system")
    public var isSystem: Bool

    @Children(for: \.$role)
    public var permissions: [Permission]

    @Children(for: \.$role)
    public var users: [User]

    public init() {}

    public init(
        id: UUID? = nil, name: String, slug: String,
        description: String? = nil, isSystem: Bool = false
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.isSystem = isSystem
    }

    /// Convert to response DTO.
    public func toResponseDTO(permissions: [PermissionDTO]? = nil) -> RoleResponseDTO {
        RoleResponseDTO(
            id: id ?? UUID(),
            name: name,
            slug: slug,
            description: description,
            isSystem: isSystem,
            permissions: permissions
        )
    }
}

// MARK: - Permission Model

/// Represents a permission linking a role to a content type action.
public final class Permission: Model, Content, @unchecked Sendable {
    public static let schema = "permissions"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "role_id")
    public var role: Role

    @Field(key: "content_type_slug")
    public var contentTypeSlug: String

    @Field(key: "action")
    public var action: String

    public init() {}

    public init(
        id: UUID? = nil, roleID: UUID,
        contentTypeSlug: String, action: String
    ) {
        self.id = id
        self.$role.id = roleID
        self.contentTypeSlug = contentTypeSlug
        self.action = action
    }

    /// Convert to DTO.
    public func toDTO() -> PermissionDTO {
        PermissionDTO(contentTypeSlug: contentTypeSlug, action: action)
    }
}
