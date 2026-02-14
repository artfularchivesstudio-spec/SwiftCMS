import Vapor
import CMSCore
import CMSEvents

// MARK: - Media Thumbnail Subscriber

/// Handles media upload events and dispatches thumbnail generation jobs.
public struct MediaThumbnailSubscriber: Sendable {

    /// Configure event subscriptions for thumbnail generation.
    public static func configure(app: Application) {
        app.eventBus.subscribe(MediaUploadedEvent.self) { event, context in
            // Only process image files
            guard event.mimeType.hasPrefix("image/") else {
                context.logger.debug("Skipping non-image file: \(event.filename)")
                return
            }

            // Queue thumbnail generation job
            let payload = ThumbnailJobPayload(mediaId: event.mediaId.uuidString)
            do {
                try await app.queues.queue.dispatch(ThumbnailJob.self, payload)
                context.logger.info("Queued thumbnail generation for \(event.filename)")
            } catch {
                context.logger.error("Failed to queue thumbnail job: \(error)")
            }
        }
    }
}
