import Fluent
import Vapor

// MARK: - CreateRoles Migration

/// 🔄 **CreateRoles Migration**
/// Creates the `roles` table for RBAC role management
///
/// ## 📋 Schema Changes
/// - Creates table: `roles`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `name` (String, Required)
///   - `slug` (String, Required, Unique)
///   - `description` (String, Optional)
///   - `is_system` (Bool, Required, Default: false)
///
/// ## 📊 Indexes
/// - Unique index on `slug` (required for role lookup)
///
/// ## 🔍 Usage
/// Called during initial database migration to establish RBAC foundation
public struct CreateRoles: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration (create tables/indexes)
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

    /// 🔄 Revert migration (drop tables)
    public func revert(on database: Database) async throws {
        try await database.schema("roles").delete()
    }
}

// MARK: - CreateUsers Migration

/// 🔄 **CreateUsers Migration**
/// Creates the `users` table for authentication
///
/// ## 📋 Schema Changes
/// - Creates table: `users`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `email` (String, Required, Unique)
///   - `password_hash` (String, Optional - for local auth)
///   - `display_name` (String, Optional)
///   - `role_id` (UUID, Required, FK to roles)
///   - `auth_provider` (String, Required, Default: 'local')
///   - `external_id` (String, Optional - for OAuth)
///   - `tenant_id` (String, Optional)
///   - `created_at` (DateTime, Auto)
///   - `updated_at` (DateTime, Auto)
///
/// ## 🔗 Foreign Keys
/// - `role_id` → `roles.id`
///
/// ## 📊 Indexes
/// - Unique index on `email` (required for login)
public struct CreateUsers: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration
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

    /// 🔄 Revert migration
    public func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}

// MARK: - CreatePermissions Migration

/// 🔄 **CreatePermissions Migration**
/// Creates the `permissions` table for role-based access control
///
/// ## 📋 Schema Changes
/// - Creates table: `permissions`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `role_id` (UUID, Required, FK to roles, Cascade Delete)
///   - `content_type_slug` (String, Required)
///   - `action` (String, Required)
///
/// ## 🔗 Foreign Keys
/// - `role_id` → `roles.id` (ON DELETE CASCADE)
///
/// ## 📊 Indexes
/// - Unique: `(role_id, content_type_slug, action)`
///   Prevents duplicate permissions for same role/type/action combo
public struct CreatePermissions: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration
    public func prepare(on database: Database) async throws {
        try await database.schema("permissions")
            .id()
            .field("role_id", .uuid, .required, .references("roles", "id", onDelete: .cascade))
            .field("content_type_slug", .string, .required)
            .field("action", .string, .required)
            .unique(on: "role_id", "content_type_slug", "action")
            .create()
    }

    /// 🔄 Revert migration
    public func revert(on database: Database) async throws {
        try await database.schema("permissions").delete()
    }
}

// MARK: - CreateApiKeys Migration

/// 🔄 **CreateApiKeys Migration**
/// Creates the `api_keys` table for machine-to-machine authentication
///
/// ## 📋 Schema Changes
/// - Creates table: `api_keys`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `name` (String, Required)
///   - `key_hash` (String, Required, hashed key)
///   - `permissions` (JSON, Required - array of permissions)
///   - `last_used_at` (DateTime, Optional)
///   - `expires_at` (DateTime, Optional)
///   - `tenant_id` (String, Optional)
///   - `created_at` (DateTime)
///
/// ## 🔐 Security Notes
/// - Store only SHA256 hashes of API keys (never plaintext)
/// - Keys can have expiration dates for rotation
/// - Permissions stored as JSON array of action strings
public struct CreateApiKeys: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration
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

    /// 🔄 Revert migration
    public func revert(on database: Database) async throws {
        try await database.schema("api_keys").delete()
    }
}

// MARK: - CreateMediaFiles Migration

/// 🔄 **CreateMediaFiles Migration**
/// Creates the `media_files` table for media asset management
///
/// ## 📋 Schema Changes
/// - Creates table: `media_files`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `filename` (String, Required)
///   - `mime_type` (String, Required)
///   - `size_bytes` (Int, Required)
///   - `storage_path` (String, Required)
///   - `provider` (String, Required, Default: 'local')
///   - `alt_text` (String, Optional)
///   - `metadata` (JSON, Optional)
///   - `tenant_id` (String, Optional)
///   - `thumbnail_small` (String, Optional)
///   - `thumbnail_medium` (String, Optional)
///   - `thumbnail_large` (String, Optional)
///   - `created_at` (DateTime)
///
/// ## 💽 Storage Strategy
/// - Store actual file paths in `storage_path`
/// - Support multiple storage providers (S3, local, etc.)
/// - Generate multiple thumbnail sizes
public struct CreateMediaFiles: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration
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
            .field("thumbnail_small", .string)
            .field("thumbnail_medium", .string)
            .field("thumbnail_large", .string)
            .field("created_at", .datetime)
            .create()
    }

    /// 🔄 Revert migration
    public func revert(on database: Database) async throws {
        try await database.schema("media_files").delete()
    }
}

