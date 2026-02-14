import Vapor

/// A type-erased Codable value that represents any JSON-compatible data.
/// Used for all JSONB columns in PostgreSQL models.
public enum AnyCodableValue: Sendable, Equatable, Content {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    // MARK: - Convenience Accessors

    /// Returns the string value if this is a `.string`, otherwise nil.
    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    /// Returns the int value if this is an `.int`, otherwise nil.
    public var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    /// Returns the double value if this is a `.double`, otherwise nil.
    public var doubleValue: Double? {
        if case .double(let v) = self { return v }
        return nil
    }

    /// Returns the bool value if this is a `.bool`, otherwise nil.
    public var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    /// Returns the array value if this is an `.array`, otherwise nil.
    public var arrayValue: [AnyCodableValue]? {
        if case .array(let v) = self { return v }
        return nil
    }

    /// Returns the dictionary value if this is a `.dictionary`, otherwise nil.
    public var dictionaryValue: [String: AnyCodableValue]? {
        if case .dictionary(let v) = self { return v }
        return nil
    }

    /// Returns true if this value is `.null`.
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// Subscript access for dictionary values.
    public subscript(key: String) -> AnyCodableValue? {
        if case .dictionary(let dict) = self {
            return dict[key]
        }
        return nil
    }

    /// Subscript access for array values.
    public subscript(index: Int) -> AnyCodableValue? {
        if case .array(let arr) = self, index >= 0, index < arr.count {
            return arr[index]
        }
        return nil
    }

    /// Converts to a native Swift type for JSON Schema validation.
    public func toNative() -> Any {
        switch self {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .null: return NSNull()
        case .array(let arr): return arr.map { $0.toNative() }
        case .dictionary(let dict): return dict.mapValues { $0.toNative() }
        }
    }

    /// Creates an AnyCodableValue from a native Swift type.
    public static func from(_ value: Any) -> AnyCodableValue {
        switch value {
        case let v as String: return .string(v)
        case let v as Int: return .int(v)
        case let v as Double: return .double(v)
        case let v as Bool: return .bool(v)
        case let v as [Any]: return .array(v.map { from($0) })
        case let v as [String: Any]: return .dictionary(v.mapValues { from($0) })
        default: return .null
        }
    }
}

// MARK: - Codable

extension AnyCodableValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }
        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        if let arrayValue = try? container.decode([AnyCodableValue].self) {
            self = .array(arrayValue)
            return
        }
        if let dictValue = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dictValue)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Cannot decode AnyCodableValue"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .dictionary(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - ExpressibleBy Literals

extension AnyCodableValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension AnyCodableValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}

extension AnyCodableValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}

extension AnyCodableValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension AnyCodableValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: AnyCodableValue...) { self = .array(elements) }
}

extension AnyCodableValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, AnyCodableValue)...) {
        self = .dictionary(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension AnyCodableValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}
