import Foundation
import CMSObjects

/// Factory methods for creating test fixtures with sensible defaults.
public struct TestFixtures {

    public static func makeContentTypeDTO(
        name: String = "Articles",
        slug: String = "articles",
        displayName: String = "Articles"
    ) -> CreateContentTypeDTO {
        CreateContentTypeDTO(
            name: name,
            slug: slug,
            displayName: displayName,
            kind: .collection,
            jsonSchema: .dictionary([
                "type": "object",
                "properties": .dictionary([
                    "title": .dictionary(["type": "string", "maxLength": 255]),
                    "body": .dictionary(["type": "string"]),
                    "published": .dictionary(["type": "boolean"])
                ]),
                "required": .array([.string("title")])
            ]),
            fieldOrder: ["title", "body", "published"]
        )
    }

    public static func makeContentEntryDTO(
        title: String = "Test Article",
        body: String = "Test body content",
        published: Bool = false
    ) -> CreateContentEntryDTO {
        CreateContentEntryDTO(
            data: .dictionary([
                "title": .string(title),
                "body": .string(body),
                "published": .bool(published)
            ])
        )
    }

    public static func makeUserDTO(
        email: String = "test@example.com"
    ) -> CreateUserDTO {
        CreateUserDTO(
            email: email,
            password: "password123",
            displayName: "Test User",
            authProvider: "local"
        )
    }

    public static func makeWebhookDTO(
        name: String = "Test Webhook",
        url: String = "https://example.com/webhook"
    ) -> CreateWebhookDTO {
        CreateWebhookDTO(
            name: name,
            url: url,
            events: ["content.created", "content.updated"]
        )
    }

    public static func sampleArticleSchema() -> AnyCodableValue {
        .dictionary([
            "type": "object",
            "properties": .dictionary([
                "title": .dictionary(["type": "string"]),
                "body": .dictionary(["type": "string"]),
                "date": .dictionary(["type": "string", "format": "date-time"]),
                "tags": .dictionary([
                    "type": "array",
                    "items": .dictionary(["type": "string"])
                ]),
                "featured": .dictionary(["type": "boolean"])
            ]),
            "required": .array([.string("title"), .string("body")])
        ])
    }
}
