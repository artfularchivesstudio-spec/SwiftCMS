import Foundation
import CMSObjects

/// Test fixtures for admin panel snapshot tests.
enum AdminTestFixtures {

    /// Sample blog content type JSON schema
    static let blogSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "title": [
                "type": "string",
                "title": "Title",
                "maxLength": 255
            ],
            "body": [
                "type": "string",
                "title": "Body",
                "format": "richtext"
            ],
            "published": [
                "type": "boolean",
                "title": "Published"
            ],
            "views": [
                "type": "number",
                "title": "Views",
                "minimum": 0
            ],
            "category": [
                "type": "string",
                "title": "Category",
                "enum": ["tech", "lifestyle", "news"]
            ]
        ],
        "required": ["title"]
    ]

    /// Sample blog field order
    static let blogFieldOrder = ["title", "body", "published", "views", "category"]

    /// Sample content type list data for template contexts
    static let sampleContentTypes: [[String: Any]] = [
        [
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "displayName": "Blog Posts",
            "slug": "blog-posts",
            "description": "Articles and blog entries",
            "kind": "collection",
            "fieldCount": 5
        ],
        [
            "id": "550e8400-e29b-41d4-a716-446655440002",
            "displayName": "Pages",
            "slug": "pages",
            "description": "Static pages",
            "kind": "single",
            "fieldCount": 3
        ],
        [
            "id": "550e8400-e29b-41d4-a716-446655440003",
            "displayName": "Products",
            "slug": "products",
            "description": "Product catalog items",
            "kind": "collection",
            "fieldCount": 8
        ]
    ]

    /// Sample recent entries for dashboard
    static let sampleRecentEntries: [[String: Any]] = [
        [
            "id": "660e8400-e29b-41d4-a716-446655440001",
            "contentType": "blog-posts",
            "status": "published",
            "data": ["title": "Getting Started with SwiftCMS"]
        ],
        [
            "id": "660e8400-e29b-41d4-a716-446655440002",
            "contentType": "blog-posts",
            "status": "draft",
            "data": ["title": "Advanced Content Modeling"]
        ],
        [
            "id": "660e8400-e29b-41d4-a716-446655440003",
            "contentType": "pages",
            "status": "published",
            "data": ["title": "About Us"]
        ]
    ]

    /// Sample blog entry data for edit view
    static let sampleBlogEntryData: [String: Any] = [
        "title": "Getting Started with SwiftCMS",
        "body": "<p>Welcome to SwiftCMS, a modern headless CMS built in Swift.</p>",
        "published": true,
        "views": 42,
        "category": "tech"
    ]
}
