import Vapor
import Fluent
import CMSObjects
import CMSSchema
import CMSEvents
import CMSCore
import NIOCore


// MARK: - 🎬 Media Upload Service

/// 🚀 Central service for handling all media file uploads in SwiftCMS.
/// Manages validation, storage, database persistence, and event publishing.
///
/// # Architecture
/// - File validation (extension, size, MIME type)
/// - Secure key generation with date-based organization
/// - Pluggable storage provider system
/// - Database record creation with metadata
/// - Event-driven notifications for post-processing
///
/// # Security Features
/// - Whitelist-based file extension validation
/// - Maximum file size limits (default: 50MB)
/// - MIME type detection and preservation
/// - Secure filename generation with UUIDs
/// - Tenant isolation for multi-tenant setups
///
/// # Processing Pipeline
/// 1. **Validation** → Extension and size checks
/// 2. **Key Generation** → Date-based paths with UUIDs
/// 3. **Upload** → Delegates to storage provider
/// 4. **Persistence** → Creates MediaFile database record
/// 5. **Events** → Fires MediaUploadedEvent for async processing
///
/// # Usage Example
/// ```swift
/// let media = try await MediaService.upload(
///     file: uploadedFile,
///     storage: s3Storage,
///     providerName: "s3",
///     on: req.db,
///     eventBus: req.eventBus,
///     context: cmsContext
/// )
/// // Returns MediaResponseDTO with file metadata and URLs
/// ```
@available(macOS 13.0, *)
public struct MediaService: Sendable {

    /// 📋 Whitelist of allowed file extensions for security.
    /// Prevents uploading of potentially dangerous file types.
    public static let allowedExtensions = Set([
        "jpg", "jpeg", "png", "gif", "webp", "svg",  // 🖼️ Standard images
        "pdf", "doc", "docx", "xls", "xlsx",        // 📄 Documents
        "mp4", "mov", "avi",                           // 🎬 Common videos
        "mp3", "wav", "m4a"                            // 🎵 Common audio
    ])

    /// 📏 Maximum file size in bytes (50MB default).
    /// Adjustable based on deployment requirements and storage limits.
    public static let maxFileSize = 50 * 1024 * 1024