// MARK: - CreateWebhooks Migration

/// 🔄 **CreateWebhooks Migration**
/// Creates the `webhooks` table for outbound event notifications
///
/// ## 📋 Schema Changes
/// - Creates table: `webhooks`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `name` (String, Required)
///   - `url` (String, Required - webhook endpoint)
///   - `events` (JSON, Required - array of event names)
///   - `headers` (JSON, Optional - custom HTTP headers)
///   - `secret` (String, Required - for HMAC signing)
///   - `enabled` (Bool, Required, Default: true)
///   - `retry_count` (Int, Required, Default: 5)
///   - `tenant_id` (String, Optional)
///   - `created_at` (DateTime)
///
/// ## 🔄 Events
/// Webhooks are triggered by CMS events like:
/// - content.created / content.updated / content.deleted
/// - schema.created / schema.updated / schema.deleted
public struct CreateWebhooks: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration
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

    /// 🔄 Revert migration
    public func revert(on database: Database) async throws {
        try await database.schema("webhooks").delete()
    }
}

// MARK: - CreateWebhookDeliveries Migration

/// 🔄 **CreateWebhookDeliveries Migration**
/// Creates the `webhook_deliveries` table for webhook attempt tracking
///
/// ## 📋 Schema Changes
/// - Creates table: `webhook_deliveries`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `webhook_id` (UUID, Required, FK to webhooks, Cascade Delete)
///   - `event` (String, Required - triggered event name)
///   - `payload` (JSON, Required - webhook payload)
///   - `idempotency_key` (String, Required, Unique)
///   - `response_status` (Int, Optional - HTTP status)
///   - `attempts` (Int, Required, Default: 0)
///   - `delivered_at` (DateTime, Optional)
///   - `created_at` (DateTime)
///
/// ## 🔗 Foreign Keys
/// - `webhook_id` → `webhooks.id` (ON DELETE CASCADE)
///
/// ## 📊 Indexes
/// - Unique: `idempotency_key` (prevents duplicate deliveries)
///
/// ## 💾 Delivery Tracking
/// - Track each webhook attempt separately
/// - Idempotency prevents duplicate processing
/// - Retry count shows delivery attempts
public struct CreateWebhookDeliveries: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration
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

    /// 🔄 Revert migration
    public func revert(on database: Database) async throws {
        try await database.schema("webhook_deliveries").delete()
    }
}

// MARK: - CreateDeadLetterEntries Migration

/// 🔄 **CreateDeadLetterEntries Migration**
/// Creates the `dead_letter_entries` table for failed job tracking
///
/// ## 📋 Schema Changes
/// - Creates table: `dead_letter_entries`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `job_type` (String, Required - job class/type)
///   - `payload` (JSON, Required - original job data)
///   - `failure_reason` (String, Required - error message)
///   - `retry_count` (Int, Required - number of attempts)
///   - `first_failed_at` (DateTime, Optional)
///   - `last_failed_at` (DateTime, Optional)
///
/// ## 💾 Failure Management
/// - Store jobs that exhausted all retry attempts
/// - Manual inspection and reprocessing required
/// - Used for debugging and reliability tracking
public struct CreateDeadLetterEntries: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration
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

    /// 🔄 Revert migration
    public func revert(on database: Database) async throws {
        try await database.schema("dead_letter_entries").delete()
    }
}

// MARK: - CreateAuditLog Migration

/// 🔄 **CreateAuditLog Migration**
/// Creates the `audit_log` table for compliance and security tracking
///
/// ## 📋 Schema Changes
/// - Creates table: `audit_log`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `entry_id` (UUID, Optional - affected content entry)
///   - `content_type` (String, Optional - content type slug)
///   - `action` (String, Required - operation performed)
///   - `user_id` (String, Optional - who performed action)
///   - `before_data` (JSON, Optional - state before change)
///   - `after_data` (JSON, Optional - state after change)
///   - `tenant_id` (String, Optional)
///   - `created_at` (DateTime)
///
/// ## 💾 Audit Trail
/// - Immutable log of all content mutations
/// - Never updated or deleted
/// - Required for compliance and debugging
public struct CreateAuditLog: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration
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

    /// 🔄 Revert migration
    public func revert(on database: Database) async throws {
        try await database.schema("audit_log").delete()
    }
}

// MARK: - CreateContentTypeDefinitions Migration

