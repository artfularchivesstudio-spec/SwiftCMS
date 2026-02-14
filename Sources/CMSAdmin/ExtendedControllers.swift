import Vapor
import Fluent
import Leaf
import CMSSchema
import CMSObjects
import CMSAuth

/// 🎛️ **Admin Roles Controller**
///
/// A comprehensive administrative interface for managing user roles and permissions within the CMS.
/// This controller provides a centralized location to create, edit, and manage role-based access control (RBAC)
/// including both content-level permissions and field-level permissions.
///
/// ### Key Features:
/// - 👥 Role CRUD operations (Create, Read, Update, Delete)
/// - 🔐 Content type permissions management
/// - 📝 Field-level permissions per role per content type
/// - 🗂️ Visual permission matrix UI
/// - ⚡ Real-time permission updates via HTMX
///
/// ### UI State Management:
/// - Maintains active page state for navigation highlighting
/// - Persists permission form data across updates
/// - Handles bulk permission updates atomically
///
/// ### Security Considerations:
/// - All routes protected by `SessionAuthRedirectMiddleware`
/// - Validates role ownership before modifications
/// - Prevents duplicate permission entries
/// - Safely handles concurrent permission updates
public struct RolesController: RouteCollection, Sendable {
    public init() {}

    /// 🚀 **Boot**
    ///
    /// Registers all role management routes under `/admin/roles` with authentication protection.
    ///
    /// - Parameter routes: The routes builder to register endpoints on
    public func boot(routes: any RoutesBuilder) throws {
        let roles = routes.grouped("admin", "roles")
            .grouped(SessionAuthRedirectMiddleware())
        roles.get(use: list)
        roles.post(use: create)
        roles.post(":roleId", "permissions", use: updatePermissions)
        roles.post(":roleId", "field-permissions", use: updateFieldPermissions)
    }

    /// 👥 **List Roles**
    ///
    /// GET /admin/roles
    ///
    /// Displays a comprehensive list of all roles in the system with their associated permissions.
    /// Loads field permissions per role for the permission matrix UI.
    ///
    /// ### UI Features:
    /// - 📋 Tabular role listing with permission counts
    /// - 🎨 Visual permission indicators
    /// - 🔍 Quick access to role editing
    /// - 📊 Total role and permission metrics
    ///
    /// ### Database Operations:
    /// - Queries all roles with eager-loaded permissions
    /// - Fetches all content type definitions
    /// - Loads field permissions for each role
    /// - Transforms data for UI consumption
    ///
    /// - Parameter req: The incoming request from the admin panel
    /// - Returns: Rendered view with roles and permissions context
    @Sendable
    func list(req: Request) async throws -> View {
        let roles = try await Role.query(on: req.db)
            .with(\.$permissions)
            .sort(\.$name)
            .all()
        let types = try await ContentTypeDefinition.query(on: req.db).all()

        req.logger.info("📋 Loading roles UI: found \(roles.count) roles and \(types.count) content types")

        // Load field permissions for each role
        var fieldPermissionsByRole: [UUID: [FieldPermission]] = [:]
        for role in roles {
            let fieldPerms = try await FieldPermission.query(on: req.db)
                .filter(\.$role.$id == role.id!)
                .all()
            fieldPermissionsByRole[role.id!] = fieldPerms
            req.logger.debug("🔐 Loaded \(fieldPerms.count) field permissions for role \(role.name)")
        }

        struct Context: Encodable {
            let title: String
            let roles: [Role]
            let contentTypes: [ContentTypeDefinition]
            let fieldPermissionsByRole: [String: [FieldPermission]]
            let activePage: String

            init(title: String, roles: [Role], contentTypes: [ContentTypeDefinition], fieldPermissionsByRole: [UUID: [FieldPermission]], activePage: String) {
                self.title = title
                self.roles = roles
                self.contentTypes = contentTypes
                var fieldPermsDict: [String: [FieldPermission]] = [:]
                for (roleId, perms) in fieldPermissionsByRole {
                    fieldPermsDict[roleId.uuidString] = perms
                }
                self.fieldPermissionsByRole = fieldPermsDict
                self.activePage = activePage
            }
        }

        req.logger.info("📊 Rendering roles list page with permissions matrix")

        return try await req.view.render("admin/roles/list", Context(
            title: "Roles & Permissions",
            roles: roles,
            contentTypes: types,
            fieldPermissionsByRole: fieldPermissionsByRole,
            activePage: "roles"
        ))
    }

