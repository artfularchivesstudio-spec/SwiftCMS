import XCTest
@testable import CMSJobs
@testable import CMSSchema
@testable import CMSMedia
@testable import CMSObjects

final class ThumbnailJobTests: XCTestCase {

    func testThumbnailSizeDimensions() {
        XCTAssertEqual(ThumbnailSize.small.dimensions, (150, 150))
        XCTAssertEqual(ThumbnailSize.medium.dimensions, (500, 500))
        XCTAssertEqual(ThumbnailSize.large.dimensions, (1000, 1000))
    }

    func testThumbnailSizeShouldCrop() {
        XCTAssertTrue(ThumbnailSize.small.shouldCrop)
        XCTAssertFalse(ThumbnailSize.medium.shouldCrop)
        XCTAssertFalse(ThumbnailSize.large.shouldCrop)
    }

    func testThumbnailJobPayloadEncoding() throws {
        let payload = ThumbnailJobPayload(mediaId: "123e4567-e89b-12d3-a456-426614174000")
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ThumbnailJobPayload.self, from: data)

        XCTAssertEqual(decoded.mediaId, payload.mediaId)
    }

    func testMediaFileThumbnailFields() {
        let media = MediaFile(
            filename: "test.jpg",
            mimeType: "image/jpeg",
            sizeBytes: 1024,
            storagePath: "uploads/2024/01/test.jpg",
            provider: "local",
            thumbnailSmall: "uploads/2024/01/test-thumb-small.jpg",
            thumbnailMedium: "uploads/2024/01/test-thumb-medium.jpg",
            thumbnailLarge: "uploads/2024/01/test-thumb-large.jpg"
        )

        XCTAssertEqual(media.thumbnailSmall, "uploads/2024/01/test-thumb-small.jpg")
        XCTAssertEqual(media.thumbnailMedium, "uploads/2024/01/test-thumb-medium.jpg")
        XCTAssertEqual(media.thumbnailLarge, "uploads/2024/01/test-thumb-large.jpg")
    }

    func testMediaResponseDTOWithThumbnails() {
        let dto = MediaResponseDTO(
            id: UUID(),
            filename: "test.jpg",
            mimeType: "image/jpeg",
            sizeBytes: 1024,
            url: "http://localhost/uploads/test.jpg",
            altText: "Test image",
            metadata: nil,
            createdAt: Date(),
            thumbnails: [
                "small": "http://localhost/uploads/test-thumb-small.jpg",
                "medium": "http://localhost/uploads/test-thumb-medium.jpg",
                "large": "http://localhost/uploads/test-thumb-large.jpg"
            ]
        )

        XCTAssertNotNil(dto.thumbnails)
        XCTAssertEqual(dto.thumbnails?.count, 3)
        XCTAssertEqual(dto.thumbnails?["small"]?.contains("thumb-small"), true)
    }
}
