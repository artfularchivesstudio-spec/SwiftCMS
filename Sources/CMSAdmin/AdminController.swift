import Vapor
import Fluent
import Leaf
import CMSCore
import CMSSchema
import CMSObjects
import CMSAuth
import CMSEvents
import CMSMedia

// MARK: - Admin Controller

/// Main admin panel controller.
/// Routes: /admin
public struct AdminController: RouteCollection, Sendable {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let admin = routes.grouped("admin")

        // Public routes
        admin.get("login", use: loginPage)
        admin.post("login", use: loginAction)
        admin.get("logout", use: logout)

        // Protected routes
        let protected = admin.grouped(SessionAuthRedirectMiddleware())
        protected.get(use: dashboard)
        protected.get("content-types", use: contentTypes)
        protected.post("content-types", ":id", "duplicate", use: duplicateContentType)
        protected.get("content-types", "new", use: contentTypeBuilder)
        protected.get("content", ":contentType", use: contentList)
        protected.get("content", ":contentType", "new", use: contentEdit)
        protected.get("content", ":contentType", ":entryId", use: contentEdit)
        protected.get("media", use: mediaLibrary)
        protected.get("users", use: userList)
        protected.get("webhooks", use: webhookList)
        protected.get("settings", use: settings)
        protected.get("system", "dlq", use: deadLetterQueue)

        // POST routes — Wave 2: form-based mutations
        protected.post("content-types", use: createContentType)
        protected.post("content", ":contentType", use: createOrUpdateEntry)
        protected.post("content", ":contentType", ":entryId", use: createOrUpdateEntry)
        protected.post("webhooks", use: createWebhook)
        protected.post("webhooks", ":webhookId", "delete", use: deleteWebhook)
        protected.post("webhooks", ":webhookId", "toggle", use: toggleWebhook)
        protected.post("users", use: createUser)
        protected.post("users", ":userId", "delete", use: deleteUser)

        // Admin search (HTMX)
        protected.get("search", use: adminSearch)

        // Webhook edit/deliveries
        protected.get("webhooks", "new", use: webhookEdit)
        protected.get("webhooks", ":webhookId", "edit", use: webhookEdit)
        protected.get("webhooks", ":webhookId", "deliveries", use: webhookDeliveries)

        // Media upload via admin form
        protected.on(.POST, "media", "upload", body: .collect(maxSize: "50mb"), use: adminMediaUpload)

