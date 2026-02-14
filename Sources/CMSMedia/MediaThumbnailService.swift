import Vapor
import CMSCore
import CMSEvents

// MARK: - 🎬 Media Thumbnail Service

/// 🖼️ Service for managing automatic thumbnail generation for uploaded media files.
///
/// # Purpose
/// This service acts as a stub/wrapper to avoid circular dependencies between modules.
/// The actual thumbnail generation logic has been moved to CMSJobs module.
///
/// # Architecture Decision
/// Moving thumbnail processing to CMSJobs module resolves the dependency cycle:
/// - CMSMedia needs to reference event handlers
/// - CMSEvents needs to reference media types
/// - CMSJobs can depend on both without creating cycles
///
/// # Flow
/// 1. Media upload → MediaUploadedEvent fired
/// 2. Event picked up by CMSJobs subscriber
/// 3. Thumbnailing job queued and processed asynchronously
/// 4. Results saved to MediaFile record
///
/// # Related Files
/// - `/Sources/CMSJobs/MediaThumbnailSubscriber.swift` (actual implementation)
/// - `/Sources/CMSEvents/MediaUploadedEvent.swift` (trigger event)
/// - `/Sources/CMSObjects/ThumbnailSize.swift` (size definitions)
///
/// # Deprecation Notice
/// This service is deprecated. Use `CMSJobs/MediaThumbnailSubscriber` instead.
@available(macOS 13.0, *)
public struct MediaThumbnailService: Sendable {

    /// 🏗️ Creates a new thumbnail service instance.
    public init() {
        print("🖼️ MediaThumbnailService initialized (deprecated - use CMSJobs)")
    }

    /// ⚠️ Deprecated configuration method.
    ///
    /// # Historical Context
    /// Previously this method set up event subscriptions for automatic thumbnailing
    /// after media uploads. It has been replaced by a job-based architecture.
    ///
    /// # Migration Guide
    /// Instead of calling this method during boot:
    /// ```swift
    /// // ❌ Deprecated approach
    /// MediaThumbnailService.configure(app: app)
    ///
    /// // ✅ New approach in CMSJobs/boot.swift
    /// app.eventBus.subscribe(
    ///     type: MediaUploadedEvent.self,
    ///     handler: MediaThumbnailSubscriber()
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - app: Vapor application instance
    @available(*, deprecated, message: "Use CMSJobs module instead - see MediaThumbnailSubscriber")
    public static func configure(app: Application) {
        // Deprecated: Implementation moved to CMSJobs
        app.logger.warning("⚠️ MediaThumbnailService.configure() is deprecated. Use CMSJobs module instead.")
        print("📖 See: /Sources/CMSJobs/MediaThumbnailSubscriber.swift")
    }
}

// MARK: - Documentation References

/// 📚 Related types and documentation locations:
///
/// MediaUploadedEvent:
/// ```swift
/// // Location: Sources/CMSEvents/MediaUploadedEvent.swift
/// public struct MediaUploadedEvent: CmsEvent {
///     let mediaId: UUID
///     let filename: String
///     let mimeType: String
/// }
/// ```
///
/// ThumbnailSize definition:
/// ```swift
/// // Location: Sources/CMSObjects/ThumbnailSize.swift
/// public enum ThumbnailSize: String, Codable, Sendable {
///     case small   // 150x150, cropped square
///     case medium  // 300x300, aspect ratio preserved
///     case large   // 800x600 max, aspect ratio preserved
/// }
/// ```
///
/// MediaThumbnailSubscriber (actual implementation):
/// ```swift
/// // Location: Sources/CMSJobs/MediaThumbnailSubscriber.swift
/// public struct MediaThumbnailSubscriber: CmsEventHandler {
///     public func handle(_ event: MediaUploadedEvent, context: CmsContext) async throws {
///         // 1. Check if image (skip videos, documents)
///         guard event.mimeType.hasPrefix("image/") else {
///             context.logger.debug("Skipping thumbnailing for non-image: \(event.mimeType)")
///             return
///         }
///
///         // 2. Download original image
///         let originalData = try await storage.download(key: media.storagePath)
///
///         // 3. Generate thumbnails for each size
///         for size in [ThumbnailSize.small, .medium, .large] {
///             let thumbnailData = try await processor.generateThumbnail(
///                 from: originalData,
///                 mimeType: event.mimeType,
///                 size: size
///             )
///
///         // 4. Upload thumbnails
///         let thumbnailKey = "thumbnails/\(size.rawValue)/\(UUID()).jpg"
///         try await storage.upload(
///                 key: thumbnailKey,
///                 data: thumbnailData,
///                 contentType: event.mimeType
///             )
///
///         // 5. Update database
///         try await MediaFile.query(on: context.db)
///                 .filter(\.$id == event.mediaId)
///                 .set([thumbnail field], to: thumbnailKey)
///                 .update()
///         }
///     }
/// }
/// ```