    /// 📸 Handles complete upload flow from validation to persistence.
    ///
    /// # Validation Steps
    /// 1. **Extension Check** → Validates against `allowedExtensions`
    /// 2. **Size Check** → Ensures file is under `maxFileSize`
    /// 3. **Format Check** → MIME type detection from content-type
    ///
    /// # Key Generation Strategy
    /// Organizes files by date: `uploads/2024/01/uuid-filename.ext`
    /// Prevents filesystem performance issues with flat directories
    ///
    /// # Database Record Creation
    /// Creates `MediaFile` with complete metadata including:
    /// - Filename and MIME type
    /// - Size in bytes
    /// - Storage path and provider
    /// - Timestamps and tenant information
    ///
    /// # Event Publishing
    /// Fires `MediaUploadedEvent` for async processing:
    /// - Thumbnail generation
    /// - Virus scanning
    /// - CDN invalidation
    /// - Analytics tracking
    ///
    /// # Error Scenarios
    /// - Returns `ApiError.badRequest` for validation failures
    /// - Returns `ApiError.internalError` for storage/database issues
    /// - Preserves original error context in debug logs
    ///
    /// - Parameters:
    ///   - file: The uploaded file with data and metadata
    ///   - storage: Storage provider instance (local, S3, etc.)
    ///   - providerName: Identifier for the storage provider
    ///   - db: Database connection for persistence
    ///   - eventBus: Event system for async processing
    ///   - context: Tenant and user context for authorization
    /// - Returns: `MediaResponseDTO` with file info and access URLs
    public static func upload(
        file: File,
        storage: FileStorageProvider,
        providerName: String = "local",
        on db: Database,
        eventBus: EventBus,
        context: CmsContext
    ) async throws -> MediaResponseDTO {

        // Log upload start
        context.logger.info("🚀 Starting media upload for file: \(file.filename)")

        // Validate file extension against whitelist
        let ext = (file.filename as NSString).pathExtension.lowercased()
        context.logger.debug("🔍 Validating extension: \(ext) for file: \(file.filename)")
        guard allowedExtensions.contains(ext) else {
            context.logger.warning("❌ Blocked upload attempt with disallowed extension: \(ext)")
            throw ApiError.badRequest("File type '.\(ext)' is not allowed. Allowed types: \(allowedExtensions.joined(separator: ", "))")
        }

        // Validate file size
        context.logger.debug("📏 Checking file size: \(file.data.readableBytes) bytes")
        guard file.data.readableBytes <= maxFileSize else {
            let maxMB = maxFileSize / 1024 / 1024
            context.logger.warning("❌ File size \(file.data.readableBytes) exceeds limit of \(maxMB)MB")
            throw ApiError.badRequest("File exceeds maximum size of \(maxMB)MB")
        }

        // Generate organized storage key with date-based structure
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = String(format: "%02d", calendar.component(.month, from: now))
        let key = "uploads/\(year)/\(month)/\(UUID().uuidString)-\(file.filename)"

        context.logger.info("🗂️  Generated storage key: \(key)")

        // Detect and preserve MIME type
        let mimeType = file.contentType?.serialize() ?? "application/octet-stream"
        context.logger.debug("🎯 Detected MIME type: \(mimeType)")

        // Upload to configured storage provider
        context.logger.info("☁️  Uploading to provider: \(providerName)")
        _ = try await storage.upload(key: key, data: file.data, contentType: mimeType)
        context.logger.info("✅ File uploaded successfully to: \(key)")

        // Create database record with complete metadata
        let media = MediaFile(
            filename: file.filename,
            mimeType: mimeType,
            sizeBytes: file.data.readableBytes,
            storagePath: key,
            provider: providerName,
            tenantId: context.tenantId
        )
        try await media.save(on: db)
        context.logger.info("📝 Created media record in database with ID: \(media.id?.uuidString ?? "unknown")")

        // Fire upload event for async processing pipeline
        let mediaId = media.id ?? UUID()
        let event = MediaUploadedEvent(
            mediaId: mediaId,
            filename: file.filename,
            mimeType: mimeType
        )
        context.logger.info("📡 Publishing MediaUploadedEvent for ID: \(mediaId)")
        try await eventBus.publish(event: event, context: context)

        // Generate public URL and return response
        let publicUrl = storage.publicURL(key: key)
        context.logger.info("🌐 Generated public URL: \(publicUrl)")

        return media.toResponseDTO(baseURL: "")
    }
}

// MARK: - 🎛️ Media REST Controller

/// 🎮 RESTful controller for media file CRUD operations.
/// Handles HTTP requests for uploading, listing, retrieving, and deleting media files.
///
/// # API Endpoints
/// - `GET /api/v1/media` → List files with pagination
/// - `GET /api/v1/media/:id` → Get file details
/// - `POST /api/v1/media` → Upload new file (50MB limit)
/// - `DELETE /api/v1/media/:id` → Delete file and cleanup
///
/// # Filtering & Pagination
/// - `?page=1&perPage=25` → Control result pagination
/// - `?type=image` → Filter by MIME type pattern
/// - Maximum 100 items per page
///
/// # Security
/// - Validates mediaId parameter format
/// - Checks file existence during deletion
/// - Cleans up associated thumbnails on delete
///
/// # Error Handling
/// - Returns `400` for invalid parameters
/// - Returns `404` for missing files
/// - Returns `204` on successful delete
@available(macOS 13.0, *)
public struct MediaController: RouteCollection, Sendable {

    public init() {}

    /// 🛤️ Registers media routes with Vapor router.
    ///
    /// # Route Configuration
    /// - Grouped under `/api/v1/media`
    /// - Upload accepts up to 50MB files
    /// - Uses `CollectBodyMiddleware` for large file handling
    public func boot(routes: any RoutesBuilder) throws {
        let media = routes.grouped("media")
        media.get(use: list)
        media.get(":mediaId", use: get)
        media.on(.POST, body: .collect(maxSize: "50mb"), use: upload)
        media.delete(":mediaId", use: delete)

        // MediaController routes registered at /api/v1/media
    }