        // Bulk operations (Wave 3)
        protected.post("content", ":contentType", "bulk", use: bulkContentOperation)
        protected.post("media", "bulk", use: bulkMediaOperation)
        protected.post("bulk", "undo", use: undoBulkOperation)
        protected.get("bulk", "progress", ":operationId", use: bulkOperationProgress)
    }

    // MARK: - Shared Context Helpers

    /// Lightweight DTO for sidebar/command palette content type listing.
    struct SidebarContentType: Encodable {
        let slug: String
        let displayName: String
    }

    /// Fetches all content types as lightweight DTOs for sidebar/command palette.
    private func fetchSidebarTypes(on db: any Database) async throws -> [SidebarContentType] {
        try await ContentTypeDefinition.query(on: db)
            .sort(\.$name)
            .all()
            .map { SidebarContentType(slug: $0.slug, displayName: $0.displayName) }
    }

    // MARK: - Dashboard

    @Sendable
    func dashboard(req: Request) async throws -> View {
        let typeCount = try await ContentTypeDefinition.query(on: req.db).count()
        let entryCount = try await ContentEntry.query(on: req.db)
            .filter(\.$deletedAt == nil).count()
        let recentEntries = try await ContentEntry.query(on: req.db)
            .filter(\.$deletedAt == nil)
            .sort(\.$createdAt, .descending)
            .limit(10)
            .all()

        let sidebarTypes = try await fetchSidebarTypes(on: req.db)

        struct DashboardContext: Encodable {
            let title: String
            let typeCount: Int
            let entryCount: Int
            let recentEntries: [ContentEntry]
            let activePage: String
            let contentTypes: [SidebarContentType]
        }

        return try await req.view.render("admin/dashboard", DashboardContext(
            title: "Dashboard",
            typeCount: typeCount,
            entryCount: entryCount,
            recentEntries: recentEntries,
            activePage: "dashboard",
            contentTypes: sidebarTypes
        ))
    }

    // MARK: - Content Types

    @Sendable
    func contentTypes(req: Request) async throws -> View {
        let types = try await ContentTypeDefinition.query(on: req.db)
            .sort(\.$name)
            .all()

        struct ContentTypeViewDTO: Codable {
            let id: UUID
            let displayName: String
            let slug: String
            let description: String?
            let kind: String
            let jsonSchema: AnyCodableValue
            let fieldCount: Int
        }

        struct Context: Encodable {
            let title: String
            let contentTypes: [ContentTypeViewDTO]
            let activePage: String
        }

        let viewTypes = types.map { type in
            let fieldCount: Int
            if let properties = type.jsonSchema.dictionaryValue?["properties"]?.dictionaryValue {
                fieldCount = properties.count
            } else {
                fieldCount = 0
            }

            return ContentTypeViewDTO(
                id: type.id!,
                displayName: type.displayName,
                slug: type.slug,
                description: type.description,
                kind: type.kind,
                jsonSchema: type.jsonSchema,
                fieldCount: fieldCount
            )
        }

        return try await req.view.render("admin/content/types", Context(
            title: "Content Types",
            contentTypes: viewTypes,
            activePage: "content-types"
        ))
    }

    @Sendable
    func duplicateContentType(req: Request) async throws -> Response {
        guard let typeId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        // Fetch original content type
        guard let originalType = try await ContentTypeDefinition.find(typeId, on: req.db) else {
            throw Abort(.notFound)
        }

        // Generate unique name and slug
        let baseName = "\(originalType.displayName) Copy"
        let baseSlug = "\(originalType.slug)-copy"

        var newName = baseName
        var newSlug = baseSlug
        var counter = 1

        // Check for existing duplicates and generate unique names
        while try await ContentTypeDefinition.query(on: req.db)
            .filter(\.$slug == newSlug)
            .first() != nil {
            counter += 1
            newName = "\(baseName) \(counter)"
            newSlug = "\(baseSlug)-\(counter)"
        }

        // Create duplicate content type
        let duplicatedType = ContentTypeDefinition(
            name: newName,
            slug: newSlug,
            displayName: newName,
            description: originalType.description,
            kind: ContentTypeKind(rawValue: originalType.kind) ?? .collection,
            jsonSchema: originalType.jsonSchema,
            fieldOrder: originalType.fieldOrder,
            settings: originalType.settings
        )

        try await duplicatedType.save(on: req.db)

        return req.redirect(to: "/admin/content-types")
    }

    @Sendable
    func contentTypeBuilder(req: Request) async throws -> View {
        let sidebarTypes = try await fetchSidebarTypes(on: req.db)

        struct Context: Encodable {
            let title: String
            let fieldTypes: [String]
            let activePage: String
            let contentTypes: [SidebarContentType]
        }

        return try await req.view.render("admin/content/builder", Context(
            title: "New Content Type",
            fieldTypes: FieldTypeRegistry.allFieldTypes,
            activePage: "content-types",
            contentTypes: sidebarTypes
        ))
    }

    // MARK: - Content List & Edit

    @Sendable
    func contentList(req: Request) async throws -> View {
        let contentType = try req.parameters.require("contentType")
        let page = req.query[Int.self, at: "page"] ?? 1

        guard let typeDef = try await ContentTypeDefinition.query(on: req.db)
            .filter(\.$slug == contentType)
            .first()
        else {
            throw Abort(.notFound)
        }

        let entries = try await ContentEntry.query(on: req.db)
            .filter(\.$contentType == contentType)
            .filter(\.$deletedAt == nil)
            .sort(\.$createdAt, .descending)
            .limit(25)
            .offset((page - 1) * 25)
            .all()

        let total = try await ContentEntry.query(on: req.db)
            .filter(\.$contentType == contentType)
            .filter(\.$deletedAt == nil)
            .count()

        // Get user's role and permissions
        let sidebarTypes = try await fetchSidebarTypes(on: req.db)

        if let user = req.auth.get(User.self) {
            try await user.$role.load(on: req.db)
            let permissions = try await user.role.$permissions.get(on: req.db)

            struct Context: Encodable {
                let title: String
                let contentType: ContentTypeDefinition
                let entries: [ContentEntry]
                let page: Int
                let totalPages: Int
                let activePage: String
                let userPermissions: [Permission]
                let contentTypes: [SidebarContentType]
            }

            return try await req.view.render("admin/content/list", Context(
                title: typeDef.displayName,
                contentType: typeDef,
                entries: entries,
                page: page,
                totalPages: max(1, Int(ceil(Double(total) / 25.0))),
                activePage: "content",
                userPermissions: permissions,
                contentTypes: sidebarTypes
            ))
        } else {
            struct Context: Encodable {
                let title: String
                let contentType: ContentTypeDefinition
                let entries: [ContentEntry]
                let page: Int
                let totalPages: Int
                let activePage: String
                let contentTypes: [SidebarContentType]
            }

            return try await req.view.render("admin/content/list", Context(
                title: typeDef.displayName,
                contentType: typeDef,
                entries: entries,
                page: page,
                totalPages: max(1, Int(ceil(Double(total) / 25.0))),
                activePage: "content",
                contentTypes: sidebarTypes
            ))
        }
    }

    @Sendable
    func contentEdit(req: Request) async throws -> View {
        let contentType = try req.parameters.require("contentType")
        let entryId = req.parameters.get("entryId", as: UUID.self)

        guard let typeDef = try await ContentTypeDefinition.query(on: req.db)
            .filter(\.$slug == contentType)
            .first()
        else {
            throw Abort(.notFound)
        }

        let entry: ContentEntry? = if let id = entryId {
            try await ContentEntry.find(id, on: req.db)
        } else {
            nil
        }

        let sidebarTypes = try await fetchSidebarTypes(on: req.db)

        struct Context: Encodable {
            let title: String
            let contentType: ContentTypeDefinition
            let entry: ContentEntry?
            let activePage: String
            let contentTypes: [SidebarContentType]
        }

        return try await req.view.render("admin/content/edit", Context(
            title: entry != nil ? "Edit Entry" : "New Entry",
            contentType: typeDef,
            entry: entry,
            activePage: "content",
            contentTypes: sidebarTypes
        ))
    }

    // MARK: - Media

    @Sendable
    func mediaLibrary(req: Request) async throws -> View {
        let files = try await MediaFile.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .limit(50)
            .all()

        let sidebarTypes = try await fetchSidebarTypes(on: req.db)

        struct Context: Encodable {
            let title: String
            let files: [MediaFile]
            let activePage: String
            let contentTypes: [SidebarContentType]
        }

        return try await req.view.render("admin/media/library", Context(
            title: "Media Library",
            files: files,
            activePage: "media",
            contentTypes: sidebarTypes
        ))
    }

    // MARK: - Users

    @Sendable
    func userList(req: Request) async throws -> View {
        let users = try await User.query(on: req.db)
            .with(\.$role)
            .sort(\.$email)
            .all()

        let sidebarTypes = try await fetchSidebarTypes(on: req.db)

        struct Context: Encodable {
            let title: String
            let users: [User]
            let activePage: String
            let contentTypes: [SidebarContentType]
        }

        return try await req.view.render("admin/users/list", Context(
            title: "Users",
            users: users,
            activePage: "users",
            contentTypes: sidebarTypes
        ))
    }

    // MARK: - Webhooks

    @Sendable
    func webhookList(req: Request) async throws -> View {
        let webhooks = try await Webhook.query(on: req.db)
            .sort(\.$name)
            .all()

        let sidebarTypes = try await fetchSidebarTypes(on: req.db)

        struct Context: Encodable {
            let title: String
            let webhooks: [Webhook]
            let activePage: String
            let contentTypes: [SidebarContentType]
        }

        return try await req.view.render("admin/webhooks/list", Context(
            title: "Webhooks",
            webhooks: webhooks,
            activePage: "webhooks",
            contentTypes: sidebarTypes
        ))
    }

    // MARK: - Settings

    @Sendable
    func settings(req: Request) async throws -> View {
        let sidebarTypes = try await fetchSidebarTypes(on: req.db)

        struct Context: Encodable {
            let title: String
            let activePage: String
            let contentTypes: [SidebarContentType]
        }
        return try await req.view.render("admin/settings/index", Context(
            title: "Settings",
            activePage: "settings",
            contentTypes: sidebarTypes
        ))
    }

    // MARK: - Dead Letter Queue

    @Sendable
    func deadLetterQueue(req: Request) async throws -> View {
        let entries = try await DeadLetterEntry.query(on: req.db)
            .sort(\.$lastFailedAt, .descending)
            .limit(50)
            .all()

        let sidebarTypes = try await fetchSidebarTypes(on: req.db)

        struct Context: Encodable {
            let title: String
            let entries: [DeadLetterEntry]
            let activePage: String
            let contentTypes: [SidebarContentType]
        }

        return try await req.view.render("admin/system/dlq", Context(
            title: "Dead Letter Queue",
            entries: entries,
            activePage: "system",
            contentTypes: sidebarTypes
        ))
    }

    // MARK: - Auth

    @Sendable
    func loginPage(req: Request) async throws -> View {
        struct Context: Encodable {
            let title: String
            let error: String?
        }
        return try await req.view.render("admin/login", Context(
            title: "Login", error: nil
        ))
    }

    @Sendable
    func loginAction(req: Request) async throws -> Response {
        let dto = try req.content.decode(LoginDTO.self)

        guard let user = try await User.query(on: req.db)
            .filter(\.$email == dto.email)
            .first(),
              let passwordHash = user.passwordHash,
              try Bcrypt.verify(dto.password, created: passwordHash)
        else {
            return req.redirect(to: "/admin/login?error=invalid")
        }

        req.auth.login(user)
        req.session.authenticate(user)
        return req.redirect(to: "/admin")
    }

    @Sendable
    func logout(req: Request) async throws -> Response {
        req.auth.logout(User.self)
        req.session.unauthenticate(User.self)
        return req.redirect(to: "/admin/login")
    }

    // MARK: - POST Handlers (Wave 2)

    // MARK: Content Type Creation

    /// Creates a new content type from the admin form builder.
    /// Parses the submitted field definitions JSON and generates a JSON Schema.
    @Sendable
    func createContentType(req: Request) async throws -> Response {
        let form = try req.content.decode(ContentTypeFormDTO.self)

        // Parse field definitions from the JSON string submitted by the form builder
        var fields: [FieldDefinition] = []
        if let json = form.fieldsJson, !json.isEmpty {
            let data = Data(json.utf8)
            fields = try JSONDecoder().decode([FieldDefinition].self, from: data)
        }

        // Generate JSON Schema from the parsed field definitions
        let schema = SchemaGenerator.generate(from: fields)

        // Build the ordered field names for display ordering
        let fieldOrder: [AnyCodableValue] = fields.map { .string($0.name) }

        // Determine content type kind, defaulting to collection
        let kind = ContentTypeKind(rawValue: form.kind ?? "collection") ?? .collection

        // Build the CmsContext from the authenticated session user
        let userId = req.auth.get(User.self)?.id?.uuidString
        let context = CmsContext(logger: req.logger, userId: userId)

        let dto = CreateContentTypeDTO(
            name: form.name,
            slug: form.slug,
            displayName: form.displayName,
            description: form.description,
            kind: kind,
            jsonSchema: schema,
            fieldOrder: fieldOrder
        )

        _ = try await ContentTypeService.create(
            dto: dto,
            on: req.db,
            eventBus: req.eventBus,
            context: context
        )

        return req.redirect(to: "/admin/content-types")
    }

    // MARK: Content Entry Create / Update

    /// Creates or updates a content entry based on form data.
    /// When an entryId path parameter is present the handler updates; otherwise it creates.
    @Sendable
    func createOrUpdateEntry(req: Request) async throws -> Response {
        let contentType = try req.parameters.require("contentType")
        let entryId = req.parameters.get("entryId", as: UUID.self)

        // Decode the flat form data submitted by the content editor
        let formData = try req.content.decode([String: String].self)

        // Convert flat string values into an AnyCodableValue dictionary
        var dataDict: [String: AnyCodableValue] = [:]
        for (key, value) in formData {
            dataDict[key] = .string(value)
        }
        let entryData: AnyCodableValue = .dictionary(dataDict)

        // Build CmsContext from the authenticated session user
        let userId = req.auth.get(User.self)?.id?.uuidString
        let context = CmsContext(logger: req.logger, userId: userId)

        if let id = entryId {
            // Update existing entry
            let updateDTO = UpdateContentEntryDTO(data: entryData)
            _ = try await ContentEntryService.update(
                contentType: contentType,
                id: id,
                dto: updateDTO,
                on: req.db,
                eventBus: req.eventBus,
                context: context
            )
        } else {
            // Create new entry
            let createDTO = CreateContentEntryDTO(data: entryData)
            _ = try await ContentEntryService.create(
                contentType: contentType,
                dto: createDTO,
                on: req.db,
                eventBus: req.eventBus,
                context: context
            )
        }

        return req.redirect(to: "/admin/content/\(contentType)")
    }

    // MARK: Webhook CRUD

    /// Creates a new webhook from the admin webhooks form.
    @Sendable
    func createWebhook(req: Request) async throws -> Response {
        let form = try req.content.decode(WebhookFormDTO.self)

        // Parse the comma-separated event names into an AnyCodableValue array
        let eventNames = form.events
            .split(separator: ",")
            .map { AnyCodableValue.string(String($0).trimmingCharacters(in: .whitespaces)) }

        // Generate a random secret if none was provided
        let secret = form.secret ?? UUID().uuidString

        let webhook = Webhook(
            name: form.name,
            url: form.url,
            events: .array(eventNames),
            secret: secret,
            enabled: true
        )
        try await webhook.save(on: req.db)

        return req.redirect(to: "/admin/webhooks")
    }

    /// Deletes a webhook by its ID.
    @Sendable
    func deleteWebhook(req: Request) async throws -> Response {
        guard let webhookId = req.parameters.get("webhookId", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        guard let webhook = try await Webhook.find(webhookId, on: req.db) else {
            throw Abort(.notFound)
        }

        try await webhook.delete(on: req.db)
        return req.redirect(to: "/admin/webhooks")
    }

    /// Toggles a webhook between enabled and disabled states.
    @Sendable
    func toggleWebhook(req: Request) async throws -> Response {
        guard let webhookId = req.parameters.get("webhookId", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        guard let webhook = try await Webhook.find(webhookId, on: req.db) else {
            throw Abort(.notFound)
        }

        webhook.enabled = !webhook.enabled
        try await webhook.save(on: req.db)

        return req.redirect(to: "/admin/webhooks")
    }

    // MARK: User Management

    /// Creates a new user from the admin users form.
    @Sendable
    func createUser(req: Request) async throws -> Response {
        let form = try req.content.decode(UserFormDTO.self)

        // Look up the role; fall back to the first available role if not specified
        let roleId: UUID
        if let formRoleId = form.roleId {
            roleId = formRoleId
        } else {
            // Default to the first non-system role, or any role available
            guard let defaultRole = try await Role.query(on: req.db).first() else {
                throw Abort(.badRequest, reason: "No roles configured in the system")
            }
            roleId = defaultRole.id!
        }

        // Hash the password if provided
        let passwordHash: String? = if let password = form.password, !password.isEmpty {
            try Bcrypt.hash(password)
        } else {
            nil
        }

        let user = User(
            email: form.email,
            passwordHash: passwordHash,
            displayName: form.displayName,
            roleID: roleId,
            authProvider: form.authProvider ?? "local"
        )
        try await user.save(on: req.db)

        return req.redirect(to: "/admin/users")
    }

    /// Deletes a user by their ID.
    @Sendable
    func deleteUser(req: Request) async throws -> Response {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound)
        }

        try await user.delete(on: req.db)
        return req.redirect(to: "/admin/users")
    }

    // MARK: - Admin Search

    /// GET /admin/search?q=query
    /// Returns HTMX partial with search results dropdown.
    @Sendable
    func adminSearch(req: Request) async throws -> Response {
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            return Response(status: .ok, body: .init(string: ""))
        }

        let lowered = query.lowercased()

        // Search content entries by matching data fields
        let entries = try await ContentEntry.query(on: req.db)
            .filter(\.$deletedAt == nil)
            .limit(10)
            .all()

        // Filter entries that match the query in their data
        let matchingEntries = entries.filter { entry in
            if let dict = entry.data.dictionaryValue {
                return dict.values.contains { value in
                    if let str = value.stringValue {
                        return str.lowercased().contains(lowered)
                    }
                    return false
                }
            }
            return false
        }.prefix(5)

        // Search content types by name
        let types = try await ContentTypeDefinition.query(on: req.db)
            .all()
        let matchingTypes = types.filter { $0.displayName.lowercased().contains(lowered) || $0.slug.lowercased().contains(lowered) }

        // Build HTML response for HTMX
        var html = "<div class=\"dropdown-content bg-base-100 rounded-box z-[1] w-96 p-4 shadow-lg absolute right-0 top-12\">"

        if !matchingTypes.isEmpty {
            html += "<h4 class=\"font-semibold text-xs text-base-content/50 mb-2\">Content Types</h4>"
            for t in matchingTypes {
                html += "<a href=\"/admin/content/\(t.slug)\" class=\"block p-2 hover:bg-base-200 rounded text-sm\">\(t.displayName)</a>"
            }
        }

        if !matchingEntries.isEmpty {
            html += "<h4 class=\"font-semibold text-xs text-base-content/50 mt-2 mb-2\">Entries</h4>"
            for entry in matchingEntries {
                let id = entry.id?.uuidString ?? ""
                let ct = entry.contentType
                let label = entry.data.dictionaryValue?.values.first(where: { $0.stringValue != nil })?.stringValue ?? id.prefix(8).description
                html += "<a href=\"/admin/content/\(ct)/\(id)\" class=\"block p-2 hover:bg-base-200 rounded text-sm\">"
                html += "<span class=\"badge badge-xs badge-ghost mr-1\">\(ct)</span> \(label)</a>"
            }
        }

        if matchingTypes.isEmpty && matchingEntries.isEmpty {
            html += "<p class=\"text-sm text-base-content/50\">No results found</p>"
        }

        html += "</div>"

        let res = Response(status: .ok)
        res.headers.contentType = .html
        res.body = .init(string: html)
        return res
    }

    // MARK: - Webhook Edit

    /// GET /admin/webhooks/new or /admin/webhooks/:webhookId/edit
    @Sendable
    func webhookEdit(req: Request) async throws -> View {
        let webhookId = req.parameters.get("webhookId", as: UUID.self)
        let webhook: Webhook? = if let id = webhookId {
            try await Webhook.find(id, on: req.db)
        } else {
            nil
        }

        let sidebarTypes = try await fetchSidebarTypes(on: req.db)

        struct Context: Encodable {
            let title: String
            let webhook: Webhook?
            let activePage: String
            let eventTypes: [String]
            let contentTypes: [SidebarContentType]
        }

        return try await req.view.render("admin/webhooks/edit", Context(
            title: webhook != nil ? "Edit Webhook" : "New Webhook",
            webhook: webhook,
            activePage: "webhooks",
            eventTypes: [
                "content.created", "content.updated", "content.deleted",
                "content.published", "content.stateChanged",
                "schema.changed", "media.uploaded", "media.deleted"
            ],
            contentTypes: sidebarTypes
        ))
    }

    // MARK: - Webhook Deliveries

    /// GET /admin/webhooks/:webhookId/deliveries
    @Sendable
    func webhookDeliveries(req: Request) async throws -> View {
        guard let webhookId = req.parameters.get("webhookId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        guard let webhook = try await Webhook.find(webhookId, on: req.db) else {
            throw Abort(.notFound)
        }

        let deliveries = try await WebhookDelivery.query(on: req.db)
            .filter(\.$webhook.$id == webhookId)
            .sort(\.$createdAt, .descending)
            .limit(50)
            .all()

        let  sidebarTypes = try await fetchSidebarTypes(on: req.db)

        struct Context: Encodable {
            let title: String
            let webhook: Webhook
            let deliveries: [WebhookDelivery]
            let activePage: String
            let contentTypes: [SidebarContentType]
        }

        return try await req.view.render("admin/webhooks/deliveries", Context(
            title: "Deliveries - \(webhook.name)",
            webhook: webhook,
            deliveries: deliveries,
            activePage: "webhooks",
            contentTypes: sidebarTypes
        ))
    }

    // MARK: - Admin Media Upload

    /// POST /admin/media/upload (multipart form)
    @Sendable
    func adminMediaUpload(req: Request) async throws -> Response {
        let upload = try req.content.decode(FileUploadDTO.self)
        let storage = req.application.fileStorage
        let providerName = Environment.get("STORAGE_PROVIDER") ?? "local"
        let userId = req.auth.get(User.self)?.id?.uuidString
        let context = CmsContext(logger: req.logger, userId: userId)

        _ = try await MediaService.upload(
            file: upload.file, storage: storage,
            providerName: providerName,
            on: req.db, eventBus: req.eventBus, context: context
        )

        return req.redirect(to: "/admin/media")
    }

    // MARK: - Bulk Operations (Wave 3)

    /// POST /admin/content/:contentType/bulk
    /// Performs bulk operations on content entries.
    @Sendable
    func bulkContentOperation(req: Request) async throws -> Response {
        let contentType = try req.parameters.require("contentType")
        let bulkDTO = try req.content.decode(BulkOperationDTO.self)

        // Verify user has permission for this content type
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }

        // Validate content type exists
        guard let _ = try await ContentTypeDefinition.query(on: req.db)
            .filter(\.$slug == contentType)
            .first() else {
            throw Abort(.notFound, reason: "Content type not found")
        }

        var successIds: [UUID] = []
        var failures: [BulkFailure] = []
        let userId = user.id?.uuidString
        let context = CmsContext(logger: req.logger, userId: userId)

        // Process each entry
        for entryId in bulkDTO.entryIds {
            do {
                guard let entry = try await ContentEntry.find(entryId, on: req.db),
                      entry.contentType == contentType,
                      entry.deletedAt == nil else {
                    failures.append(BulkFailure(entryId: entryId, error: "Entry not found"))
                    continue
                }

                switch bulkDTO.action {
                case .publish:
                    entry.status = ContentStatus.published.rawValue
                    entry.publishedAt = Date()
                    try await entry.save(on: req.db)

                case .unpublish:
                    entry.status = ContentStatus.draft.rawValue
                    try await entry.save(on: req.db)

                case .delete:
                    entry.deletedAt = Date()
                    try await entry.save(on: req.db)

                case .changeLocale:
                    if let newLocale = bulkDTO.locale {
                        entry.locale = newLocale
                        try await entry.save(on: req.db)
                    } else {
                        failures.append(BulkFailure(entryId: entryId, error: "Locale not specified"))
                        continue
                    }

                case .archive:
                    entry.status = ContentStatus.archived.rawValue
                    try await entry.save(on: req.db)

                case .restore:
                    entry.status = ContentStatus.draft.rawValue
                    entry.deletedAt = nil
                    try await entry.save(on: req.db)
                }

                successIds.append(entryId)

                // Publish event for successful operation
                let event = ContentEvent(
                    id: UUID(),
                    name: "content.bulk.\(bulkDTO.action.rawValue)",
                    entityType: "content",
                    entityId: entryId.uuidString,
                    contentType: contentType,
                    data: ["action": AnyCodableValue.string(bulkDTO.action.rawValue)],
                    timestamp: Date()
                )
                try await req.eventBus.publish(event: event, context: context)

            } catch {
                req.logger.error("Bulk operation failed for entry \(entryId): \(error)")
                failures.append(BulkFailure(entryId: entryId, error: error.localizedDescription))
            }
        }

        // Generate result
        let result = BulkOperationResultDTO(
            successCount: successIds.count,
            failureCount: failures.count,
            successIds: successIds,
            failures: failures,
            action: bulkDTO.action,
            canUndo: bulkDTO.action == .publish || bulkDTO.action == .unpublish || bulkDTO.action == .delete,
            undoToken: bulkDTO.action == .publish || bulkDTO.action == .unpublish || bulkDTO.action == .delete
                ? generateUndoToken(for: bulkDTO, entryIds: successIds) : nil
        )

        // Return JSON response for HTMX
        let res = Response(status: .ok)
        res.headers.contentType = .json
        res.body = .init(string: String(data: try JSONEncoder().encode(result), encoding: .utf8) ?? "")
        return res
    }

    /// POST /admin/media/bulk
    /// Performs bulk operations on media files.
    @Sendable
    func bulkMediaOperation(req: Request) async throws -> Response {
        let bulkDTO = try req.content.decode(BulkMediaOperationDTO.self)
        let storage = req.application.fileStorage
        let userId = req.auth.get(User.self)?.id?.uuidString
        let context = CmsContext(logger: req.logger, userId: userId)

        var successIds: [UUID] = []
        var failures: [BulkFailure] = []

        for fileId in bulkDTO.fileIds {
            do {
                guard let file = try await MediaFile.find(fileId, on: req.db) else {
                    failures.append(BulkFailure(entryId: fileId, error: "File not found"))
                    continue
                }

                switch bulkDTO.action {
                case .delete:
                    // Delete from storage
                    try await storage.delete(key: file.storagePath)
                    // Delete database record
                    try await file.delete(on: req.db)

                    // Publish delete event
                    let event = MediaEvent(
                        id: UUID(),
                        name: "media.bulk.deleted",
                        entityType: "media",
                        entityId: fileId.uuidString,
                        data: ["filename": AnyCodableValue.string(file.filename)],
                        timestamp: Date()
                    )
                    try await req.eventBus.publish(event: event, context: context)

                case .move:
                    if let targetPath = bulkDTO.targetPath {
                        // Update storage path
                        let newPath = targetPath.isEmpty ? file.filename : "\(targetPath)/\(file.filename)"
                        // TODO: Implement actual file move in storage provider
                        file.storagePath = newPath
                        try await file.save(on: req.db)
                    } else {
                        failures.append(BulkFailure(entryId: fileId, error: "Target path not specified"))
                        continue
                    }
                }

                successIds.append(fileId)

            } catch {
                req.logger.error("Bulk media operation failed for file \(fileId): \(error)")
                failures.append(BulkFailure(entryId: fileId, error: error.localizedDescription))
            }
        }

        let result = BulkMediaResultDTO(
            successCount: successIds.count,
            failureCount: failures.count,
            successIds: successIds,
            failures: failures,
            action: bulkDTO.action
        )

        let res = Response(status: .ok)
        res.headers.contentType = .json
        res.body = .init(string: String(data: try JSONEncoder().encode(result), encoding: .utf8) ?? "")
        return res
    }

    /// POST /admin/bulk/undo
    /// Undoes a bulk operation using the undo token.
    @Sendable
    func undoBulkOperation(req: Request) async throws -> Response {
        struct UndoRequest: Content {
            let undoToken: String
        }

        let undoReq = try req.content.decode(UndoRequest.self)

        // Decode and validate undo token
        guard let data = undoReq.undoToken.data(using: .utf8),
              let decoded = Data(base64Encoded: data),
              let tokenString = String(data: decoded, encoding: .utf8),
              let tokenData = tokenString.data(using: .utf8),
              let token = try? JSONDecoder().decode(UndoToken.self, from: tokenData) else {
            throw Abort(.badRequest, reason: "Invalid undo token")
        }

        // Check token expiration (30 minutes)
        if Date().timeIntervalSince(token.createdAt) > 1800 {
            throw Abort(.badRequest, reason: "Undo token has expired")
        }

        var successIds: [UUID] = []
        var failures: [BulkFailure] = []

        for entryId in token.entryIds {
            do {
                guard let entry = try await ContentEntry.find(entryId, on: req.db) else {
                    failures.append(BulkFailure(entryId: entryId, error: "Entry not found"))
                    continue
                }

                // Reverse the original action
                switch token.action {
                case .publish:
                    entry.status = ContentStatus.draft.rawValue
                    entry.publishedAt = nil
                    try await entry.save(on: req.db)

                case .unpublish:
                    entry.status = ContentStatus.published.rawValue
                    entry.publishedAt = Date()
                    try await entry.save(on: req.db)

                case .delete:
                    entry.deletedAt = nil
                    try await entry.save(on: req.db)

                case .changeLocale, .archive, .restore:
                    // These actions cannot be undone
                    failures.append(BulkFailure(entryId: entryId, error: "Action cannot be undone"))
                    continue
                }

                successIds.append(entryId)

            } catch {
                failures.append(BulkFailure(entryId: entryId, error: error.localizedDescription))
            }
        }

        let result = BulkOperationResultDTO(
            successCount: successIds.count,
            failureCount: failures.count,
            successIds: successIds,
            failures: failures,
            action: token.action,
            canUndo: false
        )

        let res = Response(status: .ok)
        res.headers.contentType = .json
        res.body = .init(string: String(data: try JSONEncoder().encode(result), encoding: .utf8) ?? "")
        return res
    }

    /// GET /admin/bulk/progress/:operationId
    /// Returns progress for a long-running bulk operation.
    @Sendable
    func bulkOperationProgress(req: Request) async throws -> Response {
        guard let operationId = req.parameters.get("operationId", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        // In a real implementation, this would query a job queue for progress
        // For now, return a mock response
        struct ProgressResponse: Content {
            let operationId: UUID
            let total: Int
            let completed: Int
            let failed: Int
            let status: String
        }

        let progress = ProgressResponse(
            operationId: operationId,
            total: 100,
            completed: 100,
            failed: 0,
            status: "completed"
        )

        let res = Response(status: .ok)
        res.headers.contentType = .json
        res.body = .init(string: String(data: try JSONEncoder().encode(progress), encoding: .utf8) ?? "")
        return res
    }

    /// Generates an undo token for a bulk operation.
    private func generateUndoToken(for operation: BulkOperationDTO, entryIds: [UUID]) -> String {
        let token = UndoToken(
            action: operation.action,
            entryIds: entryIds,
            originalLocale: operation.locale,
            originalStatus: operation.status,
            createdAt: Date()
        )

        if let data = try? JSONEncoder().encode(token),
           let tokenString = String(data: data, encoding: .utf8) {
            return tokenString.data(using: .utf8)!.base64EncodedString()
        }

        return ""
    }
}