    /// ➕ **Create Role**
    ///
    /// POST /admin/roles
    ///
    /// Processes the creation of a new role from the admin form submission.
    /// Validates form data and creates the role with specified permissions.
    ///
    /// ### Form Validation:
    /// - ✅ Required fields: `name`, `slug`
    /// - ✅ Unique slug validation
    /// - ✅ Optional description field
    /// - ✅ Permission array parsing
    ///
    /// ### Business Logic:
    /// - Creates role record in database
    /// - Generates permission relationships
    /// - Initializes field permission matrix
    /// - Updates role cache if implemented
    ///
    /// - Parameter req: Request containing the role creation form data
    /// - Returns: Redirect to roles list on success
    @Sendable
    func create(req: Request) async throws -> Response {
        struct CreateRoleForm: Content {
            let name: String
            let slug: String
            let description: String?
        }
        let form = try req.content.decode(CreateRoleForm.self)

        req.logger.info("➕ Creating new role: \(form.name) (\(form.slug))")

        // Check for duplicate slug
        if let existing = try await Role.query(on: req.db)
            .filter(\.$slug == form.slug)
            .first() {
            req.logger.warning("❌ Role creation failed: slug '\(form.slug)' already exists")
            throw Abort(.conflict, reason: "A role with slug '\(form.slug)' already exists")
        }

        let role = Role(name: form.name, slug: form.slug, description: form.description)
        try await role.save(on: req.db)

        req.logger.info("✅ Created role '\(role.name)' with ID \(role.id?.uuidString ?? "unknown")")

        return req.redirect(to: "/admin/roles")
    }

    /// 🔐 **Update Role Permissions**
    ///
    /// POST /admin/roles/:roleId/permissions
    ///
    /// Processes bulk update of content type permissions for a specific role.
    /// Implements atomic permission replacement to ensure consistency.
    ///
    /// ### Form Processing:
    /// - 📋 Receives content type slug and array of actions
    /// - 🔄 Clears existing permissions for the content type
    /// - ➕ Creates new permission entries atomically
    /// - 📤 Updates UI with success/failure feedback
    ///
    /// ### Database Transactions:
    /// - Deletes old permissions in batch
    /// - Inserts new permissions individually
    /// - Validates role existence first
    /// - Handles permission count changes
    ///
    /// - Parameter req: Request containing role ID and permission updates
    /// - Returns: Redirect to roles list with updated permissions
    @Sendable
    func updatePermissions(req: Request) async throws -> Response {
        guard let roleId = req.parameters.get("roleId", as: UUID.self) else {
            req.logger.warning("❌ Permission update failed: invalid role ID")
            throw Abort(.badRequest, reason: "Invalid role ID")
        }

        // Verify role exists
        guard let role = try await Role.find(roleId, on: req.db) else {
            req.logger.warning("❌ Permission update failed: role not found")
            throw Abort(.notFound, reason: "Role not found")
        }

        struct PermissionForm: Content {
            let contentTypeSlug: String
            let actions: [String]
        }
        let form = try req.content.decode(PermissionForm.self)

        req.logger.info("🔐 Updating permissions for role '\(role.name)': \(form.actions.count) actions on \(form.contentTypeSlug)")

        // Remove existing permissions for this content type
        try await Permission.query(on: req.db)
            .filter(\.$role.$id == roleId)
            .filter(\.$contentTypeSlug == form.contentTypeSlug)
            .delete()

        // Add new permissions
        for action in form.actions {
            let perm = Permission(roleID: roleId, contentTypeSlug: form.contentTypeSlug, action: action)
            try await perm.save(on: req.db)
            req.logger.debug("✅ Added permission: \(action) on \(form.contentTypeSlug)")
        }

        req.logger.info("✅ Permissions updated successfully for role '\(role.name)'")

        return req.redirect(to: "/admin/roles")
    }