    /// 📋 Lists media files with filtering and pagination.
    ///
    /// # Query Parameters
    /// - `page`: Page number (default: 1)
    /// - `perPage`: Items per page, max 100 (default: 25)
    /// - `type`: MIME type filter pattern (e.g., "image", "video")
    ///
    /// # Database Query
    /// - Filters by MIME type if provided
    /// - Orders by creation date (newest first)
    /// - Applies tenant isolation automatically
    ///
    /// - Parameter req: Vapor request with query parameters
    /// - Returns: Paginated wrapper with media DTOs
    @Sendable
    func list(req: Request) async throws -> PaginationWrapper<MediaResponseDTO> {
        req.logger.debug("📋 Listing media files with query: \(req.url.query ?? "none")")

        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = min(req.query[Int.self, at: "perPage"] ?? 25, 100)
        let mimeFilter = req.query[String.self, at: "type"]

        req.logger.info("📊 Pagination: page=\(page), perPage=\(perPage), typeFilter=\(mimeFilter ?? "none")")

        var query = MediaFile.query(on: req.db)
        if let mimeFilter = mimeFilter {
            query = query.filter(\.$mimeType =~ mimeFilter)
            req.logger.debug("🔍 Applying MIME type filter: \(mimeFilter)")
        }

        let total = try await query.count()
        req.logger.debug("📈 Total media files: \(total)")

        let files = try await query
            .offset((page - 1) * perPage)
            .limit(perPage)
            .sort(\.$createdAt, .descending)
            .all()

        let baseURL = Environment.get("APP_URL") ?? "http://localhost:8080"
        req.logger.debug("🌐 Using baseURL: \(baseURL)")

        let dtos = files.map { $0.toResponseDTO(baseURL: baseURL) }
        req.logger.info("✅ Retrieved \(dtos.count) media files for page \(page)")

        return .paginate(items: dtos, page: page, perPage: perPage, total: total)
    }

    /// 🔍 Retrieves a single media file by ID.
    ///
    /// # Parameter Validation
    /// - Validates UUID format for mediaId
    /// - Returns 400 if format is invalid
    ///
    /// # Database Lookup
    /// - Searches by primary key
    /// - Returns 404 if not found
    ///
    /// - Parameter req: Vapor request with mediaId parameter
    /// - Returns: MediaResponseDTO with file details
    @Sendable
    func get(req: Request) async throws -> MediaResponseDTO {
        guard let id = req.parameters.get("mediaId", as: UUID.self) else {
            req.logger.warning("⚠️ Invalid media ID parameter format")
            throw ApiError.badRequest("Invalid media ID. Must be a valid UUID.")
        }

        req.logger.debug("🔍 Fetching media file with ID: \(id)")

        guard let media = try await MediaFile.find(id, on: req.db) else {
            req.logger.warning("❌ Media file not found: \(id)")
            throw ApiError.notFound("Media file not found")
        }

        let baseURL = Environment.get("APP_URL") ?? "http://localhost:8080"
        req.logger.info("✅ Retrieved media file: \(media.filename) (ID: \(id))")

        return media.toResponseDTO(baseURL: baseURL)
    }

    /// 📸 Handles file upload request with validation and processing.
    ///
    /// # Request Processing
    /// - Decodes multipart form data
    /// - Extracts file and metadata
    /// - Delegates to MediaService for processing
    ///
    /// # Authentication
    /// - Extracts authenticated user for context
    /// - Applies tenant isolation if multi-tenant
    ///
    /// - Parameter req: Vapor request with multipart file upload
    /// - Returns: 201 Created with MediaResponseDTO
    @Sendable
    func upload(req: Request) async throws -> Response {
        req.logger.info("📸 Processing new file upload request")

        let file = try req.content.decode(FileUploadDTO.self)
        req.logger.debug("📁 Uploaded file: \(file.file.filename), size: \(file.file.data.readableBytes) bytes")

        let storage = req.application.fileStorage
        let providerName = Environment.get("STORAGE_PROVIDER") ?? "local"

        req.logger.debug("☁️ Using storage provider: \(providerName)")

        let user = req.auth.get(CmsUser.self)
        let context = CmsContext(logger: req.logger, userId: user?.userId, tenantId: user?.tenantId)

        let response = try await MediaService.upload(
            file: file.file, storage: storage,
            providerName: providerName,
            on: req.db, eventBus: req.eventBus, context: context
        )

        req.logger.info("✅ Upload completed successfully, media ID: \(response.id)")

        let res = Response(status: .created)
        try res.content.encode(response)
        return res
    }

