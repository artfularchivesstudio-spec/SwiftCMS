import Vapor

// MARK: - ⚠️ ApiError

/// 📡 Structured API error response conforming to both AbortError and Content.
///
/// ApiError provides a consistent error response format across all API endpoints in SwiftCMS.
/// It integrates seamlessly with Vapor's error handling system while providing rich
/// error details and field-level validation messages.
///
/// ✨ **Key Features:**
/// - Conforms to `AbortError` for Vapor integration
/// - Conforms to `Content` for automatic JSON encoding
/// - `Sendable` for concurrency safety
/// - Optional field-level error details
/// - Factory methods for common error scenarios
///
/// 🔧 **Usage Example:**
/// ```swift
/// // In a route handler
/// func createUser(req: Request) async throws -> CreateUserDTO {
///     guard let email = req.content["email"]?.stringValue else {
///         throw ApiError.badRequest("Email is required", details: ["email": "Field is required"])
///     }
///     // ... create user
/// }
///
/// // In error middleware for logging
/// app.middleware.use(ErrorMiddleware.default(environment: app.environment, logError: { req, error in
///     if let apiError = error as? ApiError {
///         req.logger.error("API Error: \(apiError.reason)")
///         if let details = apiError.details {
///             req.logger.error("Error details: \(details)")
///         }
///     }
/// }))
///```
///
/// 📊 **Response Example:**
///```json
/// {
///   "error": true,
///   "statusCode": 400,
///   "reason": "Validation failed",
///   "details": {
///     "email": "Invalid email format",
///     "password": "Password must be at least 8 characters"
///   }
/// }
///```
public struct ApiError: AbortError, Content, Sendable {
    /// 🚫 Always true for error responses.
    public let error: Bool
    /// 🎯 HTTP status code.
    public let statusCode: Int
    /// 💭 Human-readable error reason.
    public let reason: String
    /// 📝 Optional detailed field-level errors.
    public let details: [String: String]?

    /// 📡 The HTTP status derived from statusCode.
    public var status: HTTPResponseStatus {
        HTTPResponseStatus(statusCode: statusCode)
    }

    /// 🏗️ Creates a new ApiError with specified details.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code for this error
    ///   - reason: Human-readable error message
    ///   - details: Optional dictionary of field-level error messages
    ///
    /// 📊 **Example:**
    /// ```swift
    /// let error = ApiError(
    ///   statusCode: 400,
    ///   reason: "Validation failed",
    ///   details: ["email": "Invalid format"]
    /// )
    ///```
    public init(
        statusCode: Int,
        reason: String,
        details: [String: String]? = nil
    ) {
        self.error = true
        self.statusCode = statusCode
        self.reason = reason
        self.details = details
    }

    /// 🏗️ Convenience initializer from HTTPResponseStatus.
    ///
    /// - Parameters:
    ///   - status: Vapor's HTTPResponseStatus enum value
    ///   - reason: Human-readable error message
    ///   - details: Optional dictionary of field-level error messages
    ///
    /// 📊 **Example:**
    /// ```swift
    /// let error = ApiError(status: .badRequest, reason: "Invalid input")
    /// ```
    public init(
        status: HTTPResponseStatus,
        reason: String,
        details: [String: String]? = nil
    ) {
        self.init(statusCode: Int(status.code), reason: reason, details: details)
    }

    // MARK: - 🏭 Common Error Factory Methods

    /// 📡 Creates a 404 Not Found error.
    ///
    /// - Parameter reason: Optional custom error message (defaults to "Resource not found")
    /// - Returns: Configured ApiError instance
    ///
    /// 📊 **Example:**
    /// ```swift
    /// throw ApiError.notFound("User with ID \(userId) not found")
    /// ```
    public static func notFound(_ reason: String = "Resource not found") -> ApiError {
        ApiError(status: .notFound, reason: reason)
    }

