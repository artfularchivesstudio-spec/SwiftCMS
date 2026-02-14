import XCTest
import Vapor
@testable import CMSEvents

final class EventBusTests: XCTestCase {

    func testPublishSubscribe() async throws {
        let bus = InProcessEventBus()
        let expectation = XCTestExpectation(description: "Event received")

        bus.subscribe(ContentCreatedEvent.self) { event, _ in
            XCTAssertEqual(event.contentType, "articles")
            expectation.fulfill()
        }

        // Small delay to allow actor to register
        try await Task.sleep(nanoseconds: 100_000_000)

        let event = ContentCreatedEvent(
            entryId: UUID(),
            contentType: "articles"
        )
        let context = CmsContext(logger: Logger(label: "test"))
        try await bus.publish(event: event, context: context)

        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
