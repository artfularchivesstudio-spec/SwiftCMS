import Vapor
import Fluent
import CMSObjects
import CMSSchema

// MARK: - OpenAPI Generator

/// Generates OpenAPI 3.0 specification from content type definitions.
public actor OpenAPIGenerator {

    /// Generate the complete OpenAPI specification.
    public func generateSpecification(
        app: Application,
        baseURL: String
    ) async throws -> OpenAPIDocument {
        // Fetch all content types
        let contentTypes = try await ContentTypeDefinition.query(on: app.db).all()

        // Generate paths for each content type
        var paths: [String: OpenAPIPathItem] = generateStaticPaths()

        for contentType in contentTypes {
            let basePath = "/api/v1/\(contentType.slug)"

            // List operation
            paths[basePath] = OpenAPIPathItem(
                get: generateListOperation(contentType: contentType),
                post: generateCreateOperation(contentType: contentType)
            )

            // Detail operations
            paths["\(basePath)/{id}"] = OpenAPIPathItem(
                get: generateGetOperation(contentType: contentType),
                put: generateUpdateOperation(contentType: contentType),
                delete: generateDeleteOperation(contentType: contentType)
            )

            // Publish/unpublish
            paths["\(basePath)/{id}/publish"] = OpenAPIPathItem(
                post: generatePublishOperation(contentType: contentType)
            )

            paths["\(basePath)/{id}/unpublish"] = OpenAPIPathItem(
                post: generateUnpublishOperation(contentType: contentType)
            )
        }

        // Generate schemas
        var schemas: [String: OpenAPISchema] = generateStaticSchemas()
        for contentType in contentTypes {
            schemas[contentType.slug] = generateSchema(for: contentType)
            schemas["\(contentType.slug)_data"] = generateDataSchema(for: contentType)
        }

        // Add common schemas
        schemas["PaginationMeta"] = OpenAPISchema(
            type: .object,
            properties: [
                "page": .integer(OpenAPIIntegerSchema()),
                "perPage": .integer(OpenAPIIntegerSchema()),
                "total": .integer(OpenAPIIntegerSchema()),
                "totalPages": .integer(OpenAPIIntegerSchema())
            ],
            required: ["page", "perPage", "total", "totalPages"]
        )

        schemas["Error"] = OpenAPISchema(
            type: .object,
            properties: [
                "error": .string(OpenAPIStringSchema()),
                "statusCode": .integer(OpenAPIIntegerSchema()),
                "reason": .string(OpenAPIStringSchema())
            ],
            required: ["error", "statusCode", "reason"]
        )

        let components = OpenAPIComponents(
            schemas: schemas,
            securitySchemes: [
                "bearerAuth": OpenAPISecurityScheme(
                    type: "http",
                    scheme: "bearer",
                    bearerFormat: "JWT",
                    description: "JWT authentication"
                )
            ]
        )

        let info = OpenAPIInfo(
            title: "SwiftCMS API",
            version: "1.0.0",
            description: "A type-safe, high-performance headless CMS API"
        )

        let servers = [OpenAPIServer(url: baseURL)]

        return OpenAPIDocument(
            openapi: "3.0.0",
            info: info,
            servers: servers,
            paths: paths,
            components: components
        )
    }

    // MARK: - Static Definitions

    /// Generate static schemas for system DTOs.
    private func generateStaticSchemas() -> [String: OpenAPISchema] {
        return [
            "LoginDTO": OpenAPISchema(
                type: .object,
                properties: [
                    "email": .string(OpenAPIStringSchema(format: "email")),
                    "password": .string(OpenAPIStringSchema())
                ],
                required: ["email", "password"]
            ),
            
            "TokenResponseDTO": OpenAPISchema(
                type: .object,
                properties: [
                    "token": .string(OpenAPIStringSchema()),
                    "expiresIn": .integer(OpenAPIIntegerSchema()),
                    "tokenType": .string(OpenAPIStringSchema())
                ]
            ),
            
            "MediaResponseDTO": OpenAPISchema(
                type: .object,
                properties: [
                    "id": .string(OpenAPIStringSchema(format: "uuid")),
                    "filename": .string(OpenAPIStringSchema()),
                    "mimeType": .string(OpenAPIStringSchema()),
                    "sizeBytes": .integer(OpenAPIIntegerSchema()),
                    "url": .string(OpenAPIStringSchema()),
                    "altText": .string(OpenAPIStringSchema()),
                    "createdAt": .string(OpenAPIStringSchema(format: "date-time"))
                ]
            ),
            
            "SearchResponse": OpenAPISchema(
                type: .object,
                properties: [
                    "estimatedTotalHits": .integer(OpenAPIIntegerSchema()),
                    "page": .integer(OpenAPIIntegerSchema()),
                    "perPage": .integer(OpenAPIIntegerSchema()),
                    "processingTimeMs": .integer(OpenAPIIntegerSchema()),
                    "hits": .array(OpenAPIArraySchema(
                        type: .array,
                        items: .object(OpenAPIObjectSchema(type: .object))
                    )),
                    "facets": .object(OpenAPIObjectSchema(type: .object))
                ]
            )
        ]
    }

    /// Generate static paths for system endpoints.
    private func generateStaticPaths() -> [String: OpenAPIPathItem] {
        return [
            "/api/v1/auth/login": OpenAPIPathItem(
                post: OpenAPIOperation(
                    summary: "Login",
                    tags: ["Auth"],
                    requestBody: OpenAPIRequestBody(
                        required: true,
                        content: ["application/json": OpenAPIMediaType(schema: .ref("#/components/schemas/LoginDTO"))]
                    ),
                    responses: [
                        "200": OpenAPIResponse(
                            description: "Token response",
                            content: ["application/json": OpenAPIMediaType(schema: .ref("#/components/schemas/TokenResponseDTO"))]
                        )
                    ]
                )
            ),
            "/api/v1/media": OpenAPIPathItem(
                get: OpenAPIOperation(
                    summary: "List Media",
                    tags: ["Media"],
                    parameters: [
                        OpenAPIParameter(name: "page", in: .query, schema: .string(OpenAPIStringSchema(format: "integer"))),
                        OpenAPIParameter(name: "limit", in: .query, schema: .string(OpenAPIStringSchema(format: "integer")))
                    ],
                    responses: [
                        "200": OpenAPIResponse(
                            description: "List of media files",
                            content: ["application/json": OpenAPIMediaType(schema: .object(OpenAPIObjectSchema(
                                type: .object,
                                properties: [
                                    "data": .array(OpenAPIArraySchema(items: .ref("#/components/schemas/MediaResponseDTO"))),
                                    "meta": .ref("#/components/schemas/PaginationMeta")
                                ]
                            )))]
                        )
                    ]
                ),
                post: OpenAPIOperation(
                    summary: "Upload Media",
                    tags: ["Media"],
                    requestBody: OpenAPIRequestBody(
                        required: true,
                        content: ["multipart/form-data": OpenAPIMediaType(schema: .object(OpenAPIObjectSchema(
                            type: .object,
                            properties: ["file": .string(OpenAPIStringSchema(format: "binary"))]
                        )))]
                    ),
                    responses: [
                        "201": OpenAPIResponse(
                            description: "Uploaded media",
                            content: ["application/json": OpenAPIMediaType(schema: .ref("#/components/schemas/MediaResponseDTO"))]
                        )
                    ],
                    security: [["bearerAuth": []]]
                )
            ),
            "/api/v1/search": OpenAPIPathItem(
                get: OpenAPIOperation(
                    summary: "Global Search",
                    tags: ["Search"],
                    parameters: [
                        OpenAPIParameter(name: "q", in: .query, required: true, schema: .string(OpenAPIStringSchema())),
                        OpenAPIParameter(name: "type", in: .query, schema: .string(OpenAPIStringSchema()))
                    ],
                    responses: [
                        "200": OpenAPIResponse(
                            description: "Search results",
                            content: ["application/json": OpenAPIMediaType(schema: .ref("#/components/schemas/SearchResponse"))]
                        )
                    ]
                )
            )
        ]
    }

    // MARK: - Operation Generators

    private func generateListOperation(contentType: ContentTypeDefinition) -> OpenAPIOperation {
        let typeName = typeNameFromSlug(contentType.slug)

        return OpenAPIOperation(
            summary: "List all \(contentType.displayName)",
            tags: [typeName],
            description: "Retrieve a paginated list of \(contentType.displayName.lowercased())",
            parameters: [
                OpenAPIParameter(
                    name: "page",
                    in: .query,
                    schema: .integer(OpenAPIIntegerSchema())
                ),
                OpenAPIParameter(
                    name: "perPage",
                    in: .query,
                    schema: .integer(OpenAPIIntegerSchema())
                ),
                OpenAPIParameter(
                    name: "status",
                    in: .query,
                    schema: .string(OpenAPIStringSchema())
                ),
                OpenAPIParameter(
                    name: "locale",
                    in: .query,
                    schema: .string(OpenAPIStringSchema())
                )
            ],
            responses: [
                "200": OpenAPIResponse(
                    description: "Successful response",
                    content: [
                        "application/json": OpenAPIMediaType(
                            schema: .object(OpenAPIObjectSchema(
                                type: .object,
                                properties: [
                                    "data": .array(OpenAPIArraySchema(
                                        type: .array,
                                        items: .ref("#/components/schemas/\(contentType.slug)_data")
                                    )),
                                    "meta": .ref("#/components/schemas/PaginationMeta")
                                ]
                            ))
                        )
                    ]
                )
            ],
            security: [["bearerAuth": []]]
        )
    }

    private func generateCreateOperation(contentType: ContentTypeDefinition) -> OpenAPIOperation {
        let typeName = typeNameFromSlug(contentType.slug)

        return OpenAPIOperation(
            summary: "Create a new \(contentType.displayName.singularized())",
            tags: [typeName],
            description: "Create a new \(contentType.displayName.lowercased().singularized())",
            requestBody: OpenAPIRequestBody(
                required: true,
                content: [
                    "application/json": OpenAPIMediaType(
                        schema: .ref("#/components/schemas/\(contentType.slug)_data")
                    )
                ]
            ),
            responses: [
                "201": OpenAPIResponse(
                    description: "Created successfully",
                    content: [
                        "application/json": OpenAPIMediaType(
                            schema: .ref("#/components/schemas/\(contentType.slug)_data")
                        )
                    ]
                ),
                "400": OpenAPIResponse(
                    description: "Bad request",
                    content: [
                        "application/json": OpenAPIMediaType(
                            schema: .ref("#/components/schemas/Error")
                        )
                    ]
                )
            ],
            security: [["bearerAuth": []]]
        )
    }

    private func generateGetOperation(contentType: ContentTypeDefinition) -> OpenAPIOperation {
        let typeName = typeNameFromSlug(contentType.slug)

        return OpenAPIOperation(
            summary: "Get a specific \(contentType.displayName.singularized())",
            tags: [typeName],
            parameters: [
                OpenAPIParameter(
                    name: "id",
                    in: .path,
                    required: true,
                    schema: .string(OpenAPIStringSchema(format: "uuid")),
                    description: "The ID of the item"
                )
            ],
            responses: [
                "200": OpenAPIResponse(
                    description: "Successful response",
                    content: [
                        "application/json": OpenAPIMediaType(
                            schema: .ref("#/components/schemas/\(contentType.slug)_data")
                        )
                    ]
                ),
                "404": OpenAPIResponse(
                    description: "Not found",
                    content: [
                        "application/json": OpenAPIMediaType(
                            schema: .ref("#/components/schemas/Error")
                        )
                    ]
                )
            ],
            security: [["bearerAuth": []]]
        )
    }

    private func generateUpdateOperation(contentType: ContentTypeDefinition) -> OpenAPIOperation {
        let typeName = typeNameFromSlug(contentType.slug)

        return OpenAPIOperation(
            summary: "Update a \(contentType.displayName.singularized())",
            tags: [typeName],
            parameters: [
                OpenAPIParameter(
                    name: "id",
                    in: .path,
                    required: true,
                    schema: .string(OpenAPIStringSchema(format: "uuid"))
                )
            ],
            requestBody: OpenAPIRequestBody(
                required: true,
                content: [
                    "application/json": OpenAPIMediaType(
                        schema: .ref("#/components/schemas/\(contentType.slug)_data")
                    )
                ]
            ),
            responses: [
                "200": OpenAPIResponse(
                    description: "Updated successfully",
                    content: [
                        "application/json": OpenAPIMediaType(
                            schema: .ref("#/components/schemas/\(contentType.slug)_data")
                        )
                    ]
                )
            ],
            security: [["bearerAuth": []]]
        )
    }

    private func generateDeleteOperation(contentType: ContentTypeDefinition) -> OpenAPIOperation {
        let typeName = typeNameFromSlug(contentType.slug)

        return OpenAPIOperation(
            summary: "Delete a \(contentType.displayName.singularized())",
            tags: [typeName],
            parameters: [
                OpenAPIParameter(
                    name: "id",
                    in: .path,
                    required: true,
                    schema: .string(OpenAPIStringSchema(format: "uuid"))
                )
            ],
            responses: [
                "204": OpenAPIResponse(description: "Deleted successfully"),
                "404": OpenAPIResponse(
                    description: "Not found",
                    content: [
                        "application/json": OpenAPIMediaType(
                            schema: .ref("#/components/schemas/Error")
                        )
                    ]
                )
            ],
            security: [["bearerAuth": []]]
        )
    }

    private func generatePublishOperation(contentType: ContentTypeDefinition) -> OpenAPIOperation {
        let typeName = typeNameFromSlug(contentType.slug)

        return OpenAPIOperation(
            summary: "Publish a \(contentType.displayName.singularized())",
            tags: [typeName],
            parameters: [
                OpenAPIParameter(
                    name: "id",
                    in: .path,
                    required: true,
                    schema: .string(OpenAPIStringSchema(format: "uuid"))
                )
            ],
            responses: [
                "200": OpenAPIResponse(
                    description: "Published successfully",
                    content: [
                        "application/json": OpenAPIMediaType(
                            schema: .ref("#/components/schemas/\(contentType.slug)_data")
                        )
                    ]
                )
            ],
            security: [["bearerAuth": []]]
        )
    }

    private func generateUnpublishOperation(contentType: ContentTypeDefinition) -> OpenAPIOperation {
        let typeName = typeNameFromSlug(contentType.slug)

        return OpenAPIOperation(
            summary: "Unpublish a \(contentType.displayName.singularized())",
            tags: [typeName],
            parameters: [
                OpenAPIParameter(
                    name: "id",
                    in: .path,
                    required: true,
                    schema: .string(OpenAPIStringSchema(format: "uuid"))
                )
            ],
            responses: [
                "200": OpenAPIResponse(
                    description: "Unpublished successfully",
                    content: [
                        "application/json": OpenAPIMediaType(
                            schema: .ref("#/components/schemas/\(contentType.slug)_data")
                        )
                    ]
                )
            ],
            security: [["bearerAuth": []]]
        )
    }

    // MARK: - Schema Generators

    private func generateSchema(for contentType: ContentTypeDefinition) -> OpenAPISchema {
        guard case let .dictionary(jsonSchema) = contentType.jsonSchema else {
            return OpenAPISchema(type: .object)
        }

        var properties: [String: OpenAPISchemaProperty] = [:]
        var required: [String] = []

        if let jsonProps = jsonSchema["properties"]?.dictionaryValue {
            for (fieldName, fieldSchema) in jsonProps {
                if let dict = fieldSchema.dictionaryValue,
                   let type = dict["type"]?.stringValue {
                    properties[fieldName] = generatePropertySchema(from: dict, type: type)

                    if let requiredFields = jsonSchema["required"]?.arrayValue {
                        if requiredFields.contains(where: { $0.stringValue == fieldName }) {
                            required.append(fieldName)
                        }
                    }
                }
            }
        }

        return OpenAPISchema(
            type: .object,
            properties: properties,
            required: required.isEmpty ? nil : required
        )
    }

    private func generateDataSchema(for contentType: ContentTypeDefinition) -> OpenAPISchema {
        return generateSchema(for: contentType)
    }

    private func generatePropertySchema(from dict: [String: AnyCodableValue], type: String) -> OpenAPISchemaProperty {
        switch type {
        case "string":
            let format = dict["format"]?.stringValue
            return .string(OpenAPIStringSchema(format: format))

        case "integer":
            return .integer(OpenAPIIntegerSchema())

        case "number":
            return .number(OpenAPINumberSchema())

        case "boolean":
            return .boolean(OpenAPIBooleanSchema())

        case "array":
            if let items = dict["items"]?.dictionaryValue,
               let itemType = items["type"]?.stringValue {
                let itemSchema = generatePropertySchema(from: items, type: itemType)
                return .array(OpenAPIArraySchema(
                    type: .array,
                    items: itemSchema
                ))
            }
            return .array(OpenAPIArraySchema(type: .array))

        case "object":
            return .object(OpenAPIObjectSchema(type: .object))

        default:
            return .string(OpenAPIStringSchema())
        }
    }

    /// Convert a slug to a type name (PascalCase).
    private func typeNameFromSlug(_ slug: String) -> String {
        return slug
            .split(separator: "_")
            .map { $0.capitalized }
            .joined()
    }
}