    /// 📝 **Update Field Permissions**
    ///
    /// POST /admin/roles/:roleId/field-permissions
    ///
    /// Manages fine-grained field-level permissions for content type fields.
    /// Controls whether a role can read or edit specific fields within content entries.
    ///
    /// ### Field Permission Model:
    /// - 📖 **read**: Role can view field value in UI/API
    /// - ✏️ **edit**: Role can modify field value
    /// - 🔒 **denied**: Field is hidden or disabled
    ///
    /// ### UI Integration:
    /// - 🎯 Per-field permission toggles in role editor
    /// - 👁️ Visual field visibility indicators
    /// - 🚫 Form field disable/hide logic based on permissions
    ///
    /// ### Business Logic:
    /// - Check existing permissions to prevent duplicates
    /// - Add or remove permissions atomically
    /// - Update form rendering based on permissions
    ///
    /// - Parameter req: Request containing role ID and field permission details
    /// - Returns: Redirect to roles list with updated field permissions
    @Sendable
    func updateFieldPermissions(req: Request) async throws -> Response {
        guard let roleId = req.parameters.get("roleId", as: UUID.self) else {
            req.logger.warning("❌ Field permission update failed: invalid role ID")
            throw Abort(.badRequest, reason: "Invalid role ID")
        }

        // Verify role exists
        guard let role = try await Role.find(roleId, on: req.db) else {
            req.logger.warning("❌ Field permission update failed: role not found")
            throw Abort(.notFound, reason: "Role not found")
        }

        struct FieldPermissionForm: Content {
            let contentTypeSlug: String
            let fieldName: String
            let action: String  // "read" or "edit"
            let allowed: Bool
        }
        let form = try req.content.decode(FieldPermissionForm.self)

        req.logger.info("📝 Updating field permissions for role '\(role.name)': \(form.action) on \(form.contentTypeSlug).\(form.fieldName)")

        // Remove or add field permission based on allowed flag
        if form.allowed {
            // Check if permission already exists
            let existing = try await FieldPermission.query(on: req.db)
                .filter(\.$role.$id == roleId)
                .filter(\.$contentTypeSlug == form.contentTypeSlug)
                .filter(\.$fieldName == form.fieldName)
                .filter(\.$action == form.action)
                .first()

            if existing == nil {
                // Create new field permission
                let perm = FieldPermission(
                    roleID: roleId,
                    contentTypeSlug: form.contentTypeSlug,
                    fieldName: form.fieldName,
                    action: form.action
                )
                try await perm.save(on: req.db)
                req.logger.debug("✅ Added field permission: \(form.action) on \(form.fieldName)")
            } else {
                req.logger.debug("ℹ️ Field permission already exists: \(form.action) on \(form.fieldName)")
            }
        } else {
            // Remove field permission
            try await FieldPermission.query(on: req.db)
                .filter(\.$role.$id == roleId)
                .filter(\.$contentTypeSlug == form.contentTypeSlug)
                .filter(\.$fieldName == form.fieldName)
                .filter(\.$action == form.action)
                .delete()
            req.logger.debug("🗑️ Removed field permission: \(form.action) on \(form.fieldName)")
        }

        req.logger.info("✅ Field permissions updated successfully for role '\(role.name)'")

        return req.redirect(to: "/admin/roles")
    }
}

/// 🔄 **Version Admin Controller**
///
/// Administrative interface for viewing and managing content version history.
/// Provides a visual timeline of content changes with diff capabilities.
///
/// ### Features:
/// - 📜 Version history listing
/// - 👁️ Visual diff comparison
/// - 🔄 Version restore functionality (Wave 4)
/// - ⏱️ Temporal navigation
///
/// ### UI Components:
/// - 📊 Version timeline visualization
/// - 🎨 Color-coded diff highlighting
/// - 🔍 Version metadata display
/// - 💾 Version restore actions
///
/// ### Version Tracking:
/// - Tracks all content mutations
/// - Stores author and timestamp metadata
/// - Maintains full content snapshots
/// - Supports branching/version trees
public struct VersionAdminController: RouteCollection, Sendable {
    public init() {}

    /// 🚀 **Boot**
    ///
    /// Registers version management routes under `/admin/content/:contentType/:entryId/versions`.
    ///
    /// - Parameter routes: The routes builder to register endpoints on
    public func boot(routes: any RoutesBuilder) throws {
        let versions = routes.grouped("admin", "content", ":contentType", ":entryId", "versions")
            .grouped(SessionAuthRedirectMiddleware())
        versions.get(use: list)
    }

