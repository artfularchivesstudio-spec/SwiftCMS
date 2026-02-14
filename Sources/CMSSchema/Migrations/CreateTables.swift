import Fluent
import Vapor

// MARK: - CreateRoles

public struct CreateRoles: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("roles")
            .id()
            .field("name", .string, .required)
            .field("slug", .string, .required)
            .field("description", .string)
            .field("is_system", .bool, .required, .custom("DEFAULT false"))
            .unique(on: "slug")
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("roles").delete()
    }
}

// MARK: - CreateUsers

public struct CreateUsers: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("email", .string, .required)
            .field("password_hash", .string)
            .field("display_name", .string)
            .field("role_id", .uuid, .required, .references("roles", "id"))
            .field("auth_provider", .string, .required, .custom("DEFAULT 'local'"))
            .field("external_id", .string)
            .field("tenant_id", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "email")
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}

// MARK: - CreatePermissions

public struct CreatePermissions: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("permissions")
            .id()
            .field("role_id", .uuid, .required, .references("roles", "id", onDelete: .cascade))
            .field("content_type_slug", .string, .required)
            .field("action", .string, .required)
            .unique(on: "role_id", "content_type_slug", "action")
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("permissions").delete()
    }
}

// MARK: - CreateApiKeys

public struct CreateApiKeys: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("api_keys")
            .id()
            .field("name", .string, .required)
            .field("key_hash", .string, .required)
            .field("permissions", .json, .required)
            .field("last_used_at", .datetime)
            .field("expires_at", .datetime)
            .field("tenant_id", .string)
            .field("created_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("api_keys").delete()
    }
}

// MARK: - CreateMediaFiles

public struct CreateMediaFiles: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("media_files")
            .id()
            .field("filename", .string, .required)
            .field("mime_type", .string, .required)
            .field("size_bytes", .int, .required)
            .field("storage_path", .string, .required)
            .field("provider", .string, .required, .custom("DEFAULT 'local'"))
            .field("alt_text", .string)
            .field("metadata", .json)
            .field("tenant_id", .string)
            .field("created_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("media_files").delete()
    }
}

// MARK: - CreateWebhooks

public struct CreateWebhooks: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("webhooks")
            .id()
            .field("name", .string, .required)
            .field("url", .string, .required)
            .field("events", .json, .required)
            .field("headers", .json)
            .field("secret", .string, .required)
            .field("enabled", .bool, .required, .custom("DEFAULT true"))
            .field("retry_count", .int, .required, .custom("DEFAULT 5"))
            .field("tenant_id", .string)
            .field("created_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("webhooks").delete()
    }
}

// MARK: - CreateWebhookDeliveries

public struct CreateWebhookDeliveries: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("webhook_deliveries")
            .id()
            .field("webhook_id", .uuid, .required, .references("webhooks", "id", onDelete: .cascade))
            .field("event", .string, .required)
            .field("payload", .json, .required)
            .field("idempotency_key", .string, .required)
            .field("response_status", .int)
            .field("attempts", .int, .required, .custom("DEFAULT 0"))
            .field("delivered_at", .datetime)
            .field("created_at", .datetime)
            .unique(on: "idempotency_key")
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("webhook_deliveries").delete()
    }
}

// MARK: - CreateDeadLetterEntries

public struct CreateDeadLetterEntries: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("dead_letter_entries")
            .id()
            .field("job_type", .string, .required)
            .field("payload", .json, .required)
            .field("failure_reason", .string, .required)
            .field("retry_count", .int, .required)
            .field("first_failed_at", .datetime)
            .field("last_failed_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("dead_letter_entries").delete()
    }
}

// MARK: - CreateAuditLog

public struct CreateAuditLog: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("audit_log")
            .id()
            .field("entry_id", .uuid)
            .field("content_type", .string)
            .field("action", .string, .required)
            .field("user_id", .string)
            .field("before_data", .json)
            .field("after_data", .json)
            .field("tenant_id", .string)
            .field("created_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("audit_log").delete()
    }
}

// MARK: - CreateContentTypeDefinitions

public struct CreateContentTypeDefinitions: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("content_type_definitions")
            .id()
            .field("name", .string, .required)
            .field("slug", .string, .required)
            .field("display_name", .string, .required)
            .field("description", .string)
            .field("kind", .string, .required, .custom("DEFAULT 'collection'"))
            .field("json_schema", .json, .required)
            .field("field_order", .json, .required)
            .field("settings", .json)
            .field("tenant_id", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "slug")
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("content_type_definitions").delete()
    }
}

// MARK: - CreateContentEntries

public struct CreateContentEntries: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("content_entries")
            .id()
            .field("content_type", .string, .required)
            .field("data", .json, .required)
            .field("status", .string, .required, .custom("DEFAULT 'draft'"))
            .field("locale", .string)
            .field("publish_at", .datetime)
            .field("unpublish_at", .datetime)
            .field("created_by", .string)
            .field("updated_by", .string)
            .field("tenant_id", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("published_at", .datetime)
            .field("deleted_at", .datetime)
            .create()

        // B-tree index on (tenant_id, content_type)
        // GIN index on data is PostgreSQL-specific (added conditionally)
        // We skip GIN for SQLite
    }

    public func revert(on database: Database) async throws {
        try await database.schema("content_entries").delete()
    }
}

// MARK: - CreateContentVersions

public struct CreateContentVersions: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("content_versions")
            .id()
            .field("entry_id", .uuid, .required, .references("content_entries", "id", onDelete: .cascade))
            .field("version", .int, .required)
            .field("data", .json, .required)
            .field("changed_by", .string)
            .field("created_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("content_versions").delete()
    }
}

// MARK: - SeedDefaultRoles

public struct SeedDefaultRoles: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        let superAdmin = Role(
            name: "Super Admin", slug: "super-admin",
            description: "Full system access", isSystem: true
        )
        let editor = Role(
            name: "Editor", slug: "editor",
            description: "Can manage all content", isSystem: false
        )
        let author = Role(
            name: "Author", slug: "author",
            description: "Can manage own content", isSystem: false
        )
        let publicRole = Role(
            name: "Public", slug: "public",
            description: "Unauthenticated access", isSystem: true
        )

        try await superAdmin.save(on: database)
        try await editor.save(on: database)
        try await author.save(on: database)
        try await publicRole.save(on: database)

        // Grant super admin all permissions on wildcard
        guard let adminId = superAdmin.id else { return }
        let actions = ["create", "read", "update", "delete", "publish", "configure"]
        for action in actions {
            let perm = Permission(roleID: adminId, contentTypeSlug: "*", action: action)
            try await perm.save(on: database)
        }

        // Create default admin user if env vars provided
        if let adminEmail = Environment.get("ADMIN_EMAIL"),
           let adminPassword = Environment.get("ADMIN_PASSWORD") {
            let hash = try Bcrypt.hash(adminPassword)
            let admin = User(
                email: adminEmail,
                passwordHash: hash,
                displayName: "Admin",
                roleID: adminId,
                authProvider: "local"
            )
            try await admin.save(on: database)
        }
    }

    public func revert(on database: Database) async throws {
        try await Permission.query(on: database).delete()
        try await User.query(on: database).delete()
        try await Role.query(on: database).delete()
    }
}
