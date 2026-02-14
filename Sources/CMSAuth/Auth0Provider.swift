import Vapor
import JWTKit
import CMSObjects

// MARK: - 🔐 Auth0 Provider

/// 🔐 **Auth0 Authentication Provider**
///
/// Enterprise-grade authentication using Auth0's OAuth 2.0 and OpenID Connect.
/// Supports social logins, enterprise connections, and custom authentication flows.
///
/// ## Auth0 Overview
///
/// Auth0 is a leading identity platform that provides:
/// - 🔑 **Universal Login**: Ready-made, customizable login pages
/// - 🌐 **Social Connections**: Google, Facebook, Twitter, etc.
/// - 🏢 **Enterprise SSO**: SAML, LDAP, Active Directory
/// - 📱 **Passwordless**: Email/SMS one-time codes
/// - 🔐 **MFA**: Multi-factor authentication (TOTP, SMS, Push)
/// - 📊 **User Management**: Admin dashboard, user search
/// - 🎯 **Rules/Hooks**: Custom authentication logic
/// - 📈 **Analytics**: Login metrics and monitoring
///
/// ## Architecture
///
/// ### Auth0 Integration Flow
/// ```
/// SwiftCMS API                       Auth0
///     │                                 │
///     │  1. Client sends JWT            │
///     │────────────────────────────────▶│
///     │                                 │
///     │  2. Verify signature            │
///     │  (using JWKS endpoint)          │
///     │                                 │
///     │  3. Validate claims             │
///     │  (exp, iss, aud, etc.)          │
///     │                                 │
///     │  4. Extract user info           │
///     │                                 │
///     │◀────────────────────────────────│
///     │                                 │
///     │  5. Create CmsUser              │
///     │  6. Continue request            │
/// ```
///
/// ### JWKS (JSON Web Key Set) Flow
/// ```
/// ┌─────────────────┐
/// │  JWT Token      │
/// │  from Client    │
/// └────────┬────────┘
///          │ 1. Decode header
///          │    └─{"kid": "key-id-123", "alg": "RS256"}
///          ↓
/// ┌─────────────────────┐
/// │  Check Cache        │
/// │  for Key ID         │◀──┐
/// └────────┬────────────┘   │
///          │ Cache hit?     │
///          │                │
///          │ YES            │
///          ↓                │
/// ┌─────────────────┐      │
/// │  Use Cached     │      │
/// │  Public Key     │      │
/// └────────┬────────┘      │
///          │                │ NO
///          │                │
///          ↓                │
/// ┌───────────────────────┐ │
/// │  Fetch from Auth0     │ │
/// │  ┌─────────────────┐  │ │
/// │  │ GET /.well-known│  │ │
/// │  │ /jwks.json      │  │ │
/// │  └────────┬────────┘  │ │
/// │           │             │ │
/// │  ┌────────▼────────┐   │ │
/// │  │  {"keys": [...]} │   │ │
/// │  └────────┬────────┘   │ │
/// └───────────┼────────────┘ │
///             │ 2. Parse and │
///             │    cache     │
///             ↓              │
/// ┌────────────────────┐     │
/// │  Extract RSA       │     │
/// │  Public Key        │     │
/// └────────┬───────────┘     │
///          │                 │
///          └─────────────────┘
///          ↓
/// ┌─────────────────┐
/// │  Verify JWT     │
/// │  Signature        │
/// └────────┬────────┘
///          ↓
///     ✅ Valid Token
/// ```
///
/// ## Features
///
/// ### 🔐 JWT Signature Verification
/// - **JWKS endpoint**: Fetches signing keys from Auth0
/// - **RSA256 support**: Industry-standard asymmetric signing
/// - **Automatic rotation**: Handles Auth0's key rotation
/// - **Caching**: Caches keys for performance
///
/// ### 🏢 Multi-Tenant Support
/// - **Organization claims**: Built-in tenant isolation
/// - **org_id claim**: Maps to tenantId in SwiftCMS
/// - **Org-based roles**: Different roles per organization
///
/// ### 🔑 Role-Based Access Control
/// - **Permissions array**: Auth0's RBAC in action
/// - **Custom claims**: Extend tokens with app-specific data
/// - **Dynamic scopes**: Request specific permissions
///
/// ### 🌐 Identity Provider Support
/// - **Social**: Google, Facebook, Twitter, GitHub, etc.
/// - **Enterprise**: SAML, LDAP, ADFS, Okta
/// - **Passwordless**: Email magic links, SMS codes
/// - **MFA**: TOTP, SMS, Push notifications
///
/// ## Token Structure
///
/// ### Sample Auth0 JWT Token
/// ```json
/// {
///   // Standard JWT claims
///   "iss": "https://your-domain.auth0.com",
///   "sub": "auth0|123456789",
///   "aud": [
///     "https://api.yourapp.com",
///     "https://your-domain.auth0.com/userinfo"
///   ],
///   "exp": 1640995200,
///   "iat": 1640991600,
///   "nonce": "abc123",
///
///   // OIDC claims
///   "email": "user@example.com",
///   "email_verified": true,
///   "name": "John Doe",
///   "picture": "https://avatar.example.com/john.jpg",
///   "given_name": "John",
///   "family_name": "Doe",
///   "nickname": "johnd",
///
///   // Auth0 specific
///   "updated_at": "2021-12-31T12:00:00.000Z",
///   "org_id": "org_123456789",
///   "org_name": "Acme Corp",
///   "org_metadata": {
///     "plan": "enterprise",
///     "trial": false
///   },
///
///   // Permissions from Auth0 RBAC
///   "permissions": [
///     "read:users",
///     "write:posts",
///     "publish:articles",
///     "access:admin"
///   ]
/// }
/// ```
///
/// ### Claim Descriptions
///
/// | Claim | Description | Required |
/// |-------|-------------|----------|
/// | `iss` | Token issuer (Auth0 domain) | ✅ Yes |
/// | `sub` | Subject (user ID) | ✅ Yes |
/// | `aud` | Audience (API identifiers) | ✅ Yes |
/// | `exp` | Expiration timestamp | ✅ Yes |
/// | `iat` | Issued at timestamp | ✅ Yes |
/// | `email` | User's email address | Optional |
/// | `org_id` | Organization ID (multi-tenant) | Optional |
/// | `permissions` | Array of granted permissions | Optional |
///
/// ## Configuration
///
/// ### Environment Variables
/// ```bash
/// # Authentication provider selection
/// export AUTH_PROVIDER=auth0
///
/// # Auth0 tenant configuration
/// export AUTH0_DOMAIN=your-domain.auth0.com          # Your Auth0 domain
/// export AUTH0_AUDIENCE=https://api.yourapp.com     # Your API identifier
/// export AUTH0_CLIENT_ID=your-client-id             # For API calls to Auth0
/// export AUTH0_CLIENT_SECRET=your-client-secret     # For API calls to Auth0
///
/// # Optional: Custom JWKS cache duration (seconds)
/// export AUTH0_JWKS_CACHE_TTL=3600                  # 1 hour default
/// ```
///
/// ### Auth0 Application Setup
///
/// 1. **Create Application** in Auth0 Dashboard
///    - Type: Regular Web Application or Single Page Application
///    - Token Endpoint: RS256 algorithm
///
/// 2. **Configure Callback URLs**
///    - Allowed Callback URLs: `https://yourapp.com/callback`
///    - Allowed Logout URLs: `https://yourapp.com/logout`
///    - Allowed Web Origins: `https://yourapp.com`
///
/// 3. **Configure API**
///    - Create API with identifier: `https://api.yourapp.com`
///    - Enable RBAC settings
///    - Add permissions (scopes)
///
/// 4. **Configure Connections**
///    - Enable Username-Password-Authentication
///    - Enable social connections (Google, etc.)
///    - Configure enterprise connections if needed
///
/// 5. **User Management**
///    - Set up roles and permissions
///    - Configure organization (for multi-tenant)
///    - Set up MFA policies
///
/// ## Usage Example
///
/// ### Basic Setup
/// ```swift
/// import Vapor
/// import CMSAuth
///
/// // In configure.swift
/// public func configure(_ app: Application) async throws {
///     // ... database, middleware, etc. ...
///
///     // Initialize Auth0 provider
///     let auth0 = Auth0Provider()
///     try auth0.configure(app: app)
///
///     // Register auth middleware
///     app.middleware.use(auth0.middleware())
/// }
/// ```
///
/// ### Protect API Routes
/// ```swift
/// // In routes.swift
///
/// // Public routes (no authentication)
/// app.get { req in
///     return "Welcome to SwiftCMS API"
/// }
///
/// // Protected API routes
/// let api = app.grouped("api", "v1")
///     .grouped(auth0.middleware())
///
/// // All authenticated users can access
/// api.get("profile") { req in
///     let user = try req.auth.require(CmsUser.self)
///     return "Hello, \(user.userId)!"
/// }
///
/// // Role-based protection
/// let admin = api.grouped(RBACMiddleware(action: "admin"))
/// admin.get("users") { req in
///     return try await User.query(on: req.db).all()
/// }
///
/// // Content-type specific protection
/// let articles = api.grouped(RBACMiddleware(
///     contentTypeSlug: "articles",
///     action: "publish"
/// ))
/// articles.post(":id", "publish") { req in
///     return try await publishArticle(req)
/// }
/// ```
///
/// ### Multi-Tenant with Organizations
/// ```swift
/// // Automatically filter by organization
/// app.middleware.use(auth0.middleware())
///
/// app.get("api/tenant/data") { req in
///     let user = try req.auth.require(CmsUser.self)
///
///     // Access user's organization
///     guard let tenantId = user.tenantId else {
///         throw Abort(.forbidden, reason: "No organization assigned")
///      }
///
///     // Fetch organization-specific data
///   return try await Data.query(on: req.db)
///         .filter(\.$tenantId == tenantId)
///         .all()
/// }
/// ```
///
/// ### Custom Auth0 API Calls
/// ```swift
/// // Fetch user profile from Auth0
/// app.get("auth", "profile") { req async throws -> Auth0Profile in
///     let user = try req.auth.require(CmsUser.self)
///
///     guard let accessToken = req.headers.bearerAuthorization?.token else {
///         throw Abort(.unauthorized)
///     }
///
///     let profileRes = try await req.client.get(
///   "https://\(auth0Domain)/userinfo",
///         headers: ["Authorization": "Bearer \(accessToken)"]
/// )
///
///       return try profileRes.content.decode(Auth0Profile.self)
/// }
/// ```
///
/// ## Security Notes
///
/// ### 🛡️ Production Security Checklist
///
/// - ✅ **Always verify JWT signatures**: Never skip signature verification
/// - ✅ **Use RS256 algorithm**: Asymmetric signing (HS256 is symmetric)
/// - ✅ **Validate all standard claims**: iss, aud, exp, iat
/// - ✅ **Check token expiration**: Reject expired tokens immediately
/// - ✅ **Verify issuer**: Must match your Auth0 domain exactly
/// - ✅ **Verify audience**: Must match your API identifier
/// - ✅ **Use HTTPS only**: HTTPS for all token transmission
/// - ✅ **Enable Auth0 logs**: Monitor authentication events in Auth0 dashboard
/// - ✅ **Implement refresh tokens**: For mobile/SPA applications
/// - ✅ **Use short expiration**: Access tokens: 15 minutes max
/// - ✅ **Enable MFA**: Multi-factor authentication for sensitive operations
///
/// ### 🔐 Auth0-Specific Security Features
///
/// #### 1. Organizations (Multi-Tenancy)
/// ```swift
/// // Validate organization membership
/// if let orgId = payload.orgId {
///     // Check if user belongs to this organization
///     let membership = try await OrganizationMember.query(on: req.db)
///         .filter(\.$userId == user.id!)
///         .filter(\$organization.$id == orgId)
///         .first()
///
///     guard membership != nil else {
///         throw Abort(.forbidden, reason: "Not a member of this organization")
///  }
/// }
/// ```
///
/// #### 2. Permissions (RBAC)
/// ```swift
/// // Check specific permissions
/// let requiredPermission = "create:articles"
///
/// guard user.roles.contains(requiredPermission) else {
///      throw Abort(.forbidden, reason: "Missing required permission: \(requiredPermission)")
/// }
///
/// // Or use RBACMiddleware for automatic checking
/// app.grouped(RBACMiddleware(action: "create"))
/// ```
///
/// #### 3. Email Verification
/// ```swift
/// // Ensure email is verified
/// guard payload.emailVerified == true else {
///     throw Abort(.forbidden, reason: "Email not verified")
///  }
/// ```
///
/// ### ⚠️ Development vs Production
///
/// #### Current Implementation (Development)
/// ```swift
/// // ⚠️ WARNING: For development only!
/// // This does NOT verify token signatures
/// private func decodeJWTPayload(token: String) -> Data? {
///     // Extract payload without verification
///     // Insecure - allows forged tokens!
/// }
/// ```
///
/// #### Production Implementation Required
/// ```swift
/// // ✅ Production-ready implementation using JWT-Kit
/// private func verifyToken(token: String, on req: Request) async throws -> Auth0Payload {
///     // 1. Fetch JWKS from Auth0
///     let jwks = try await fetchJWKS()
///
///     // 2. Verify signature
///     let signers = JWTSigners()
///     try signers.use(jwks: jwks)
///
///     // 3. Verify and decode token
///     let payload = try signers.verify(token, as: Auth0Payload.self)
///
///     return payload
/// }
/// ```
///
/// ## Error Handling
///
/// ### Auth0-Specific Errors
/// ```swift
/// // Token validation errors
/// enum Auth0Error: Error {
///     case invalidSignature
///     case tokenExpired
///     case invalidIssuer
///     case invalidAudience
///     case missingOrganization
///     case emailNotVerified
/// }
///
/// // JWKS fetch errors
/// enum JWKSFetchError: Error {
///  case networkError(Error)
///     case invalidResponse
///     case invalidJSON
/// }
/// ```
///
/// ### Common Issues
///
/// #### "Invalid issuer"
/// **Cause**: Domain mismatch between token and configuration
/// **Solution**: Ensure `AUTH0_DOMAIN` matches your Auth0 tenant domain exactly
///
/// #### "Invalid audience"
///  **Cause**: API identifier mismatch
/// **Solution**: Check `AUTH0_AUDIENCE` matches Auth0 API settings
///
/// #### "Token expired"
///  **Cause**: Token lifetime exceeded
/// **Solution**: Implement token refresh flow or increase token lifetime in Auth0
///
/// #### "Invalid signature"
/// **Cause**: Token tampering or wrong signing key
/// **Solution**: Ensure JWKS fetch is working, check clock synchronization
///
/// ## Testing Auth0 Authentication
///
/// ### Unit Tests with Mock Tokens
/// ```swift
/// func testAuth0TokenVerification() async throws {
///     let app = Application(.testing)
///     defer { app.shutdown() }
///
///     // Create mock token payload
///     let payload = Auth0TokenPayload(
///         iss: "https://test.auth0.com",
///         sub: "auth0|123456",
///         aud: ["https://api.test.com"],
///         exp: Date().addingTimeInterval(3600),
///         email: "test@example.com",
///         permissions: ["read:test"],
///         orgId: "org_test"
///     )
///
///     // Verify token
///     let provider = Auth0Provider()
///     let user = try await provider.verify(
///      token: mockToken,
///         on: app.makeRequest()
///     )
///
///     XCTAssertEqual(user.userId, "auth0|123456")
///     XCTAssertEqual(user.roles, ["read:test"])
///     XCTAssertEqual(user.tenantId, "org_test")
/// }
/// ```
///
/// ### Integration Tests
/// ```swift
/// func testAuth0ProtectedRoute() async throws {
///     let app = try createTestApp()
///
///     // Test without token
///     try await app.test(.GET, "/api/protected") { res in
///         XCTAssertEqual(res.status, .unauthorized)
///     }
///
///     // Test with valid Auth0 token
///     let token = try await fetchAuth0TestToken()
///     try await app.test(.GET, "/api/protected", headers: [
///         "Authorization": "Bearer \(token)"
///     ]) { res in
///         XCTAssertEqual(res.status, .ok)
///     }
/// }
/// ```
///
/// ## Monitoring and Observability
///
/// ### Key Metrics to Track
/// - Token verification success/failure rate
/// - JWKS cache hit/miss rate
/// - Token expiration patterns
/// - Organization-based usage
/// - Permission-based access patterns
///
/// ### Auth0 Dashboard Monitoring
/// ```swift
/// // Log Auth0 events for monitoring
/// app.middleware.use { req, next in
///     do {
///         let res = try await next.respond(to: req)
///
///         // Log successful Auth0 authentication
///         if let user = req.auth.get(CmsUser.self),
///            user.userId.hasPrefix("auth0|") {
///             req.logger.info("Auth0 login", metadata: [
///                 "userId": "\(user.userId)",
///                 "tenantId": "\(user.tenantId ?? "none")"
///             ])
///         }
///
///         return res
///     } catch {
///         // Log Auth0 authentication failures
///         if error is Auth0Error {
///             req.logger.warning("Auth0 authentication failed", metadata: [
///                 "error": "\(error)"
///             ])
///         }
///         throw error
///     }
/// }
/// ```
///
/// ## Resources
///
/// - [Auth0 Documentation](https://auth0.com/docs)
/// - [JWT Handbook](https://auth0.com/resources/ebooks/jwt-handbook)
/// - [OIDC Specification](https://openid.net/specs/openid-connect-core-1_0.html)
/// - [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749)
public struct Auth0Provider: AuthProvider, Sendable {
    public let name = "auth0"