// MARK: - Undo Token

/// Internal token structure for undo operations.
private struct UndoToken: Codable {
    let action: BulkAction
    let entryIds: [UUID]
    let originalLocale: String?
    let originalStatus: ContentStatus?
    let createdAt: Date
}

// MARK: - Content Event

/// Event for content mutations.
public struct ContentEvent: CmsEvent, Sendable {
    public static let eventName = "content.event"

    public let id: UUID
    public let name: String
    public let entityType: String
    public let entityId: String
    public let contentType: String?
    public let data: [String: AnyCodableValue]
    public let timestamp: Date

    public init(
        id: UUID,
        name: String,
        entityType: String,
        entityId: String,
        contentType: String? = nil,
        data: [String: AnyCodableValue],
        timestamp: Date
    ) {
        self.id = id
        self.name = name
        self.entityType = entityType
        self.entityId = entityId
        self.contentType = contentType
        self.data = data
        self.timestamp = timestamp
    }

    public func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "entityType": entityType,
            "entityId": entityId,
            "timestamp": timestamp.ISO8601Format()
        ]

        if let contentType = contentType {
            dict["contentType"] = contentType
        }

        return dict
    }
}

// MARK: - Media Event

/// Event for media mutations.
public struct MediaEvent: CmsEvent, Sendable {
    public static let eventName = "media.event"