// MARK: - OpenAPI Data Structures

public struct OpenAPIDocument: Content {
    public let openapi: String
    public let info: OpenAPIInfo
    public let servers: [OpenAPIServer]
    public let paths: [String: OpenAPIPathItem]
    public let components: OpenAPIComponents

    public init(
        openapi: String,
        info: OpenAPIInfo,
        servers: [OpenAPIServer],
        paths: [String: OpenAPIPathItem],
        components: OpenAPIComponents
    ) {
        self.openapi = openapi
        self.info = info
        self.servers = servers
        self.paths = paths
        self.components = components
    }
}

public struct OpenAPIInfo: Content {
    public let title: String
    public let version: String
    public let description: String?

    public init(title: String, version: String, description: String? = nil) {
        self.title = title
        self.version = version
        self.description = description
    }
}

public struct OpenAPIServer: Content {
    public let url: String
    public let description: String?

    public init(url: String, description: String? = nil) {
        self.url = url
        self.description = description
    }
}

public struct OpenAPIPathItem: Content {
    public let get: OpenAPIOperation?
    public let post: OpenAPIOperation?
    public let put: OpenAPIOperation?
    public let delete: OpenAPIOperation?
    public let patch: OpenAPIOperation?

    public init(
        get: OpenAPIOperation? = nil,
        post: OpenAPIOperation? = nil,
        put: OpenAPIOperation? = nil,
        delete: OpenAPIOperation? = nil,
        patch: OpenAPIOperation? = nil
    ) {
        self.get = get
        self.post = post
        self.put = put
        self.delete = delete
        self.patch = patch
    }
}

