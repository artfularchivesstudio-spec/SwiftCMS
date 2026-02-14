import Vapor

// MARK: - 🎭 AnyCodableValue

/// 📦 A type-erased Codable value that represents any JSON-compatible data.
///
/// This enum serves as a universal container for JSON data, enabling all JSONB columns
/// in PostgreSQL models to be strongly typed within Swift while maintaining JSON
/// compatibility.
///
/// ✨ **Key Features:**
/// - Type-safe JSON handling
/// - PostgreSQL JSONB column storage
/// - Full Codable compliance
/// - Equatable for testing
/// - Sendable for concurrency safety
///
/// 🎯 **Supported Types:**
/// - String, Int, Double, Bool
/// - Arrays and dictionaries
/// - Null values
///
/// 📊 **Example Usage:**
/// ```swift
/// // Creating from literals
/// let simpleValue: AnyCodableValue = "Hello World"
/// let numberValue: AnyCodableValue = 42
/// let boolValue: AnyCodableValue = true
///
/// // Creating from native types
/// let dictValue = AnyCodableValue.from(["name": "Alice", "age": 30])
/// let arrayValue = AnyCodableValue.from([1, 2, 3, 4, 5])
///
/// // Accessing values
/// if case .string(let str) = simpleValue {
///     print("String value: \(str)")
/// }
///
/// // Using convenience accessors
/// let name = dictValue["name"]?.stringValue  // "Alice"
/// let age = dictValue["age"]?.intValue       // 30
/// ```
///
/// 🔗 **See Also:**
/// - ``toNative()`` - Convert to native Swift types
/// - ``from(_:)`` - Create from native types
/// - Convenience properties: `stringValue`, `intValue`, `boolValue`, etc.
public enum AnyCodableValue: Sendable, Equatable, Content {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    // MARK: - 💡 Convenience Accessors

    /// 📄 Extracts the string value if this is a `.string`, otherwise returns nil.
    ///
    /// - Returns: String value for `.string` cases, nil otherwise
    ///
    /// 📊 **Example:**
    /// ```swift
    /// let value: AnyCodableValue = "Hello World"
    /// print(value.stringValue) // Optional("Hello World")
    ///```
    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    /// 🔢 Extracts the integer value if this is an `.int`, otherwise returns nil.
    ///
    /// - Returns: Int value for `.int` cases, nil otherwise
    ///
    /// 📊 **Example:**
    ///```swift
    /// let value: AnyCodableValue = 42
    /// print(value.intValue) // Optional(42)
    ///```
    public var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    /// 🔮 Extracts the double value if this is a `.double`, otherwise returns nil.
    ///
    /// - Returns: Double value for `.double` cases, nil otherwise
    ///
    /// 📊 **Example:**
    /// ```swift
    /// let value: AnyCodableValue = 3.14159
    /// print(value.doubleValue) // Optional(3.14159)
    ///```
    public var doubleValue: Double? {
        if case .double(let v) = self { return v }
        return nil
    }

    /// ✅ Extracts the boolean value if this is a `.bool`, otherwise returns nil.
    ///
    /// - Returns: Bool value for `.bool` cases, nil otherwise
    ///
    /// 📊 **Example:**
    /// ```swift
    /// let value: AnyCodableValue = true
    /// print(value.boolValue) // Optional(true)
    ///```
    public var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    /// 📋 Extracts the array value if this is an `.array`, otherwise returns nil.
    ///
    /// - Returns: Array value for `.array` cases, nil otherwise
    ///
    /// 📊 **Example:**
    /// ```swift
    /// let value: AnyCodableValue = [1, 2, 3]
    /// print(value.arrayValue?.count) // Optional(3)
    ///```
    public var arrayValue: [AnyCodableValue]? {
        if case .array(let v) = self { return v }
        return nil
    }

    /// 🗂️ Extracts the dictionary value if this is a `.dictionary`, otherwise returns nil.
    ///
    /// - Returns: Dictionary value for `.dictionary` cases, nil otherwise
    ///
    /// 📊 **Example:**
    /// ```swift
    /// let value = AnyCodableValue.from(["name": "Alice"])
    /// print(value.dictionaryValue?.keys) // Optional(["name"])
    ///```
    public var dictionaryValue: [String: AnyCodableValue]? {
        if case .dictionary(let v) = self { return v }
        return nil
    }

