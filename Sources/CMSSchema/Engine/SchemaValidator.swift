import Foundation
import CMSObjects
import JSONSchema

/// Validates content data against JSON Schema definitions.
public struct SchemaValidator: Sendable {

    /// Validation error with field path information.
    public struct ValidationError: Sendable, CustomStringConvertible {
        public let path: String
        public let message: String

        public var description: String {
            path.isEmpty ? message : "\(path): \(message)"
        }

        public init(path: String = "", message: String) {
            self.path = path
            self.message = message
        }
    }

    /// Validate data against a JSON Schema.
    /// - Parameters:
    ///   - data: The content data to validate.
    ///   - schema: The JSON Schema to validate against.
    /// - Returns: Array of validation errors (empty if valid).
    public static func validate(
        data: AnyCodableValue,
        against schema: AnyCodableValue
    ) -> [ValidationError] {
        // Convert to native types for JSONSchema library
        let nativeData = data.toNative()
        let nativeSchema = schema.toNative()

        guard let schemaDict = nativeSchema as? [String: Any] else {
            return [ValidationError(message: "Invalid schema format")]
        }

        do {
            let result = try JSONSchema.validate(nativeData, schema: schemaDict)

            switch result {
            case .valid:
                return []
            case .invalid(let errors):
                return errors.map { error in
                    ValidationError(message: error.description)
                }
            }
        } catch {
            return [ValidationError(message: "Schema validation failed: \(error.localizedDescription)")]
        }
    }

    /// Quick check if data is valid against a schema.
    public static func isValid(
        data: AnyCodableValue,
        against schema: AnyCodableValue
    ) -> Bool {
        validate(data: data, against: schema).isEmpty
    }
}
