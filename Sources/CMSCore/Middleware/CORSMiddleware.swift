import Vapor
import Foundation

/// Custom CORS middleware with advanced configuration support.
/// Provides origin whitelisting, wildcard support, credentials handling,
/// and per-tenant origin configuration for multi-tenancy.
public struct CORSMiddleware: AsyncMiddleware, Sendable {

    /// CORS configuration settings.
    public struct Configuration: Sendable {
        /// Allowed origin policy.
        public enum AllowedOrigin: Sendable {
            /// Allow all origins (`*`).
            case all
            /// Allow specific origins from a list.
            case any([String])
            /// Allow origins matching a regex pattern.
            case regex(String)
            /// Custom origin resolver function.
            case custom(@Sendable (String) -> Bool)

            func isAllowed(_ origin: String) -> Bool {
                switch self {
                case .all:
                    return true
                case .any(let origins):
                    return origins.contains(origin)
                case .regex(let pattern):
                    guard let regex = try? NSRegularExpression(pattern: pattern) else {
                        return false
                    }
                    let range = NSRange(location: 0, length: origin.utf16.count)
                    return regex.firstMatch(in: origin, range: range) != nil
                case .custom(let resolver):
                    return resolver(origin)
                }
            }
        }

        /// Which origins are allowed.
        public let allowedOrigin: AllowedOrigin

        /// HTTP methods allowed for CORS requests.
        public let allowedMethods: [HTTPMethod]

        /// HTTP headers allowed in CORS requests.
        public let allowedHeaders: [HTTPHeaders.Name]

        /// HTTP headers exposed to browsers.
        public let exposedHeaders: [HTTPHeaders.Name]

        /// Whether credentials (cookies, auth headers) are allowed.
        public let allowCredentials: Bool

        /// Cache duration for preflight requests (seconds).
        public let cacheExpiration: Int

        /// Whether to log CORS decisions.
        public let logDecisions: Bool

        /// Per-tenant origin overrides for multi-tenancy.
        public var tenantOrigins: [String: [String]]

        public init(
            allowedOrigin: AllowedOrigin,
            allowedMethods: [HTTPMethod] = [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
            allowedHeaders: [HTTPHeaders.Name] = [.accept, .authorization, .contentType,
                                                  .init("X-API-Key"), .init("X-Request-Id"),
                                                  .init("X-Tenant-ID")],
            exposedHeaders: [HTTPHeaders.Name] = [],
            allowCredentials: Bool = false,
            cacheExpiration: Int = 600,
            logDecisions: Bool = false,
            tenantOrigins: [String: [String]] = [:]
        ) {
            self.allowedOrigin = allowedOrigin
            self.allowedMethods = allowedMethods
            self.allowedHeaders = allowedHeaders
            self.exposedHeaders = exposedHeaders
            self.allowCredentials = allowCredentials
            self.cacheExpiration = cacheExpiration
            self.logDecisions = logDecisions
            self.tenantOrigins = tenantOrigins
        }

        /// Creates configuration from environment variables.
        /// Reads `CORS_ALLOWED_ORIGINS` and `CORS_ALLOW_CREDENTIALS`.
        public static func fromEnvironment() -> Configuration {
            let originsString = Environment.get("CORS_ALLOWED_ORIGINS") ?? "*"
            let origins = originsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            let allowedOrigin: AllowedOrigin
            if origins.count == 1 && origins[0] == "*" {
                allowedOrigin = .all
            } else {
                allowedOrigin = .any(origins)
            }

            let allowCredentials = Environment.get("CORS_ALLOW_CREDENTIALS")?.lowercased() == "true"

            // Load per-tenant origins from JSON config if available
            var tenantOrigins: [String: [String]] = [:]
            if let configPath = Environment.get("CORS_TENANT_CONFIG"),
               let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
               let config = try? JSONDecoder().decode(TenantCORSConfig.self, from: data) {
                tenantOrigins = config.tenants
            }

            return Configuration(
                allowedOrigin: allowedOrigin,
                allowCredentials: allowCredentials,
                tenantOrigins: tenantOrigins
            )
        }
    }

    private let configuration: Configuration

    public init(configuration: Configuration = .fromEnvironment()) {
        self.configuration = configuration
    }

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Handle preflight OPTIONS request
        if request.method == .OPTIONS {
            return try await handlePreflight(request: request)
        }

        // Process actual request
        let response = try await next.respond(to: request)
        return applyCORSHeaders(to: response, for: request)
    }

    // MARK: - Preflight Handling