public struct OpenAPIOperation: Content {
    public let summary: String
    public let tags: [String]
    public let description: String?
    public let parameters: [OpenAPIParameter]?
    public let requestBody: OpenAPIRequestBody?
    public let responses: [String: OpenAPIResponse]
    public let security: [[String: [String]]]?
    public let deprecated: Bool?

    public init(
        summary: String,
        tags: [String],
        description: String? = nil,
        parameters: [OpenAPIParameter]? = nil,
        requestBody: OpenAPIRequestBody? = nil,
        responses: [String: OpenAPIResponse],
        security: [[String: [String]]]? = nil,
        deprecated: Bool? = nil
    ) {
        self.summary = summary
        self.tags = tags
        self.description = description
        self.parameters = parameters
        self.requestBody = requestBody
        self.responses = responses
        self.security = security
        self.deprecated = deprecated
    }
}

public struct OpenAPIParameter: Content {
    public let name: String
    public let location: OpenAPIParameterLocation
    public let required: Bool?
    public let schema: OpenAPISchemaProperty
    public let description: String?

    public init(
        name: String,
        in location: OpenAPIParameterLocation,
        required: Bool? = nil,
        schema: OpenAPISchemaProperty,
        description: String? = nil
    ) {
        self.name = name
        self.location = location
        self.required = required
        self.schema = schema
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case name, location, required, schema, description
    }
}

