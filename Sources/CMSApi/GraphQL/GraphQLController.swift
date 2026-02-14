import Vapor
import Fluent
import CMSObjects
import CMSSchema
import CMSAuth
import Graphiti

// MARK: - GraphQL Schema Builder

/// Builds a Graphiti schema from content type definitions.
/// Note: Full Graphiti + Pioneer integration requires those dependencies.
/// This provides the schema generation logic.
public struct GraphQLSchemaBuilder: Sendable {

    /// Map SwiftCMS field types to GraphQL type strings.
    public static let typeMapping: [String: String] = [
        "shortText": "String",
        "longText": "String",
        "richText": "String",
        "integer": "Int",
        "decimal": "Float",
        "boolean": "Boolean",
        "dateTime": "String",
        "email": "String",
        "enumeration": "String",
        "json": "JSON",
        "media": "ID",
        "relationHasOne": "ID",
        "relationHasMany": "[ID]",
        "component": "JSON"
    ]

    /// Generate GraphQL SDL from content type definitions.
    public static func generateSchema(
        from types: [ContentTypeDefinition]
    ) -> String {
        var sdl = """
        scalar JSON
        scalar DateTime

        type Query {
        """

        for typeDef in types {
            let typeName = typeDef.name.replacingOccurrences(of: " ", with: "")
            sdl += "\n    \(typeDef.slug)(id: ID!): \(typeName)"
            sdl += "\n    \(typeDef.slug)List(page: Int, perPage: Int): \(typeName)Connection!"
        }

        sdl += "\n}\n\ntype Mutation {"

        for typeDef in types {
            let typeName = typeDef.name.replacingOccurrences(of: " ", with: "")
            sdl += "\n    create\(typeName)(data: JSON!): \(typeName)!"
            sdl += "\n    update\(typeName)(id: ID!, data: JSON!): \(typeName)!"
            sdl += "\n    delete\(typeName)(id: ID!): Boolean!"
        }

        sdl += "\n}\n"

        // Generate types
        for typeDef in types {
            let typeName = typeDef.name.replacingOccurrences(of: " ", with: "")
            sdl += "\ntype \(typeName) {"
            sdl += "\n    id: ID!"
            sdl += "\n    status: String!"
            sdl += "\n    createdAt: DateTime"
            sdl += "\n    updatedAt: DateTime"

            if let props = typeDef.jsonSchema["properties"]?.dictionaryValue {
                for (fieldName, fieldSchema) in props {
                    let gqlType = mapToGraphQLType(fieldSchema)
                    sdl += "\n    \(fieldName): \(gqlType)"
                }
            }

            sdl += "\n}\n"

            // Connection type for pagination
            sdl += """

            type \(typeName)Connection {
                data: [\(typeName)!]!
                meta: PaginationMeta!
            }

            """
        }

        sdl += """

        type PaginationMeta {
            page: Int!
            perPage: Int!
            total: Int!
            totalPages: Int!
        }
        """

        return sdl
    }

    private static func mapToGraphQLType(_ schema: AnyCodableValue) -> String {
        guard let dict = schema.dictionaryValue,
              let type = dict["type"]?.stringValue else {
            return "JSON"
        }

        switch type {
        case "string":
            if dict["format"]?.stringValue == "date-time" { return "DateTime" }
            if dict["format"]?.stringValue == "uuid" { return "ID" }
            return "String"
        case "integer": return "Int"
        case "number": return "Float"
        case "boolean": return "Boolean"
        case "array": return "[JSON]"
        case "object": return "JSON"
        default: return "String"
        }
    }
}

// MARK: - GraphQL Request/Response Types

/// GraphQL request structure
struct GraphQLRequest: Content {
    let query: String
    let variables: [String: AnyCodableValue]?
    let operationName: String?
}

/// GraphQL response structure
struct GraphQLResponse: Content {
    let data: [String: AnyCodableValue]?
    let errors: [GraphQLError]?

    init(data: [String: AnyCodableValue]? = nil, errors: [GraphQLError]? = nil) {
        self.data = data
        self.errors = errors
    }
}

/// GraphQL error structure
struct GraphQLError: Content {
    let message: String
    let locations: [Location]?
    let path: [String]?

    struct Location: Content {
        let line: Int
        let column: Int
    }
}

// MARK: - GraphQL Endpoint Controller

/// GraphQL endpoint controller.
/// Routes: /graphql
public final class GraphQLController: RouteCollection {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        // SDL introspection endpoint
        routes.get("graphql", "schema") { req async throws -> String in
            let types = try await ContentTypeDefinition.query(on: req.db).all()
            return GraphQLSchemaBuilder.generateSchema(from: types)
        }

        // GraphQL Playground endpoint
        routes.get("graphql") { req -> Response in
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <style>
                    body { height: 100vh; margin: 0; width: 100%; overflow: hidden; }
                    #playground { height: 100vh; }
                </style>
                <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/graphql-playground-react@1.7.26/build/static/css/index.css" />
                <script crossorigin src="https://cdn.jsdelivr.net/npm/graphql-playground-react@1.7.26/build/static/js/middleware.js"></script>
            </head>
            <body>
                <div id="playground"></div>
                <script>
                    window.addEventListener('load', function (event) {
                        GraphQLPlayground.init(document.getElementById('playground'), {
                            endpoint: '/graphql',
                            subscriptionEndpoint: '/ws'
                        });
                    });
                </script>
            </body>
            </html>
            """

            var res = Response(status: .ok, headers: ["Content-Type": "text/html"])
            res.body = .init(string: html)
            return res
        }

        // Main GraphQL endpoint
        routes.post("graphql") { req async throws -> Response in
            // For now, return a simple placeholder response
            // Full GraphQL execution requires Graphiti executor integration
            let gqlReq = try req.content.decode(GraphQLRequest.self)
            req.logger.info("GraphQL query: \(gqlReq.query.prefix(100))")

            // Parse query and handle basic operations
            let queryLower = gqlReq.query.lowercased()

            var resultData: [String: AnyCodableValue] = [:]

            // Health check query
            if queryLower.contains("health") {
                resultData["health"] = .string("ok")
            }

            // Return response
            let res = Response(status: .ok)
            try res.content.encode(GraphQLResponse(data: resultData))
            return res
        }
    }
}