    /// 🚫 Checks if this value is `.null`.
    ///
    /// - Returns: true if the value is null, false otherwise
    ///
    /// 📊 **Example:**
    /// ```swift
    /// let value: AnyCodableValue = .null
    /// print(value.isNull) // true
    /// let other: AnyCodableValue = "value"
    /// print(other.isNull) // false
    ///```
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// 🗝️ Subscript access for dictionary values by key.
    ///
    /// - Parameter key: The dictionary key to access
    /// - Returns: The value for the given key, or nil if not found
    ///
    /// 📊 **Example:**
    /// ```swift
    /// let user = AnyCodableValue.from(["name": "Alice", "age": 30])
    /// let name = user["name"]  // .string("Alice")
    /// let age = user["age"]    // .int(30)
    /// let invalid = user["invalid"] // nil
    ///```
    public subscript(key: String) -> AnyCodableValue? {
        if case .dictionary(let dict) = self {
            return dict[key]
        }
        return nil
    }

    /// 🔢 Subscript access for array values by index.
    ///
    /// - Parameter index: The array index to access
    /// - Returns: The value at the given index, or nil if out of bounds
    ///
    /// 📊 **Example:**
    /// ```swift
    /// let numbers = AnyCodableValue.from([1, 2, 3, 4, 5])
    /// let first = numbers[0]  // .int(1)
    /// let third = numbers[2]  // .int(3)
    /// let invalid = numbers[99] // nil
    ///```
    public subscript(index: Int) -> AnyCodableValue? {
        if case .array(let arr) = self, index >= 0, index < arr.count {
            return arr[index]
        }
        return nil
    }

    /// 🔄 Converts this value to a native Swift type for JSON Schema validation.
    ///
    /// This is primarily used when integrating with JSON Schema validation libraries
    /// that expect native Foundation types.
    ///
    /// - Returns: A native Swift type (String, Int, Double, Bool, NSNull, [Any], or [String: Any])
    ///
    /// 📊 **Example:**
    ///```swift
    /// let anyValue = AnyCodableValue.from(["name": "Alice"])
    /// let native = anyValue.toNative() // Returns [String: Any] dictionary
    ///```
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

    /// 🏭 Creates an AnyCodableValue from a native Swift type.
    ///
    /// This factory method handles conversion from Foundation types, making it easy
    /// to bridge between external data sources (JSON, API responses, databases) and the type-safe enum.
    ///
    /// - Parameter value: Any native value that should be JSON-encodable
    /// - Returns: An AnyCodableValue instance wrapping the provided value
    ///
    /// 📊 **Example:**
    ///```swift
    /// // From string
    /// let strValue = AnyCodableValue.from("Hello World") // .string("Hello World")
    ///
    /// // From dictionary
    /// let userData = ["id": 123, "name": "Bob"]
    /// let userValue = AnyCodableValue.from(userData) // .dictionary([...])
    ///
    /// // From array
    /// let numbers = [1, 2, 3, 4]
    /// let arrValue = AnyCodableValue.from(numbers) // .array([...])
    ///
    /// // Unsupported types convert to .null
    /// let nullValue = AnyCodableValue.from(UIView()) // .null
    ///```
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

// MARK: - 🔬 Codable Implementation

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

// MARK: - ✨ ExpressibleBy Literals

// MARK: - 📄 String Literal

/// Enables initializing AnyCodableValue with string literals.
extension AnyCodableValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

/// Enables initializing AnyCodableValue with Unicode scalar literals.
extension AnyCodableValue: ExpressibleByUnicodeScalarLiteral {
    public init(unicodeScalarLiteral value: String) {
        self = .string(value)
    }
}

/// Enables initializing AnyCodableValue with extended grapheme cluster literals.
extension AnyCodableValue: ExpressibleByExtendedGraphemeClusterLiteral {
    public init(extendedGraphemeClusterLiteral value: String) {
        self = .string(value)
    }
}

// MARK: - 🔢 Numeric Literals

/// Enables initializing AnyCodableValue with integer literals.
extension AnyCodableValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

/// Enables initializing AnyCodableValue with float literals.
extension AnyCodableValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

// MARK: - ✅ Boolean Literal

/// Enables initializing AnyCodableValue with boolean literals.
extension AnyCodableValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

// MARK: - 📋 Array Literal

/// Enables initializing AnyCodableValue with array literals.
extension AnyCodableValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: AnyCodableValue...) {
        self = .array(elements)
    }
}

// MARK: - 🗂️ Dictionary Literal

/// Enables initializing AnyCodableValue with dictionary literals.
extension AnyCodableValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, AnyCodableValue)...) {
        self = .dictionary(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - 🚫 Nil Literal

/// Enables initializing AnyCodableValue with nil literals.
extension AnyCodableValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