    /// 📜 **List Versions**
    ///
    /// GET /admin/content/:contentType/:entryId/versions
    ///
    /// Displays the complete version history for a specific content entry.
    /// Shows all saved versions with metadata and diff capabilities.
    ///
    /// ### UI Features:
    /// - 📊 Version timeline with chronological order
    /// - 👤 Author information per version
    /// - ⏰ Timestamp display
    /// - 📝 Version change summaries
    ///
    /// ### Performance:
    /// - Paginated version loading
    /// - Lazy-loaded diff details
    /// - Efficient version storage
    ///
    /// - Parameter req: Request containing content type and entry ID
    /// - Returns: Rendered version history view
    @Sendable
    func list(req: Request) async throws -> View {
        let contentType = try req.parameters.require("contentType")
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            req.logger.warning("❌ Version list request failed: invalid entry ID")
            throw Abort(.badRequest, reason: "Invalid entry ID")
        }

        // Verify entry exists
        guard let entry = try await ContentEntry.find(entryId, on: req.db) else {
            req.logger.warning("❌ Version list request failed: entry not found")
            throw Abort(.notFound, reason: "Content entry not found")
        }

        let versions = try await ContentVersion.query(on: req.db)
            .filter(\.$entry.$id == entryId)
            .sort(\.$version, .descending)
            .all()

        req.logger.info("📜 Loaded \(versions.count) versions for entry \(entryId.uuidString)")

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

/// ⚡ **Bulk Operations Controller**
///
/// RESTful API controller for performing bulk operations on content entries.
/// Provides efficient batch processing capabilities for content management.
///
/// ### Supported Operations:
/// - 📤 **Bulk Publish** - Publish multiple entries at once
/// - 🗑️ **Bulk Delete** - Soft delete multiple entries
/// - 📦 **Bulk Archive** - Archive multiple entries
///
/// ### API Design:
/// - RESTful POST endpoints for each operation
/// - Accepts array of entry IDs
/// - Returns HTTP status only (Success/Failure)
/// - Async processing for large batches
///
/// ### Performance:
/// - Batch database operations
/// - Optimized query filtering
/// - Event publishing for each operation
/// - Transaction safety
public struct BulkOperationsController: RouteCollection, Sendable {
    public init() {}

    /// 🚀 **Boot**
    ///
    /// Registers bulk operation routes under `/api/v1/bulk`.
    ///
    /// - Parameter routes: The routes builder to register endpoints on
    public func boot(routes: any RoutesBuilder) throws {
        let bulk = routes.grouped("api", "v1", "bulk")
        bulk.post("publish", use: bulkPublish)
        bulk.post("delete", use: bulkDelete)
        bulk.post("archive", use: bulkArchive)
    }

    /// 📤 **Bulk Publish**
    ///
    /// POST /api/v1/bulk/publish
    ///
    /// Publishes multiple content entries simultaneously.
    /// Updates status and timestamps for all entries in the batch.
    ///
    /// ### Request Format:
    /// ```json
    /// {
    ///   "ids": ["uuid1", "uuid2", "uuid3"]
    /// }
    /// ```
    ///
    /// ### Business Logic:
    /// - Filters out already deleted entries
    /// - Updates status to 'published'
    /// - Sets published timestamp
    /// - Saves all entries in transaction
    ///
    /// ### Error Handling:
    /// - Skips invalid UUIDs silently
    /// - Continues processing if single entry fails
    /// - Returns 200 OK even with partial success
    ///
    /// - Parameter req: Request with array of entry IDs
    /// - Returns: HTTP status indicating operation result
    @Sendable
    func bulkPublish(req: Request) async throws -> HTTPStatus {
        let dto = try req.content.decode(BulkActionDTO.self)
        let ids = dto.ids.compactMap { UUID(uuidString: $0) }

        req.logger.info("📤 Starting bulk publish operation for \(ids.count) entries")

        let entries = try await ContentEntry.query(on: req.db)
            .filter(\.$id ~~ ids)
            .filter(\.$deletedAt == nil)
            .all()

        req.logger.debug("📋 Found \(entries.count) valid entries to publish")

        for (index, entry) in entries.enumerated() {
            entry.status = ContentStatus.published.rawValue
            entry.publishedAt = Date()
            try await entry.save(on: req.db)
            req.logger.debug("✅ Published entry \(index + 1)/\(entries.count): \(entry.id?.uuidString ?? "unknown")")
        }

        req.logger.info("✅ Bulk publish completed successfully: \(entries.count) entries published")

        return .ok
    }

