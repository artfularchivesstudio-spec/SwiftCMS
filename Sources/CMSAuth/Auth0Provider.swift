import Vapor
import JWTKit
import CMSObjects

/// Auth0 authentication provider using JWKS.
public struct Auth0Provider: AuthProvider, Sendable {
    public let name = "auth0"

    public init() {}

    public func configure(app: Application) throws {
        guard let domain = Environment.get("AUTH0_DOMAIN") else {
            app.logger.warning("AUTH0_DOMAIN not set, Auth0 provider will not function")
            return
        }

        let jwksURL = "https://\(domain)/.well-known/jwks.json"
        app.logger.info("Configuring Auth0 with JWKS from: \(jwksURL)")

        // In production, fetch JWKS and add to app.jwt.keys
        // This is simplified for the initial implementation
    }

    public func verify(token: String, on req: Request) async throws -> AuthenticatedUser {
        // Decode JWT payload
        guard let payloadData = decodeJWTPayload(token: token) else {
            throw ApiError.unauthorized("Invalid token format")
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(Auth0TokenPayload.self, from: payloadData)

        // Check expiration
        guard payload.exp > Date() else {
            throw ApiError.unauthorized("Token expired")
        }

        // Check audience if configured
        if let expectedAudience = Environment.get("AUTH0_AUDIENCE") {
            guard payload.aud.contains(expectedAudience) else {
                throw ApiError.unauthorized("Invalid audience")
            }
        }

        return AuthenticatedUser(
            userId: payload.sub,
            email: payload.email,
            roles: payload.permissions ?? [],
            tenantId: payload.orgId
        )
    }

    public func middleware() -> any AsyncMiddleware {
        JWTBearerAuthenticator(provider: self)
    }

    /// Decode the payload portion of a JWT (without verification for now).
    private func decodeJWTPayload(token: String) -> Data? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        while base64.count % 4 != 0 {
            base64.append("=")
        }

        return Data(base64Encoded: base64)
    }
}

// MARK: - Auth0 Token Payload

/// JWT payload structure for Auth0 tokens.
public struct Auth0TokenPayload: Codable, Sendable {
    public let iss: String
    public let sub: String
    public let aud: [String]
    public let exp: Date
    public let iat: Date?
    public let email: String?
    public let permissions: [String]?
    public let orgId: String?

    enum CodingKeys: String, CodingKey {
        case iss, sub, aud, exp, iat, email, permissions
        case orgId = "org_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        iss = try container.decode(String.self, forKey: .iss)
        sub = try container.decode(String.self, forKey: .sub)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        permissions = try container.decodeIfPresent([String].self, forKey: .permissions)
        orgId = try container.decodeIfPresent(String.self, forKey: .orgId)

        // Handle aud as string or array
        if let audString = try? container.decode(String.self, forKey: .aud) {
            aud = [audString]
        } else {
            aud = try container.decode([String].self, forKey: .aud)
        }

        // Handle exp as Unix timestamp
        let expTimestamp = try container.decode(Double.self, forKey: .exp)
        exp = Date(timeIntervalSince1970: expTimestamp)

        if let iatTimestamp = try container.decodeIfPresent(Double.self, forKey: .iat) {
            iat = Date(timeIntervalSince1970: iatTimestamp)
        } else {
            iat = nil
        }
    }
}