    private func handlePreflight(request: Request) async throws -> Response {
        let origin = request.headers.first(name: .origin) ?? ""
        let requestMethod = request.headers.first(name: .accessControlRequestMethod) ?? ""
        let requestHeaders = request.headers[.accessControlRequestHeaders]

        guard !origin.isEmpty else {
            return Response(status: .ok)
        }

        // Check if origin is allowed
        let isAllowed = isOriginAllowed(origin, for: request)
        if configuration.logDecisions {
            request.logger.info("CORS preflight: \(origin) - \(isAllowed ? "allowed" : "denied")")
        }

        let response = Response(status: .ok)

        if isAllowed {
            // Apply allowed origin header
            applyOriginHeader(to: response, origin: origin)

            // Apply allowed methods
            if !requestMethod.isEmpty {
                let methodNames = configuration.allowedMethods.map { $0.rawValue }
                response.headers.add(name: .accessControlAllowMethods, value: methodNames.joined(separator: ", "))
            }

            // Apply allowed headers
            if !requestHeaders.isEmpty {
                response.headers.add(name: .accessControlAllowHeaders, value: requestHeaders.joined(separator: ", "))
            }

            // Apply credentials support
            if configuration.allowCredentials {
                response.headers.add(name: .accessControlAllowCredentials, value: "true")
            }

            // Apply cache expiration
            response.headers.add(name: .accessControlMaxAge, value: "\(configuration.cacheExpiration)")
        }

        return response
    }

    // MARK: - CORS Headers

    private func applyCORSHeaders(to response: Response, for request: Request) -> Response {
        let origin = request.headers.first(name: .origin) ?? ""

        guard !origin.isEmpty, isOriginAllowed(origin, for: request) else {
            return response
        }

        // Apply allowed origin header
        applyOriginHeader(to: response, origin: origin)

        // Apply exposed headers
        if !configuration.exposedHeaders.isEmpty {
            let headerNames = configuration.exposedHeaders.map { $0.description }
            response.headers.add(name: .accessControlExposeHeaders, value: headerNames.joined(separator: ", "))
        }

        // Apply credentials support
        if configuration.allowCredentials {
            response.headers.add(name: .accessControlAllowCredentials, value: "true")
        }

        return response
    }

    private func applyOriginHeader(to response: Response, origin: String) {
        switch configuration.allowedOrigin {
        case .all:
            if configuration.allowCredentials {
                // With credentials, cannot use wildcard; must echo origin
                response.headers.add(name: .accessControlAllowOrigin, value: origin)
                response.headers.add(name: .vary, value: "Origin")
            } else {
                response.headers.add(name: .accessControlAllowOrigin, value: "*")
            }
        case .any, .regex, .custom:
            response.headers.add(name: .accessControlAllowOrigin, value: origin)
            response.headers.add(name: .vary, value: "Origin")
        }
    }

    // MARK: - Origin Validation

    private func isOriginAllowed(_ origin: String, for request: Request) -> Bool {
        // Check tenant-specific origins first
        // Note: Direct tenantId access requires App module; using header fallback
        if let tenantId = request.headers.first(name: "X-Tenant-ID"),
           let tenantOrigins = configuration.tenantOrigins[tenantId],
           tenantOrigins.contains(origin) {
            return true
        }

        // Check global origin policy
        return configuration.allowedOrigin.isAllowed(origin)
    }
}

// MARK: - Tenant CORS Config

/// Tenant-specific CORS configuration loaded from JSON.
private struct TenantCORSConfig: Codable {
    let tenants: [String: [String]]
}

// MARK: - HTTPHeaders.Name Extensions

private extension HTTPHeaders.Name {
    static let accessControlAllowOrigin = HTTPHeaders.Name("Access-Control-Allow-Origin")
    static let accessControlAllowMethods = HTTPHeaders.Name("Access-Control-Allow-Methods")
    static let accessControlAllowHeaders = HTTPHeaders.Name("Access-Control-Allow-Headers")
    static let accessControlExposeHeaders = HTTPHeaders.Name("Access-Control-Expose-Headers")
    static let accessControlAllowCredentials = HTTPHeaders.Name("Access-Control-Allow-Credentials")
    static let accessControlMaxAge = HTTPHeaders.Name("Access-Control-Max-Age")
    static let accessControlRequestMethod = HTTPHeaders.Name("Access-Control-Request-Method")
    static let accessControlRequestHeaders = HTTPHeaders.Name("Access-Control-Request-Headers")
    static let origin = HTTPHeaders.Name("Origin")
}