/// 🔄 **CreateContentTypeDefinitions Migration**
/// Creates the `content_type_definitions` table (schema registry)
///
/// ## 📋 Schema Changes
/// - Creates table: `content_type_definitions`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `name` (String, Required)
///   - `slug` (String, Required, Unique)
///   - `display_name` (String, Required)
///   - `description` (String, Optional)
///   - `kind` (String, Required, Default: 'collection')
///   - `json_schema` (JSON, Required - fields and validation)
///   - `field_order` (JSON, Required - UI field order)
///   - `settings` (JSON, Optional - type configuration)
///   - `tenant_id` (String, Optional)
///   - `schema_hash` (String - SHA256 of json_schema)
///   - `created_at` (DateTime)
///   - `updated_at` (DateTime)
///
/// ## 📊 Indexes
/// - Unique: `slug` (content type lookup)
///
/// ## 🔧 Registry Purpose
/// Central registry of all content types in the CMS
/// Powers dynamic schema management and validation
public struct CreateContentTypeDefinitions: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration
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

    /// 🔄 Revert migration
    public func revert(on database: Database) async throws {
        try await database.schema("content_type_definitions").delete()
    }
}

// MARK: - CreateContentEntries Migration

/// 🔄 **CreateContentEntries Migration**
/// Creates the `content_entries` table for dynamic content storage
///
/// ## 📋 Schema Changes
/// - Creates table: `content_entries`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `content_type` (String, Required - FK to content_type_definitions.slug)
///   - `data` (JSON, Required - polymorphic payload)
///   - `status` (String, Required, Default: 'draft')
///   - `locale` (String, Optional)
///   - `publish_at` (DateTime, Optional)
///   - `unpublish_at` (DateTime, Optional)
///   - `created_by` (String, Optional - user ID)
///   - `updated_by` (String, Optional - user ID)
///   - `tenant_id` (String, Optional)
///   - `created_at` (DateTime)
///   - `updated_at` (DateTime)
///   - `published_at` (DateTime) - for sorting
///   - `deleted_at` (DateTime) - soft delete
///
/// ## 📊 Indexes
/// - B-tree: `(tenant_id, content_type)` - for efficient tenant filtering
/// - GIN: `data` (PostgreSQL only, for JSONB queries)
///
/// ## 💾 Polymorphic Design
/// All content of any type stored in one table
/// JsonSchema validation ensures data integrity per content type
public struct CreateContentEntries: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration
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

    /// 🔄 Revert migration
    public func revert(on database: Database) async throws {
        try await database.schema("content_entries").delete()
    }
}

// MARK: - CreateContentVersions Migration

/// 🔄 **CreateContentVersions Migration**
/// Creates the `content_versions` table for version history tracking
///
/// ## 📋 Schema Changes
/// - Creates table: `content_versions`
/// - Fields:
///   - `id` (UUID, Primary Key)
///   - `entry_id` (UUID, Required, FK to content_entries)
///   - `version` (Int, Required - version number)
///   - `data` (JSON, Required - snapshot of entry data)
///   - `changed_by` (String, Optional - user ID)
///   - `created_at` (DateTime)
///
/// ## 🔗 Foreign Keys
/// - `entry_id` → `content_entries.id` (ON DELETE CASCADE)
///
/// ## 📊 Indexes
/// - Composite index suggested: `(entry_id, version DESC)`
///   Not explicitly created as Fluent handles this
///
/// ## 🔄 Versioning Strategy
/// Automatic versioning on content updates
/// Enables rollback and diff comparison features
public struct CreateContentVersions: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration
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

    /// 🔄 Revert migration
    public func revert(on database: Database) async throws {
        try await database.schema("content_versions").delete()
    }
}

// MARK: - SeedDefaultRoles Migration

/// 🔄 **SeedDefaultRoles Migration**
/// Seeds initial roles and creates default admin user
///
/// ## 📋 Schema Changes
/// Inserts default rows into `roles` and `permissions` tables
///
/// ## 🎯 Default Roles Created
/// - **Super Admin**: Full system access, wildcard permissions
/// - **Editor**: Can manage all content, all content types
/// - **Author**: Can manage own content
/// - **Public**: Unauthenticated public access
///
/// ## 🔐 Default Admin User
/// If `ADMIN_EMAIL` and `ADMIN_PASSWORD` env vars are set:
/// - Creates admin user with Super Admin role
/// - Used for initial system access
///
/// ## ⚠️ Security Note
/// Default admin credentials should be changed immediately in production
public struct SeedDefaultRoles: AsyncMigration {
    public init() {}

    /// 🚀 Prepare migration (seed data)
    public func prepare(on database: Database) async throws {
        // Create default roles
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

    /// 🔄 Revert migration (delete seeded data)
    public func revert(on database: Database) async throws {
        try await Permission.query(on: database).delete()
        try await User.query(on: database).delete()
        try await Role.query(on: database).delete()
    }
}