public enum OpenAPIParameterLocation: String, Content {
    case query
    case header
    case path
    case cookie
}

public struct OpenAPIRequestBody: Content {
    public let required: Bool?
    public let content: [String: OpenAPIMediaType]

    public init(required: Bool? = nil, content: [String: OpenAPIMediaType]) {
        self.required = required
        self.content = content
    }
}

public struct OpenAPIResponse: Content {
    public let description: String
    public let content: [String: OpenAPIMediaType]?

    public init(description: String, content: [String: OpenAPIMediaType]? = nil) {
        self.description = description
        self.content = content
    }
}

public struct OpenAPIMediaType: Content {
    public let schema: OpenAPISchemaProperty

    public init(schema: OpenAPISchemaProperty) {
        self.schema = schema
    }
}

public struct OpenAPIComponents: Content {
    public let schemas: [String: OpenAPISchema]
    public let securitySchemes: [String: OpenAPISecurityScheme]

    public init(
        schemas: [String: OpenAPISchema],
        securitySchemes: [String: OpenAPISecurityScheme] = [:]
    ) {
        self.schemas = schemas
        self.securitySchemes = securitySchemes
    }
}

public struct OpenAPISecurityScheme: Content {
    public let type: String
    public let scheme: String?
    public let bearerFormat: String?
    public let description: String?