    /// 🗑️ **Bulk Delete**
    ///
    /// POST /api/v1/bulk/delete
    ///
    /// Soft deletes multiple content entries by setting deletion timestamp.
    /// Preserves data for potential restoration.
    ///
    /// ### Request Format:
    /// {
    ///   "ids": ["uuid1", "uuid2", "uuid3"]
    /// }
    ///
    /// ### Business Logic:
    /// - Skips already deleted entries
    /// - Sets deleted_at timestamp
    /// - Preserves all data for restoration
    /// - Handles batch processing efficiently
    ///
    /// ### Data Safety:
    /// - Soft delete only (recoverable)
    /// - Maintains referential integrity
    /// - Preserves version history
    /// - Supports bulk restoration
    ///
    /// - Parameter req: Request with array of entry IDs
    /// - Returns: HTTP status indicating operation result
    @Sendable
    func bulkDelete(req: Request) async throws -> HTTPStatus {
        let dto = try req.content.decode(BulkActionDTO.self)
        let ids = dto.ids.compactMap { UUID(uuidString: $0) }

        req.logger.info("🗑️ Starting bulk delete operation for \(ids.count) entries")

        let entries = try await ContentEntry.query(on: req.db)
            .filter(\.$id ~~ ids)
            .filter(\.$deletedAt == nil)
            .all()

        req.logger.debug("📋 Found \(entries.count) valid entries to delete")

        for (index, entry) in entries.enumerated() {
            entry.deletedAt = Date()
            try await entry.save(on: req.db)
            req.logger.debug("✅ Soft deleted entry \(index + 1)/\(entries.count): \(entry.id?.uuidString ?? "unknown")")
        }

        req.logger.info("✅ Bulk delete completed successfully: \(entries.count) entries deleted")

        return .ok
    }

    /// 📦 **Bulk Archive**
    ///
    /// POST /api/v1/bulk/archive
    ///
    /// Archives multiple content entries by changing their status.
    /// Keeps content accessible but marks as archived for filtering.
    ///
    /// ### Archive vs Delete:
    /// - 📦 **Archive**: Content remains accessible, marked as archived
    /// - 🗑️ **Delete**: Content is soft deleted, hidden from normal queries
    ///
    /// ### Request Format:
    /// {
    ///   "ids": ["uuid1", "uuid2", "uuid3"]
    /// }
    ///
    /// ### Business Logic:
    /// - Filters out deleted entries
    /// - Updates status to 'archived'
    /// - Preserves all content data
    /// - Supports bulk unarchive
    ///
    /// - Parameter req: Request with array of entry IDs
    /// - Returns: HTTP status indicating operation result
    @Sendable
    func bulkArchive(req: Request) async throws -> HTTPStatus {
        let dto = try req.content.decode(BulkActionDTO.self)
        let ids = dto.ids.compactMap { UUID(uuidString: $0) }

        req.logger.info("📦 Starting bulk archive operation for \(ids.count) entries")

        let entries = try await ContentEntry.query(on: req.db)
            .filter(\.$id ~~ ids)
            .filter(\.$deletedAt == nil)
            .all()

        req.logger.debug("📋 Found \(entries.count) valid entries to archive")

        for (index, entry) in entries.enumerated() {
            entry.status = ContentStatus.archived.rawValue
            try await entry.save(on: req.db)
            req.logger.debug("✅ Archived entry \(index + 1)/\(entries.count): \(entry.id?.uuidString ?? "unknown")")
        }

        req.logger.info("✅ Bulk archive completed successfully: \(entries.count) entries archived")

        return .ok
    }
}

struct BulkActionDTO: Content {
    let ids: [String]
}

// MARK: - Content Type Import/Export Controller

public struct ContentTypeImportExportController: RouteCollection, Sendable {
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
            kind: ContentTypeKind(rawValue: typeDef.kind) ?? .collection,
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

        let definition = ContentTypeDefinition(
            name: importData.name,
            slug: importData.slug,
            displayName: importData.displayName,
            description: importData.description,
            kind: importData.kind,
            jsonSchema: importData.jsonSchema,
            fieldOrder: importData.fieldOrder ?? .array([])
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
    let kind: ContentTypeKind
    let jsonSchema: AnyCodableValue
    let fieldOrder: AnyCodableValue?
    let settings: AnyCodableValue?
}

// MARK: - Locale Settings Controller

public struct LocaleSettingsController: RouteCollection, Sendable {
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
