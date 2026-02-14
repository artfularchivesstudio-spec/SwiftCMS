import Vapor
import Fluent
import CMSObjects
import CMSSchema
import CMSEvents
import NIOCore

// MARK: - FileStorageProvider Protocol

/// Protocol for file storage backends.
public protocol FileStorageProvider: Sendable {
    func upload(key: String, data: ByteBuffer, contentType: String) async throws -> String
    func download(key: String) async throws -> ByteBuffer
    func delete(key: String) async throws
    func publicURL(key: String) -> String
}

// MARK: - Local Storage Provider

/// Stores files in the local filesystem.
public struct LocalStorageProvider: FileStorageProvider, Sendable {
    let basePath: String
    let baseURL: String

    public init(basePath: String = "Public/uploads", baseURL: String = "/uploads") {
        self.basePath = basePath
        self.baseURL = baseURL
    }

    public func upload(key: String, data: ByteBuffer, contentType: String) async throws -> String {
        let filePath = "\(basePath)/\(key)"
        let dir = (filePath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        guard let bytes = data.getBytes(at: 0, length: data.readableBytes) else {
            throw ApiError.internalError("Failed to read upload data")
        }
        try Data(bytes).write(to: URL(fileURLWithPath: filePath))
        return key
    }

    public func download(key: String) async throws -> ByteBuffer {
        let filePath = "\(basePath)/\(key)"
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        return buffer
    }

    public func delete(key: String) async throws {
        let filePath = "\(basePath)/\(key)"
        try FileManager.default.removeItem(atPath: filePath)
    }

    public func publicURL(key: String) -> String {
        "\(baseURL)/\(key)"
    }
}

// MARK: - Media Service

/// Service for managing media file uploads.
public struct MediaService: Sendable {

    /// Allowed file extensions.
    public static let allowedExtensions = Set([
        "jpg", "jpeg", "png", "gif", "webp", "svg",
        "pdf", "mp4", "mp3", "doc", "docx", "xls", "xlsx"
    ])

    /// Maximum file size (50MB default).
    public static let maxFileSize = 50 * 1024 * 1024

    /// Upload a media file.
    public static func upload(
        file: File,
        storage: FileStorageProvider,
        providerName: String = "local",
        on db: Database,
        eventBus: EventBus,
        context: CmsContext
    ) async throws -> MediaResponseDTO {
        // Validate extension
        let ext = (file.filename as NSString).pathExtension.lowercased()
        guard allowedExtensions.contains(ext) else {
            throw ApiError.badRequest("File type '.\(ext)' is not allowed")
        }

        // Validate size
        guard file.data.readableBytes <= maxFileSize else {
            throw ApiError.badRequest("File exceeds maximum size of \(maxFileSize / 1024 / 1024)MB")
        }

        // Generate storage key
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = String(format: "%02d", calendar.component(.month, from: now))
        let key = "uploads/\(year)/\(month)/\(UUID().uuidString)-\(file.filename)"

        // Determine MIME type
        let mimeType = file.contentType?.serialize() ?? "application/octet-stream"

        // Upload to storage
        _ = try await storage.upload(key: key, data: file.data, contentType: mimeType)

        // Create database record
        let media = MediaFile(
            filename: file.filename,
            mimeType: mimeType,
            sizeBytes: file.data.readableBytes,
            storagePath: key,
            provider: providerName,
            tenantId: context.tenantId
        )
        try await media.save(on: db)

        // Fire event
        let event = MediaUploadedEvent(
            mediaId: media.id ?? UUID(),
            filename: file.filename,
            mimeType: mimeType
        )
        try await eventBus.publish(event: event, context: context)

        let url = storage.publicURL(key: key)
        return media.toResponseDTO(baseURL: "")
    }
}

// MARK: - Media Controller

/// Controller for media file operations.
/// Routes: /api/v1/media
public struct MediaController: RouteCollection {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let media = routes.grouped("media")
        media.get(use: list)
        media.get(":mediaId", use: get)
        media.on(.POST, body: .collect(maxSize: "50mb"), use: upload)
        media.delete(":mediaId", use: delete)
    }

    @Sendable
    func list(req: Request) async throws -> PaginationWrapper<MediaResponseDTO> {
        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = min(req.query[Int.self, at: "perPage"] ?? 25, 100)
        let mimeFilter = req.query[String.self, at: "type"]

        var query = MediaFile.query(on: req.db)
        if let mimeFilter = mimeFilter {
            query = query.filter(\.$mimeType =~ mimeFilter)
        }

        let total = try await query.count()
        let files = try await query
            .offset((page - 1) * perPage)
            .limit(perPage)
            .sort(\.$createdAt, .descending)
            .all()

        let baseURL = Environment.get("APP_URL") ?? "http://localhost:8080"
        let dtos = files.map { $0.toResponseDTO(baseURL: baseURL) }
        return .paginate(items: dtos, page: page, perPage: perPage, total: total)
    }

    @Sendable
    func get(req: Request) async throws -> MediaResponseDTO {
        guard let id = req.parameters.get("mediaId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid media ID")
        }
        guard let media = try await MediaFile.find(id, on: req.db) else {
            throw ApiError.notFound("Media file not found")
        }
        let baseURL = Environment.get("APP_URL") ?? "http://localhost:8080"
        return media.toResponseDTO(baseURL: baseURL)
    }

    @Sendable
    func upload(req: Request) async throws -> Response {
        let file = try req.content.decode(FileUploadDTO.self)
        let storage = req.application.fileStorage
        let providerName = Environment.get("STORAGE_PROVIDER") ?? "local"
        let user = req.auth.get(CmsUser.self)
        let context = CmsContext(logger: req.logger, userId: user?.userId, tenantId: user?.tenantId)

        let response = try await MediaService.upload(
            file: file.file, storage: storage,
            providerName: providerName,
            on: req.db, eventBus: req.eventBus, context: context
        )

        let res = Response(status: .created)
        try res.content.encode(response)
        return res
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let id = req.parameters.get("mediaId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid media ID")
        }
        guard let media = try await MediaFile.find(id, on: req.db) else {
            throw ApiError.notFound("Media file not found")
        }

        let storage = req.application.fileStorage
        try await storage.delete(key: media.storagePath)
        try await media.delete(on: req.db)

        return .noContent
    }
}

/// DTO for file uploads.
struct FileUploadDTO: Content {
    var file: File
}

// MARK: - Application Storage

extension Application {
    struct FileStorageKey: StorageKey {
        typealias Value = FileStorageProvider
    }

    public var fileStorage: FileStorageProvider {
        get {
            storage[FileStorageKey.self] ?? LocalStorageProvider()
        }
        set {
            storage[FileStorageKey.self] = newValue
        }
    }
}