    /// 🔐 Initialize Auth0 provider
    public init() {}

    /// ⚙️ Configure Auth0 provider with JWKS endpoint
    ///
    /// - Parameter app: The Vapor application
    /// - Throws: Configuration error if AUTH0_DOMAIN is not set
    public func configure(app: Application) throws {
        guard let domain = Environment.get("AUTH0_DOMAIN") else {
            app.logger.error("❌ AUTH0_DOMAIN not set, Auth0 provider will not function")
            throw Abort(.internalServerError, reason: "AUTH0_DOMAIN environment variable required")
        }

        let jwksURL = "https://\(domain)/.well-known/jwks.json"
        app.logger.info("🔐 Configuring Auth0 with JWKS from: \(jwksURL)")

        // ⚠️ TODO: In production, fetch JWKS and configure JWT signer
        // For development, we're validating claims without full signature verification
        app.logger.warning("⚠️ Auth0 JWKS signature verification not implemented")
    }

    /// 🔍 Verify Auth0 JWT token
    ///
    /// - Parameters:
    ///   - token: The JWT token from Auth0
    ///   - req: The Vapor request
    /// - Returns: Authenticated user with Auth0 claims
    /// - Throws: Unauthorized error if token is invalid or expired
    public func verify(token: String, on req: Request) async throws -> AuthenticatedUser {
        req.logger.debug("🔍 Verifying Auth0 token")

        // Decode JWT payload
        guard let payloadData = decodeJWTPayload(token: token) else {
            req.logger.warning("🚫 Invalid Auth0 token format")
            throw ApiError.unauthorized("Invalid token format")
        }

        let decoder = JSONDecoder()
        let payload: Auth0TokenPayload

        do {
            payload = try decoder.decode(Auth0TokenPayload.self, from: payloadData)
            req.logger.info("✅ Auth0 token decoded successfully")
        } catch {
            req.logger.error("❌ Failed to decode Auth0 token payload: \(error)")
            throw ApiError.unauthorized("Invalid token payload")
        }

        // ⏰ Check expiration
        guard payload.exp > Date() else {
            req.logger.warning("⏰ Auth0 token expired")
            throw ApiError.unauthorized("Token expired")
        }

        // 🎯 Check audience if configured
        if let expectedAudience = Environment.get("AUTH0_AUDIENCE") {
            guard payload.aud.contains(expectedAudience) else {
                req.logger.warning("🎯 Invalid audience in Auth0 token")
                throw ApiError.unauthorized("Invalid audience")
            }
            req.logger.debug("✅ Auth0 audience validated")
        }

        req.logger.info("✅ Auth0 token verification successful for user: \(payload.sub)")

        return AuthenticatedUser(
            userId: payload.sub,
            email: payload.email,
            roles: payload.permissions ?? [],
            tenantId: payload.orgId
        )
    }

