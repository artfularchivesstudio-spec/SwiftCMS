import Vapor
import Fluent
import CMSObjects

/// Resolves relation fields by populating nested objects.
public struct RelationResolver: Sendable {

    /// Maximum depth for nested relation resolution.
    public static let maxDepth = 2

    /// Resolve relations in a content entry's data.
    /// - Parameters:
    ///   - data: The entry data containing relation UUIDs.
    ///   - schema: The JSON Schema describing the fields.
    ///   - db: Database connection.
    ///   - populateFields: Fields to populate (from ?populate= query param).
    ///   - depth: Current resolution depth.
    /// - Returns: Data with relations resolved to nested objects.
    public static func resolve(
        data: AnyCodableValue,
        schema: AnyCodableValue,
        on db: Database,
        populateFields: [String] = [],
        depth: Int = 0,
        visited: Set<String> = []
    ) async throws -> AnyCodableValue {
        guard depth < maxDepth else { return data }
        guard case .dictionary(var dataDict) = data else { return data }

        let properties = schema["properties"]?.dictionaryValue ?? [:]

        for field in populateFields {
            guard let fieldSchema = properties[field]?.dictionaryValue,
                  let fieldValue = dataDict[field] else {
                continue
            }

            let format = fieldSchema["format"]?.stringValue
            let type = fieldSchema["type"]?.stringValue

            // hasOne: UUID string -> nested object
            if type == "string" && format == "uuid",
               let uuidString = fieldValue.stringValue,
               let uuid = UUID(uuidString: uuidString) {

                // Circular detection
                let visitKey = "\(uuid)"
                guard !visited.contains(visitKey) else {
                    continue
                }
                var newVisited = visited
                newVisited.insert(visitKey)

                if let related = try await ContentEntry.find(uuid, on: db) {
                    dataDict[field] = related.data
                }
            }

            // hasMany: UUID array -> nested object array
            if type == "array",
               let items = fieldValue.arrayValue {
                var resolved: [AnyCodableValue] = []
                for item in items {
                    if let uuidString = item.stringValue,
                       let uuid = UUID(uuidString: uuidString) {
                        let visitKey = "\(uuid)"
                        guard !visited.contains(visitKey) else {
                            resolved.append(item)
                            continue
                        }
                        var newVisited = visited
                        newVisited.insert(visitKey)

                        if let related = try await ContentEntry.find(uuid, on: db) {
                            resolved.append(related.data)
                        } else {
                            resolved.append(item)
                        }
                    } else {
                        resolved.append(item)
                    }
                }
                dataDict[field] = .array(resolved)
            }
        }

        return .dictionary(dataDict)
    }
}