    public init(
        type: String,
        scheme: String? = nil,
        bearerFormat: String? = nil,
        description: String? = nil
    ) {
        self.type = type
        self.scheme = scheme
        self.bearerFormat = bearerFormat
        self.description = description
    }
}

// MARK: - OpenAPI Schema Types

public enum OpenAPISchemaType: String, Content {
    case object
    case string
    case integer
    case number
    case boolean
    case array
}

public struct OpenAPISchema: Content {
    public let type: OpenAPISchemaType
    public let properties: [String: OpenAPISchemaProperty]?
    public let required: [String]?
    public let format: String?
    public let enumValues: [String]?
    public let minimum: Double?
    public let maximum: Double?
    public let items: OpenAPISchemaProperty?
    public let description: String?
    public let ref: String?

    public init(
        type: OpenAPISchemaType,
        properties: [String: OpenAPISchemaProperty]? = nil,
        required: [String]? = nil,
        format: String? = nil,
        enumValues: [String]? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        items: OpenAPISchemaProperty? = nil,
        description: String? = nil,
        ref: String? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.format = format
        self.enumValues = enumValues
        self.minimum = minimum
        self.maximum = maximum
        self.items = items
        self.description = description
        self.ref = ref
    }

    enum CodingKeys: String, CodingKey {
        case type, properties, required, format, enumValues, minimum, maximum, items, description
        case ref = "$ref"
    }
}

