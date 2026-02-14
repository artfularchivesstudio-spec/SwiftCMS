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

        struct DashboardContext: Encodable {
            let title: String
            let typeCount: Int
            let entryCount: Int
            let recentEntries: [ContentEntry]
            let activePage: String
        }

        return try await req.view.render("admin/dashboard", DashboardContext(
            title: "Dashboard",
            typeCount: typeCount,
            entryCount: entryCount,
            recentEntries: recentEntries,
            activePage: "dashboard"
        ))
    }

    // MARK: - Content Types

    @Sendable
    func contentTypes(req: Request) async throws -> View {
        let types = try await ContentTypeDefinition.query(on: req.db)
            .sort(\.$name)
            .all()

        struct Context: Encodable {
            let title: String
            let contentTypes: [ContentTypeDefinition]
            let activePage: String
        }

        return try await req.view.render("admin/content/types", Context(
            title: "Content Types",
            contentTypes: types,
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
        struct Context: Encodable {
            let title: String
            let fieldTypes: [String]
            let activePage: String
        }

        return try await req.view.render("admin/content/builder", Context(
            title: "New Content Type",
            fieldTypes: FieldTypeRegistry.allFieldTypes,
            activePage: "content-types"
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
            }

            return try await req.view.render("admin/content/list", Context(
                title: typeDef.displayName,
                contentType: typeDef,
                entries: entries,
                page: page,
                totalPages: max(1, Int(ceil(Double(total) / 25.0))),
                activePage: "content",
                userPermissions: permissions
            ))
        } else {
            struct Context: Encodable {
                let title: String
                let contentType: ContentTypeDefinition
                let entries: [ContentEntry]
                let page: Int
                let totalPages: Int
                let activePage: String
            }

            return try await req.view.render("admin/content/list", Context(
                title: typeDef.displayName,
                contentType: typeDef,
                entries: entries,
                page: page,
                totalPages: max(1, Int(ceil(Double(total) / 25.0))),
                activePage: "content"
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

        struct Context: Encodable {
            let title: String
            let contentType: ContentTypeDefinition
            let entry: ContentEntry?
            let activePage: String
        }

        return try await req.view.render("admin/content/edit", Context(
            title: entry != nil ? "Edit Entry" : "New Entry",
            contentType: typeDef,
            entry: entry,
            activePage: "content"
        ))
    }

    // MARK: - Media

    @Sendable
    func mediaLibrary(req: Request) async throws -> View {
        let files = try await MediaFile.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .limit(50)
            .all()

        struct Context: Encodable {
            let title: String
            let files: [MediaFile]
            let activePage: String
        }

        return try await req.view.render("admin/media/library", Context(
            title: "Media Library",
            files: files,
            activePage: "media"
        ))
    }

    // MARK: - Users

    @Sendable
    func userList(req: Request) async throws -> View {
        let users = try await User.query(on: req.db)
            .with(\.$role)
            .sort(\.$email)
            .all()

        struct Context: Encodable {
            let title: String
            let users: [User]
            let activePage: String
        }

        return try await req.view.render("admin/users/list", Context(
            title: "Users",
            users: users,
            activePage: "users"
        ))
    }

    // MARK: - Webhooks

    @Sendable
    func webhookList(req: Request) async throws -> View {
        let webhooks = try await Webhook.query(on: req.db)
            .sort(\.$name)
            .all()

        struct Context: Encodable {
            let title: String
            let webhooks: [Webhook]
            let activePage: String
        }

        return try await req.view.render("admin/webhooks/list", Context(
            title: "Webhooks",
            webhooks: webhooks,
            activePage: "webhooks"
        ))
    }

    // MARK: - Settings

    @Sendable
    func settings(req: Request) async throws -> View {
        struct Context: Encodable {
            let title: String
            let activePage: String
        }
        return try await req.view.render("admin/settings/index", Context(
            title: "Settings",
            activePage: "settings"
        ))
    }

    // MARK: - Dead Letter Queue

    @Sendable
    func deadLetterQueue(req: Request) async throws -> View {
        let entries = try await DeadLetterEntry.query(on: req.db)
            .sort(\.$lastFailedAt, .descending)
            .limit(50)
            .all()

        struct Context: Encodable {
            let title: String
            let entries: [DeadLetterEntry]
            let activePage: String
        }

        return try await req.view.render("admin/system/dlq", Context(
            title: "Dead Letter Queue",
            entries: entries,
            activePage: "system"
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

        struct Context: Encodable {
            let title: String
            let webhook: Webhook?
            let activePage: String
            let eventTypes: [String]
        }

        return try await req.view.render("admin/webhooks/edit", Context(
            title: webhook != nil ? "Edit Webhook" : "New Webhook",
            webhook: webhook,
            activePage: "webhooks",
            eventTypes: [
                "content.created", "content.updated", "content.deleted",
                "content.published", "content.stateChanged",
                "schema.changed", "media.uploaded", "media.deleted"
            ]
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

        struct Context: Encodable {
            let title: String
            let webhook: Webhook
            let deliveries: [WebhookDelivery]
            let activePage: String
        }

        return try await req.view.render("admin/webhooks/deliveries", Context(
            title: "Deliveries - \(webhook.name)",
            webhook: webhook,
            deliveries: deliveries,
            activePage: "webhooks"
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
