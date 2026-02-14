import XCTest
import Logging
@testable import CMSEvents

final class CMSEventsTests: XCTestCase {

    func testInProcessEventBusPublishSubscribe() async throws {
        let bus = InProcessEventBus()
        let expectation = XCTestExpectation(description: "Event received")
        var receivedEntryId: UUID?

        bus.subscribe(ContentCreatedEvent.self) { event, context in
            receivedEntryId = event.entryId
            expectation.fulfill()
        }

        // Small delay to let the actor register the handler
        try await Task.sleep(nanoseconds: 100_000_000)

        let entryId = UUID()
        let event = ContentCreatedEvent(entryId: entryId, contentType: "articles")
        let context = CmsContext(logger: Logger(label: "test"))

        try await bus.publish(event: event, context: context)

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedEntryId, entryId)
    }

    func testMultipleSubscribers() async throws {
        let bus = InProcessEventBus()
        let exp1 = XCTestExpectation(description: "Subscriber 1")
        let exp2 = XCTestExpectation(description: "Subscriber 2")

        bus.subscribe(ContentDeletedEvent.self) { _, _ in
            exp1.fulfill()
        }
        bus.subscribe(ContentDeletedEvent.self) { _, _ in
            exp2.fulfill()
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        let event = ContentDeletedEvent(entryId: UUID(), contentType: "posts")
        try await bus.publish(event: event, context: CmsContext(logger: Logger(label: "test")))

        await fulfillment(of: [exp1, exp2], timeout: 2.0)
    }

    func testEventName() {
        XCTAssertEqual(ContentCreatedEvent.eventName, "content.created")
        XCTAssertEqual(ContentUpdatedEvent.eventName, "content.updated")
        XCTAssertEqual(ContentDeletedEvent.eventName, "content.deleted")
        XCTAssertEqual(ContentPublishedEvent.eventName, "content.published")
        XCTAssertEqual(SchemaChangedEvent.eventName, "schema.changed")
        XCTAssertEqual(UserLoginEvent.eventName, "user.login")
        XCTAssertEqual(MediaUploadedEvent.eventName, "media.uploaded")
    }

    func testCmsContextProperties() {
        let ctx = CmsContext(
            logger: Logger(label: "test"),
            userId: "user-123",
            tenantId: "tenant-abc"
        )
        XCTAssertEqual(ctx.userId, "user-123")
        XCTAssertEqual(ctx.tenantId, "tenant-abc")
    }

    func testEventCodable() throws {
        let event = ContentCreatedEvent(
            entryId: UUID(),
            contentType: "articles",
            data: ["title": "Test"],
            userId: "user-1"
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(ContentCreatedEvent.self, from: data)
        XCTAssertEqual(decoded.contentType, "articles")
        XCTAssertEqual(decoded.data["title"], "Test")
    }
}