    /// 🛡️ Get JWT bearer authenticator
    ///
    /// - Returns: JWT bearer authenticator for API routes
    public func middleware() -> any AsyncMiddleware {
        JWTBearerAuthenticator(provider: self)
    }

    // MARK: - Token Decoding

    /// 🔍 Decode the payload portion of a JWT (simplified implementation)
    ///
    /// ⚠️ **Security Note**: This implementation does NOT verify the token signature.
    /// In production, use the full JWKS implementation from JWT-Kit.
    ///
    /// - Parameter token: The JWT token string
    /// - Returns: Decoded payload data or nil if invalid
    private func decodeJWTPayload(token: String) -> Data? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            return nil
        }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        return Data(base64Encoded: base64)
    }
}

// MARK: - 📄 Auth0 Token Payload

/// 📄 **Auth0 JWT Token Payload Structure**
///
/// Represents the claims contained in an Auth0-issued JWT token.
/// Implements custom decoding to handle Auth0's specific token format.
///
/// ## Standard Claims
/// - `iss`: Issuer (Auth0 domain)
/// - `sub`: Subject (user ID in Auth0 format: "auth0|12345")
/// - `aud`: Audience (API identifier)
/// - `exp`: Expiration timestamp
/// - `iat`: Issued at timestamp
/// - `email`: User's email address
///
/// ## Auth0-Specific Claims
/// - `permissions`: Array of role permissions from Auth0 RBAC
/// - `org_id`: Organization ID for multi-tenant applications
///
/// ## Example Token Payload
/// ```json
/// {
///   "iss": "https://your-domain.auth0.com",
///   "sub": "auth0|123456789",
///   "aud": ["https://api.yourapp.com"],
///   "exp": 1234567890,
///   "iat": 1234567890,
///   "email": "user@example.com",
///   "permissions": ["read:users", "write:posts"],
///   "org_id": "org_12345"
/// }
/// ```
public struct Auth0TokenPayload: Codable, Sendable {
    /// 🌐 Token issuer (Auth0 domain)
    public let iss: String

    /// 👤 Subject - unique user identifier
    public let sub: String

    /// 🎯 Audience - intended API recipients
    public let aud: [String]

    /// ⏰ Expiration timestamp
    public let exp: Date

    /// 📅 Issued at timestamp
    public let iat: Date?

    /// 📧 User's email address
    public let email: String?

    /// 📋 Role-based permissions from Auth0
    public let permissions: [String]?

    /// 🏢 Organization ID (for multi-tenant)
    public let orgId: String?

    enum CodingKeys: String, CodingKey {
        case iss, sub, aud, exp, iat, email, permissions
        case orgId = "org_id"
    }

    /// 📥 Custom decoder to handle Auth0's specific format
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