    /// ⚡ Creates a 400 Bad Request error.
    ///
    /// - Parameters:
    ///   - reason: Human-readable error message
    ///   - details: Optional dictionary of field-level errors
    /// - Returns: Configured ApiError instance
    ///
    /// 📊 **Example:**
    ///```swift
    /// throw ApiError.badRequest(
    ///     "Invalid request data",
    ///     details: ["email": "Must be a valid email address"]
    /// )
    ///```
    public static func badRequest(_ reason: String, details: [String: String]? = nil) -> ApiError {
        ApiError(status: .badRequest, reason: reason, details: details)
    }

    /// 🔐 Creates a 401 Unauthorized error.
    ///
    /// - Parameter reason: Optional custom error message (defaults to "Authentication required")
    /// - Returns: Configured ApiError instance
    ///
    /// 📊 **Example:**
    ///```swift
    /// guard let authHeader = req.headers.bearerAuthorization else {
    ///     throw ApiError.unauthorized("Bearer token required")
    /// }
    ///```
    public static func unauthorized(_ reason: String = "Authentication required") -> ApiError {
        ApiError(status: .unauthorized, reason: reason)
    }

    /// 🚫 Creates a 403 Forbidden error.
    ///
    /// - Parameter reason: Optional custom error message (defaults to "Insufficient permissions")
    /// - Returns: Configured ApiError instance
    ///
    /// 📊 **Example:**
    ///```swift
    /// guard user.hasPermission("manage_content") else {
    ///     throw ApiError.forbidden("You don't have permission to manage content")
    /// }
    ///```
    public static func forbidden(_ reason: String = "Insufficient permissions") -> ApiError {
        ApiError(status: .forbidden, reason: reason)
    }

    /// 💥 Creates a 409 Conflict error.
    ///
    /// - Parameter reason: Human-readable error message describing the conflict
    /// - Returns: Configured ApiError instance
    ///
    /// 📊 **Example:**
    ///```swift
    /// if try await User.query(on: req.db).filter(\.$email == email).first() != nil {
    ///     throw ApiError.conflict("Email already registered")
    /// }
    ///```
    public static func conflict(_ reason: String) -> ApiError {
        ApiError(status: .conflict, reason: reason)
    }

    /// 📋 Creates a 422 Unprocessable Entity error (typically for validation).
    ///
    /// - Parameters:
    ///   - reason: Human-readable error message
    ///   - details: Dictionary of field-level validation errors
    /// - Returns: Configured ApiError instance
    ///
    /// 📊 **Example:**
    ///```swift
    /// throw ApiError.unprocessableEntity(
    ///     "Validation failed",
    ///     details: ["password": "Must be at least 8 characters long"]
    /// )
    ///```
    public static func unprocessableEntity(_ reason: String, details: [String: String]? = nil) -> ApiError {
        ApiError(status: .unprocessableEntity, reason: reason, details: details)
    }

    /// 💔 Creates a 500 Internal Server Error.
    ///
    /// - Parameter reason: Optional custom error message (defaults to "Internal server error")
    /// - Returns: Configured ApiError instance
    ///
    /// 📊 **Example:**
    ///```swift
    /// do {
    ///     try performCriticalOperation()
    /// } catch {
    ///     req.logger.error("Critical operation failed: \(error)")
    ///     throw ApiError.internalError("An unexpected error occurred")
    /// }
    ///```
    public static func internalError(_ reason: String = "Internal server error") -> ApiError {
        ApiError(status: .internalServerError, reason: reason)
    }

    /// ⏱️ Creates a 429 Too Many Requests error.
    ///
    /// Useful for rate limiting responses.
    ///
    /// - Parameter reason: Optional custom error message (defaults to "Rate limit exceeded")
    /// - Returns: Configured ApiError instance
    ///
    /// 📊 **Example:**
    ///```swift
    /// if rateLimitExceeded {
    ///     throw ApiError.tooManyRequests("Please try again later")
    /// }
    ///```
    public static func tooManyRequests(_ reason: String = "Rate limit exceeded") -> ApiError {
        ApiError(statusCode: 429, reason: reason)
    }
}