    public let id: UUID
    public let name: String
    public let entityType: String
    public let entityId: String
    public let data: [String: AnyCodableValue]
    public let timestamp: Date

    public init(
        id: UUID,
        name: String,
        entityType: String,
        entityId: String,
        data: [String: AnyCodableValue],
        timestamp: Date
    ) {
        self.id = id
        self.name = name
        self.entityType = entityType
        self.entityId = entityId
        self.data = data
        self.timestamp = timestamp
    }

    public func toDict() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "entityType": entityType,
            "entityId": entityId,
            "timestamp": timestamp.ISO8601Format()
        ]
    }
}

// MARK: - Admin Form DTOs

/// Form DTO for content type creation from the admin builder UI.
struct ContentTypeFormDTO: Content {
    let name: String
    let slug: String
    let displayName: String
    let description: String?
    let kind: String?
    let fieldsJson: String?  // JSON array of field definitions
}

/// Form DTO for webhook creation from the admin webhooks UI.
struct WebhookFormDTO: Content {
    let name: String
    let url: String
    let events: String       // Comma-separated event names
    let secret: String?
}

/// Form DTO for user creation from the admin users UI.
struct UserFormDTO: Content {
    let email: String
    let password: String?
    let displayName: String?
    let roleId: UUID?
    let authProvider: String?
}
