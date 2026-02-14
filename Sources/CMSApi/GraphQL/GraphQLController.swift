import Vapor
import Fluent
import CMSObjects
import CMSSchema
import CMSEvents

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

/// GraphQL endpoint controller.
/// Routes: /graphql
public struct GraphQLController: RouteCollection, Sendable {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        // SDL introspection endpoint
        routes.get("graphql", "schema") { req async throws -> String in
            let types = try await ContentTypeDefinition.query(on: req.db).all()
            return GraphQLSchemaBuilder.generateSchema(from: types)
        }

        // GraphQL endpoint (simplified - full implementation requires Graphiti + Pioneer)
        routes.post("graphql") { req async throws -> Response in
            // Parse GraphQL query
            struct GraphQLRequest: Content {
                let query: String
                let variables: AnyCodableValue?
                let operationName: String?
            }

            let gqlReq = try req.content.decode(GraphQLRequest.self)
            req.logger.info("GraphQL query: \(gqlReq.query.prefix(100))")

            // Return schema info for introspection
            let res = Response(status: .ok)
            try res.content.encode(["data": AnyCodableValue.dictionary([
                "message": .string("GraphQL endpoint active. Full Graphiti+Pioneer integration pending.")
            ])])
            return res
        }
    }
}