public indirect enum OpenAPISchemaProperty: Content {
    case object(OpenAPIObjectSchema)
    case string(OpenAPIStringSchema)
    case integer(OpenAPIIntegerSchema)
    case number(OpenAPINumberSchema)
    case boolean(OpenAPIBooleanSchema)
    case array(OpenAPIArraySchema)
    case ref(String)

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .object(let s):
            try container.encode(s)
        case .string(let s):
            try container.encode(s)
        case .integer(let s):
            try container.encode(s)
        case .number(let s):
            try container.encode(s)
        case .boolean(let s):
            try container.encode(s)
        case .array(let s):
            try container.encode(s)
        case .ref(let s):
            try container.encode(["$ref": s])
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .ref(stringValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid schema property"
            )
        }
    }
}

public struct OpenAPIObjectSchema: Content {
    public let type: OpenAPISchemaType
    public let properties: [String: OpenAPISchemaProperty]?
    public let required: [String]?

    public init(
        type: OpenAPISchemaType = .object,
        properties: [String: OpenAPISchemaProperty]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

public struct OpenAPIStringSchema: Content {
    public let type: OpenAPISchemaType = .string
    public let format: String?
    public let enumValues: [String]?

    public init(format: String? = nil, enumValues: [String]? = nil) {
        self.format = format
        self.enumValues = enumValues
    }

    enum CodingKeys: String, CodingKey {
        case type, format, enumValues
    }
}

public struct OpenAPIIntegerSchema: Content {
    public let type: OpenAPISchemaType = .integer
    public let minimum: Double?
    public let maximum: Double?

    public init(minimum: Double? = nil, maximum: Double? = nil) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public struct OpenAPINumberSchema: Content {
    public let type: OpenAPISchemaType = .number
    public let minimum: Double?
    public let maximum: Double?

    public init(minimum: Double? = nil, maximum: Double? = nil) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public struct OpenAPIBooleanSchema: Content {
    public let type: OpenAPISchemaType = .boolean

    public init() {}
}

public struct OpenAPIArraySchema: Content {
    public let type: OpenAPISchemaType
    public let items: OpenAPISchemaProperty?

    public init(
        type: OpenAPISchemaType = .array,
        items: OpenAPISchemaProperty? = nil
    ) {
        self.type = type
        self.items = items
    }
}

// MARK: - String Extensions

extension String {
    func singularized() -> String {
        if self.hasSuffix("ies") {
            return String(self.dropLast(3)) + "y"
        } else if self.hasSuffix("es") {
            return String(self.dropLast(2))
        } else if self.hasSuffix("s") {
            return String(self.dropLast())
        }
        return self
    }
}
