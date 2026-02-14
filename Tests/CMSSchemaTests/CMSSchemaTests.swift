import XCTest
@testable import CMSSchema
@testable import CMSObjects

final class SchemaValidatorTests: XCTestCase {

    func testValidData() {
        let schema: AnyCodableValue = .dictionary([
            "type": "object",
            "properties": .dictionary([
                "title": .dictionary(["type": "string"]),
                "count": .dictionary(["type": "integer"])
            ]),
            "required": .array([.string("title")])
        ])

        let data: AnyCodableValue = .dictionary([
            "title": .string("Hello"),
            "count": .int(5)
        ])

        let errors = SchemaValidator.validate(data: data, against: schema)
        XCTAssertTrue(errors.isEmpty, "Expected no errors, got: \(errors)")
    }

    func testMissingRequired() {
        let schema: AnyCodableValue = .dictionary([
            "type": "object",
            "properties": .dictionary([
                "title": .dictionary(["type": "string"])
            ]),
            "required": .array([.string("title")])
        ])

        let data: AnyCodableValue = .dictionary([:])

        let errors = SchemaValidator.validate(data: data, against: schema)
        XCTAssertFalse(errors.isEmpty, "Expected validation errors for missing required field")
    }

    func testIsValid() {
        let schema: AnyCodableValue = .dictionary([
            "type": "object",
            "properties": .dictionary([:] as [String: AnyCodableValue])
        ])
        let data: AnyCodableValue = .dictionary([:])
        XCTAssertTrue(SchemaValidator.isValid(data: data, against: schema))
    }
}

final class SchemaGeneratorTests: XCTestCase {

    func testGenerateFromFields() {
        let fields = [
            FieldDefinition(name: "title", type: "shortText", required: true),
            FieldDefinition(name: "body", type: "richText"),
            FieldDefinition(name: "count", type: "integer"),
            FieldDefinition(name: "active", type: "boolean")
        ]

        let schema = SchemaGenerator.generate(from: fields)

        guard let dict = schema.dictionaryValue else {
            XCTFail("Schema should be a dictionary")
            return
        }

        XCTAssertEqual(dict["type"]?.stringValue, "object")

        let properties = dict["properties"]?.dictionaryValue ?? [:]
        XCTAssertEqual(properties.count, 4)
        XCTAssertNotNil(properties["title"])
        XCTAssertNotNil(properties["body"])

        let required = dict["required"]?.arrayValue ?? []
        XCTAssertEqual(required.count, 1)
        XCTAssertEqual(required.first?.stringValue, "title")
    }

    func testFieldTypeRegistry() {
        XCTAssertNotNil(FieldTypeRegistry.schemaFragment(for: "shortText"))
        XCTAssertNotNil(FieldTypeRegistry.schemaFragment(for: "richText"))
        XCTAssertNotNil(FieldTypeRegistry.schemaFragment(for: "integer"))
        XCTAssertNotNil(FieldTypeRegistry.schemaFragment(for: "boolean"))
        XCTAssertNotNil(FieldTypeRegistry.schemaFragment(for: "dateTime"))
        XCTAssertNotNil(FieldTypeRegistry.schemaFragment(for: "email"))
        XCTAssertNotNil(FieldTypeRegistry.schemaFragment(for: "relationHasOne"))
        XCTAssertNotNil(FieldTypeRegistry.schemaFragment(for: "relationHasMany"))
        XCTAssertNil(FieldTypeRegistry.schemaFragment(for: "nonExistent"))
        XCTAssertEqual(FieldTypeRegistry.allFieldTypes.count, 14)
    }
}

final class ContentStateMachineTests: XCTestCase {

    func testDraftTransitions() {
        let allowed = ContentStateMachine.allowedTransitions(from: .draft)
        XCTAssertTrue(allowed.contains(.review))
        XCTAssertTrue(allowed.contains(.published))
        XCTAssertFalse(allowed.contains(.archived))
        XCTAssertFalse(allowed.contains(.deleted))
    }

    func testPublishedTransitions() {
        let allowed = ContentStateMachine.allowedTransitions(from: .published)
        XCTAssertTrue(allowed.contains(.draft))
        XCTAssertTrue(allowed.contains(.archived))
        XCTAssertFalse(allowed.contains(.review))
    }

    func testDeletedIsTerminal() {
        let allowed = ContentStateMachine.allowedTransitions(from: .deleted)
        XCTAssertTrue(allowed.isEmpty)
    }

    func testCanTransition() {
        XCTAssertTrue(ContentStateMachine.canTransition(from: .draft, to: .published))
        XCTAssertFalse(ContentStateMachine.canTransition(from: .draft, to: .deleted))
        XCTAssertFalse(ContentStateMachine.canTransition(from: .deleted, to: .draft))
    }

    func testValidateTransitionThrows() {
        XCTAssertNoThrow(try ContentStateMachine.validateTransition(from: .draft, to: .published))
        XCTAssertThrowsError(try ContentStateMachine.validateTransition(from: .draft, to: .deleted))
    }
}
