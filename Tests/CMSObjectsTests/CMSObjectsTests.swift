import XCTest
@testable import CMSObjects

final class AnyCodableValueTests: XCTestCase {

    func testStringRoundtrip() throws {
        let value: AnyCodableValue = .string("hello")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        XCTAssertEqual(value, decoded)
    }

    func testIntRoundtrip() throws {
        let value: AnyCodableValue = .int(42)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        XCTAssertEqual(value, decoded)
    }

    func testDoubleRoundtrip() throws {
        let value: AnyCodableValue = .double(3.14)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        XCTAssertEqual(value, decoded)
    }

    func testBoolRoundtrip() throws {
        let value: AnyCodableValue = .bool(true)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        XCTAssertEqual(value, decoded)
    }

    func testNullRoundtrip() throws {
        let value: AnyCodableValue = .null
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        XCTAssertEqual(value, decoded)
    }

    func testArrayRoundtrip() throws {
        let value: AnyCodableValue = .array([.string("a"), .int(1), .bool(false)])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        XCTAssertEqual(value, decoded)
    }

    func testNestedDictionaryRoundtrip() throws {
        let value: AnyCodableValue = .dictionary([
            "name": .string("SwiftCMS"),
            "version": .int(2),
            "features": .array([.string("auth"), .string("graphql")]),
            "config": .dictionary([
                "debug": .bool(false),
                "port": .int(8080)
            ]),
            "nullable": .null
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        XCTAssertEqual(value, decoded)
    }

    func testAccessors() {
        let dict: AnyCodableValue = .dictionary([
            "name": .string("test"),
            "count": .int(5)
        ])
        XCTAssertEqual(dict["name"]?.stringValue, "test")
        XCTAssertEqual(dict["count"]?.intValue, 5)
        XCTAssertNil(dict["missing"])
    }

    func testArraySubscript() {
        let value: AnyCodableValue = .array([.int(1), .int(2), .int(3)])
        XCTAssertEqual(value[0]?.intValue, 1)
        XCTAssertEqual(value[2]?.intValue, 3)
        XCTAssertNil(value[5])
    }

    func testLiterals() {
        let s: AnyCodableValue = "hello"
        XCTAssertEqual(s, .string("hello"))

        let i: AnyCodableValue = 42
        XCTAssertEqual(i, .int(42))

        let b: AnyCodableValue = true
        XCTAssertEqual(b, .bool(true))

        let n: AnyCodableValue = nil
        XCTAssertEqual(n, .null)
    }

    func testToNative() {
        let value: AnyCodableValue = .dictionary([
            "key": .string("val"),
            "num": .int(10)
        ])
        let native = value.toNative()
        guard let dict = native as? [String: Any] else {
            XCTFail("Expected dictionary")
            return
        }
        XCTAssertEqual(dict["key"] as? String, "val")
        XCTAssertEqual(dict["num"] as? Int, 10)
    }
}

final class PaginationWrapperTests: XCTestCase {

    func testPaginationMeta() {
        let meta = PaginationMeta(page: 2, perPage: 10, total: 25)
        XCTAssertEqual(meta.page, 2)
        XCTAssertEqual(meta.perPage, 10)
        XCTAssertEqual(meta.total, 25)
        XCTAssertEqual(meta.totalPages, 3)
    }

    func testPaginationMetaZero() {
        let meta = PaginationMeta(page: 1, perPage: 0, total: 0)
        XCTAssertEqual(meta.totalPages, 0)
    }

    func testPaginationMetaSerialization() throws {
        let meta = PaginationMeta(page: 1, perPage: 25, total: 100)
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(PaginationMeta.self, from: data)
        XCTAssertEqual(decoded.totalPages, 4)
    }
}

final class ApiErrorTests: XCTestCase {

    func testNotFound() {
        let err = ApiError.notFound("Item missing")
        XCTAssertEqual(err.statusCode, 404)
        XCTAssertEqual(err.reason, "Item missing")
        XCTAssertTrue(err.error)
    }

    func testBadRequestWithDetails() {
        let err = ApiError.badRequest("Validation failed", details: ["title": "Required"])
        XCTAssertEqual(err.statusCode, 400)
        XCTAssertEqual(err.details?["title"], "Required")
    }

    func testSerialization() throws {
        let err = ApiError.forbidden()
        let data = try JSONEncoder().encode(err)
        let decoded = try JSONDecoder().decode(ApiError.self, from: data)
        XCTAssertEqual(decoded.statusCode, 403)
    }
}
