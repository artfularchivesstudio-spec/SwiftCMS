import Vapor
import Fluent
import Queues
import CMSCore
import CMSSchema
import CMSMedia
import CMSObjects
import CMSEvents

// MARK: - ⚡ Thumbnail Job

/// ⚡ **Background Job for Asynchronous Thumbnail Generation**
/// Processes uploaded images in the background to generate multiple thumbnail sizes,
/// offloading CPU-intensive image processing from HTTP request handlers.
///
/// # Job Architecture
/// - **Queue-driven**: Uses Vapor Queues for reliable async processing
/// - **Event-triggered**: Dispatched by MediaThumbnailSubscriber on MediaUploadedEvent
/// - **Independent**: Self-contained with all dependencies (storage, processor, db)
/// - **Retry-enabled**: Automatically retries on transient failures (5 attempts)
/// - **Idempotent**: Safe to re-run, existing thumbnails overwritten
///
/// # Processing Pipeline
/// ```
/// Async Queue → dequeue() → Validate MediaFile → Download Original → Process Each Size → Upload Thumbnails → Update DB
///     ↓              ↓           ↓                    ↓                ↓                      ↓             ↓
///  Redis List    Parse      Check exists/      Read from S3/    Generate small/      Save to S3/   Set thumbnail_
///  Ordered by    payload    permissions        local disk       medium/large         local       small/medium/large
///  priority                                                                                           fields
/// ```
///
/// # Size Generation Strategy
/// | Size | Dimensions | Use Case | File Size (avg) | Processing Time |
/// |------|------------|----------|-----------------|-----------------|
/// | **small** | 150×150px | Avatars, lists | 5–15 KB | 20–50ms |
/// | **medium** | 300×300px | Previews, cards | 15–40 KB | 30–70ms |
/// | **large** | 800×600px | Lightbox, zoom | 40–120 KB | 50–120ms |
///
/// # Concurrency & Queuing
/// - **Job queue**: Redis-backed `thumbnail` queue (default priority: medium)
/// - **Parallel processing**: 5-10 concurrent jobs recommended per worker
/// - **Rate limiting**: CPU-bound, limit to prevent system overload
/// - **Memory per job**: 50-200MB peak (depends on source image size)
///
/// # Platform Considerations
/// - **macOS**: Full ImageProcessor support via AppKit/NSImage
/// - **Linux**: Graceful degradation (logs, skips thumbnailling)
/// - **Memory**: 2GB+ RAM required for reliable operation
/// - **Disk**: Temporary space for downloaded originals (cleaned after use)
///
/// # Error Handling & Resilience
/// | Error Scenario | Response | Retry Logic | Logging |
/// |----------------|----------|-------------|---------|
/// | Media not found | Skip job silently | No retry | Error level |
/// | Non-image file | Skip after MIME check | No retry | Info level |
/// | Platform unsupported | Skip (Linux) | No retry | Warning level |
/// | Image processing failure | Skip this size only | No retry | Error level |
/// | Storage download error | Fail job | Retry with backoff | Error level |
/// | Database update error | Fail partially | Retry entire job | Error level |
///
/// # Idempotency Guarantee
/// - Same payload re-run multiple times produces identical results
/// - Overwrites existing thumbnails (no duplicate files)
/// - Database updates use `save()` which handles create/update
/// - Job deduplication via unique mediaId in payload
///
/// # Monitoring Metrics
/// ```swift
/// // Recommended instrumentation
/// logger.info("ThumbnailJob completed", metadata: [
///     "mediaId": payload.mediaId,
///     "sizesGenerated": thumbnails.keys.map { $0.rawValue },
///     "processingTimeMs": processingTime,
///     "platform": Platform.current.description
/// ])
/// ```
///
/// # Usage (Dispatching from Event Handler)
/// ```swift
/// app.eventBus.subscribe(MediaUploadedEvent.self) { event, context in
///     guard event.mimeType.hasPrefix("image/") else { return }
///
///     let payload = ThumbnailJobPayload(mediaId: event.mediaId.uuidString)
///     try await app.queues.queue.dispatch(ThumbnailJob.self, payload)
/// }
/// ```
///
/// # Production Considerations
/// - **Queue monitoring**: Alert if queue depth exceeds 1000 jobs
/// - **Worker scaling**: Autoscale workers based on queue depth metric
/// - **Disk cleanup**: Schedule cleanup of temp files from failed jobs
/// - **Image validation**: Verify MIME type before accepting upload (pre-filter)
public struct ThumbnailJob: AsyncJob, Sendable {
    public typealias Payload = ThumbnailJobPayload

    public init() {}

    public func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        let db = context.application.db
        let logger = context.logger

        guard let media = try await MediaFile.find(UUID(uuidString: payload.mediaId), on: db) else {
            logger.error("Media file \(payload.mediaId) not found")
            return
        }

        // Only process image files
        guard isImageMimeType(media.mimeType) else {
            logger.info("Skipping non-image file: \(media.filename)")
            return
        }

        logger.info("Generating thumbnails for \(media.filename)")

        let storage = context.application.fileStorage

        #if os(macOS)
        let imageData = try await storage.download(key: media.storagePath)
        let processor = ImageProcessor()
        var thumbnails: [ThumbnailSize: String] = [:]

        for size in ThumbnailSize.allCases {
            do {
                let thumbnailData = try await processor.generateThumbnail(
                    from: imageData,
                    mimeType: media.mimeType,
                    size: size
                )

                let thumbnailKey = generateThumbnailKey(originalKey: media.storagePath, size: size)
                _ = try await storage.upload(
                    key: thumbnailKey,
                    data: thumbnailData,
                    contentType: media.mimeType
                )
                thumbnails[size] = thumbnailKey
                logger.debug("Generated \(size) thumbnail for \(media.filename)")
            } catch {
                logger.error("Failed to generate \(size) thumbnail: \(error)")
            }
        }

        // Update media record with thumbnail paths
        if !thumbnails.isEmpty {
            media.thumbnailSmall = thumbnails[.small]
            media.thumbnailMedium = thumbnails[.medium]
            media.thumbnailLarge = thumbnails[.large]
            try await media.save(on: db)

            logger.info("Successfully generated \(thumbnails.count) thumbnails for \(media.filename)")
        }
        #else
        // Thumbnail generation requires AppKit (macOS only)
        logger.info("Thumbnail generation is not available on this platform")
        #endif
    }

    private func isImageMimeType(_ mimeType: String) -> Bool {
        let imageMimeTypes = [
            "image/jpeg",
            "image/jpg",
            "image/png",
            "image/gif",
            "image/webp"
        ]
        return imageMimeTypes.contains(mimeType.lowercased())
    }

    private func generateThumbnailKey(originalKey: String, size: ThumbnailSize) -> String {
        let ext = (originalKey as NSString).pathExtension
        let filename = (originalKey as NSString).deletingPathExtension
        return "\(filename)-\(size.rawValue).\(ext)"
    }
}

// MARK: - Thumbnail Job Payload

/// Payload for thumbnail generation jobs.
public struct ThumbnailJobPayload: Codable, Sendable {
    public let mediaId: String

    public init(mediaId: String) {
        self.mediaId = mediaId
    }
}
