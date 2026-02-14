import Vapor
import CMSObjects
import CMSSchema

// MARK: - Firebase Auth Provider

/// Firebase authentication provider.
public struct FirebaseAuthProvider: AuthProvider, Sendable {
    public let name = "firebase"

    public init() {}

    public func configure(app: Application) throws {
        app.logger.info("Configuring Firebase Auth provider")
        // In production: fetch Google X.509 certs, schedule periodic refresh
    }

    public func verify(token: String, on req: Request) async throws -> AuthenticatedUser {
        guard let payloadData = decodePayload(token: token) else {
            throw ApiError.unauthorized("Invalid Firebase token")
        }

        struct FirebasePayload: Codable {
            let sub: String
            let email: String?
            let exp: Double
            let iss: String
            let aud: String?
            let customClaims: FirebaseClaims?

            struct FirebaseClaims: Codable {
                let roles: [String]?
            }

            enum CodingKeys: String, CodingKey {
                case sub, email, exp, iss, aud
                case customClaims = "custom_claims"
            }
        }

        let payload = try JSONDecoder().decode(FirebasePayload.self, from: payloadData)

        // Verify token expiry
        guard Date(timeIntervalSince1970: payload.exp) > Date() else {
            throw ApiError.unauthorized("Token expired")
        }

        // Verify issuer and audience against the configured Firebase project ID
        let projectId = Environment.get("FIREBASE_PROJECT_ID") ?? ""
        if !projectId.isEmpty {
            guard payload.iss == "https://securetoken.google.com/\(projectId)" else {
                throw ApiError.unauthorized("Invalid token issuer")
            }
            if let aud = payload.aud {
                guard aud == projectId else {
                    throw ApiError.unauthorized("Invalid token audience")
                }
            }
        }

        return AuthenticatedUser(
            userId: payload.sub,
            email: payload.email,
            roles: payload.customClaims?.roles ?? []
        )
    }

    public func middleware() -> any AsyncMiddleware {
        JWTBearerAuthenticator(provider: self)
    }

    private func decodePayload(token: String) -> Data? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        return Data(base64Encoded: base64)
    }
}

// MARK: - Local JWT Provider

/// Self-issued JWT provider for air-gapped deployments.
public struct LocalJWTProvider: AuthProvider, Sendable {
    public let name = "local"

    public init() {}

    public func configure(app: Application) throws {
        guard Environment.get("JWT_SECRET") != nil else {
            app.logger.warning("JWT_SECRET not set, using default (NOT FOR PRODUCTION)")
            return
        }
        app.logger.info("Configuring Local JWT provider")
    }

    public func verify(token: String, on req: Request) async throws -> AuthenticatedUser {
        guard let payloadData = decodePayload(token: token) else {
            throw ApiError.unauthorized("Invalid token format")
        }

        struct LocalPayload: Codable {
            let sub: String
            let email: String?
            let roles: [String]?
            let exp: Double
            let tenantId: String?

            enum CodingKeys: String, CodingKey {
                case sub, email, roles, exp
                case tenantId = "tenant_id"
            }
        }

        let payload = try JSONDecoder().decode(LocalPayload.self, from: payloadData)

        guard Date(timeIntervalSince1970: payload.exp) > Date() else {
            throw ApiError.unauthorized("Token expired")
        }

        return AuthenticatedUser(
            userId: payload.sub,
            email: payload.email,
            roles: payload.roles ?? [],
            tenantId: payload.tenantId
        )
    }

    public func middleware() -> any AsyncMiddleware {
        JWTBearerAuthenticator(provider: self)
    }

    /// Issue a JWT for a user (used by login endpoint).
    public static func issueToken(
        userId: String,
        email: String,
        roles: [String],
        tenantId: String? = nil
    ) throws -> String {
        let secret = Environment.get("JWT_SECRET") ?? "dev-secret-change-me"
        let header = try JSONEncoder().encode(["alg": "HS256", "typ": "JWT"])
        let payload: [String: AnyCodableValueWrapper] = [
            "sub": .string(userId),
            "email": .string(email),
            "roles": .array(roles),
            "exp": .double(Date().addingTimeInterval(86400).timeIntervalSince1970),
            "iat": .double(Date().timeIntervalSince1970),
        ]
        let payloadData = try JSONEncoder().encode(payload)

        let headerB64 = header.base64URLEncoded()
        let payloadB64 = payloadData.base64URLEncoded()
        let signingInput = "\(headerB64).\(payloadB64)"

        // HMAC-SHA256 signing
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(signingInput.utf8), using: key
        )
        let signatureB64 = Data(signature).base64URLEncoded()

        return "\(headerB64).\(payloadB64).\(signatureB64)"
    }

    private func decodePayload(token: String) -> Data? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        return Data(base64Encoded: base64)
    }
}

// MARK: - Helper Types

import Crypto

enum AnyCodableValueWrapper: Encodable {
    case string(String)
    case double(Double)
    case array([String])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        }
    }
}

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
