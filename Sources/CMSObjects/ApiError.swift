import Vapor

/// Structured API error response conforming to both AbortError and Content.
public struct ApiError: AbortError, Content, Sendable {
    /// Always true for error responses.
    public let error: Bool
    /// HTTP status code.
    public let statusCode: Int
    /// Human-readable error reason.
    public let reason: String
    /// Optional detailed field-level errors.
    public let details: [String: String]?

    /// The HTTP status derived from statusCode.
    public var status: HTTPResponseStatus {
        HTTPResponseStatus(statusCode: statusCode)
    }

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

    /// Convenience initializer from HTTPResponseStatus.
    public init(
        status: HTTPResponseStatus,
        reason: String,
        details: [String: String]? = nil
    ) {
        self.init(statusCode: Int(status.code), reason: reason, details: details)
    }

    // MARK: - Common Errors

    public static func notFound(_ reason: String = "Resource not found") -> ApiError {
        ApiError(status: .notFound, reason: reason)
    }

    public static func badRequest(_ reason: String, details: [String: String]? = nil) -> ApiError {
        ApiError(status: .badRequest, reason: reason, details: details)
    }

    public static func unauthorized(_ reason: String = "Authentication required") -> ApiError {
        ApiError(status: .unauthorized, reason: reason)
    }

    public static func forbidden(_ reason: String = "Insufficient permissions") -> ApiError {
        ApiError(status: .forbidden, reason: reason)
    }

    public static func conflict(_ reason: String) -> ApiError {
        ApiError(status: .conflict, reason: reason)
    }

    public static func unprocessableEntity(_ reason: String, details: [String: String]? = nil) -> ApiError {
        ApiError(status: .unprocessableEntity, reason: reason, details: details)
    }

    public static func internalError(_ reason: String = "Internal server error") -> ApiError {
        ApiError(status: .internalServerError, reason: reason)
    }

    public static func tooManyRequests(_ reason: String = "Rate limit exceeded") -> ApiError {
        ApiError(statusCode: 429, reason: reason)
    }
}