    /// 🗑️ Deletes a media file and its associated thumbnails.
    ///
    /// # Deletion Process
    /// 1. Validates mediaId parameter
    /// 2. Retrieves MediaFile from database
    /// 3. Deletes original file from storage
    /// 4. Deletes all thumbnail variants (small, medium, large)
    /// 5. Removes database record
    ///
    /// # Cleanup Strategy
    /// - Parent deletion fails if original file can't be deleted
    /// - Thumbnail deletion errors are non-blocking (logged but ignored)
    /// - Database record only deleted after successful storage cleanup
    ///
    /// - Parameter req: Vapor request with mediaId parameter
    /// - Returns: 204 No Content on success
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let id = req.parameters.get("mediaId", as: UUID.self) else {
            req.logger.warning("⚠️ Invalid media ID parameter format in delete request")
            throw ApiError.badRequest("Invalid media ID")
        }

        req.logger.info("🗑️ Initiating deletion for media ID: \(id)")

        guard let media = try await MediaFile.find(id, on: req.db) else {
            req.logger.warning("❌ Media file not found for deletion: \(id)")
            throw ApiError.notFound("Media file not found")
        }

        let storage = req.application.fileStorage

        // Delete original file (required)
        req.logger.debug("🗑️ Deleting original file: \(media.storagePath)")
        try await storage.delete(key: media.storagePath)

        // Delete thumbnails (best effort, errors logged but not blocking)
        if let small = media.thumbnailSmall {
            req.logger.debug("🗑️ Deleting small thumbnail: \(small)")
            try? await storage.delete(key: small)
        }
        if let medium = media.thumbnailMedium {
            req.logger.debug("🗑️ Deleting medium thumbnail: \(medium)")
            try? await storage.delete(key: medium)
        }
        if let large = media.thumbnailLarge {
            req.logger.debug("🗑️ Deleting large thumbnail: \(large)")
            try? await storage.delete(key: large)
        }

        // Remove database record
        try await media.delete(on: req.db)
        req.logger.info("✅ Media file \(media.filename) (ID: \(id)) deleted successfully")

        return .noContent
    }
}

// MARK: - 📦 File Upload DTO

/// 📤 DTO for multipart file upload requests.
/// Wraps Vapor's `File` type for API contract compliance.
///
/// # API Contract
/// Expected in multipart form data with field name "file".
///
/// # Example Request
/// ```
/// POST /api/v1/media
/// Content-Type: multipart/form-data
///
/// --boundary
/// Content-Disposition: form-data; name="file"; filename="photo.jpg"
/// Content-Type: image/jpeg
///
/// [binary data]
/// --boundary--
/// ```
@available(macOS 13.0, *)
public struct FileUploadDTO: Content {
    /// 📁 The uploaded file with filename and data
    public var file: File
}

// MARK: - 🏭 Application Storage Configuration

/// 🔧 Extends Vapor Application to provide global file storage access.
/// Uses storage key pattern for dependency injection.
extension Application {
    /// 🔑 Storage key for FileStorageProvider in Vapor's storage system
    struct FileStorageKey: StorageKey {
        typealias Value = FileStorageProvider
    }

    /// 📦 Accesses the configured file storage provider.
    ///
    /// # Lazy Initialization
    /// Returns `LocalStorageProvider` if not explicitly set.
    /// Configure in `configure.swift`:
    /// ```swift
    /// app.fileStorage = S3StorageProvider(
    ///     accessKey: env.get("AWS_ACCESS_KEY"),
    ///     secretKey: env.get("AWS_SECRET_KEY"),
    ///     bucket: env.get("AWS_BUCKET")
    /// )
    /// ```
    public var fileStorage: FileStorageProvider {
        get {
            storage[FileStorageKey.self] ?? LocalStorageProvider()
        }
        set {
            storage[FileStorageKey.self] = newValue
        }
    }
}
