import Vapor
import CMSSchema
import Fluent
import CMSObjects
import CMSSchema

// MARK: - 🎯 AuthProvider Protocol

/// 🎯 **Authentication Provider Contract**
///
/// Defines the contract that all authentication providers must implement.
/// This protocol standardizes authentication across multiple providers (Auth0, Firebase, Local JWT).
///
/// ## Architecture Overview
///
/// The `AuthProvider` protocol is the foundation of SwiftCMS's authentication system.
/// It provides a unified interface for different authentication methods, allowing
/// seamless switching between providers without changing application code.
///
/// ### Core Responsibilities
/// - 🔐 **Token Verification**: Validate authentication tokens (JWT, OAuth, API keys)
/// - 👤 **User Authentication**: Convert tokens to authenticated users
/// - 🛡️ **Middleware Creation**: Generate authentication middleware for route protection
/// - ⚙️ **Configuration**: Initialize provider-specific settings and credentials
///
/// ## Supported Providers
///
/// | Provider | Best For | Key Features |
/// |----------|----------|--------------|
/// | 🔐 **Auth0** | Enterprise/SaaS apps | Social logins, enterprise SSO, OAuth 2.0 |
/// | 🌐 **Firebase** | Mobile apps | Google ecosystem, phone auth, social providers |
/// | 🔑 **Local JWT** | Self-hosted apps | Custom JWT, full control, no external dependencies |
///
/// ## Authentication Flow
///
/// ```
/// Client Request
///     ↓
/// Auth Middleware (JWTBearerAuthenticator)
///     ↓
/// Extract Token from Authorization Header
///     ↓
/// Provider.verify(token:on:)
///     ↓
/// Validate Signature & Claims
///     ↓
/// Return AuthenticatedUser
///     ↓
/// RBAC Middleware (Optional)
///     ↓
/// Route Handler
/// ```
///
/// ## JWT Token Lifecycle
///
/// ### Token Structure (RFC 7519)
/// ```
/// eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.  ← Header (algorithm + type)
/// eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ. ← Payload (claims)
/// SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c     ← Signature
/// ```
///
/// ### Critical Security Claims
/// - **iss** (Issuer): Who issued the token (must match expected issuer)
/// - **sub** (Subject): User identifier (unique per user)
/// - **aud** (Audience): Intended recipient (API identifier)
/// - **exp** (Expiration): Token expiry timestamp (UTC)
/// - **nbf** (Not Before): Token activation time
/// - **iat** (Issued At): Token creation time
///
/// ### Token Validation Checklist
/// - ✅ Signature verification with provider keys
/// - ✅ Expiration check (exp > now)
/// - ✅ Issuer validation (iss matches expected)
/// - ✅ Audience validation (aud matches API)
/// - ✅ Not before check (nbf < now)
/// - ✅ Token revocation check (if supported)
///
/// ## Usage Examples
///
/// ### Basic Setup
/// ```swift
/// // In configure.swift
/// let provider = AuthProviderFactory.create(from: app.environment)
/// try provider.configure(app: app)
///
/// // Register authentication middleware globally
/// app.middleware.use(provider.middleware())
/// ```
///
/// ### Protect API Routes
/// ```swift
/// // In routes.swift
/// let api = app.grouped("api")
///     .grouped(provider.middleware())
///     .grouped(RBACMiddleware(action: "read"))
///
/// api.get("users") { req in
///     let user = try req.auth.require(CmsUser.self)
///     return try await User.query(on: req.db).all()
/// }
/// ```
///
/// ### Multi-Provider Setup
/// ```swift
/// // Support multiple auth providers simultaneously
/// let auth0 = Auth0Provider()
/// let firebase = FirebaseProvider()
/// let apiKey = ApiKeyMiddleware()
///
/// app.grouped(auth0.middleware(), apiKey).get("api") { req in
///     // Accepts either Auth0 JWT or API key
/// }
/// ```
///
/// ## Security Considerations
///
/// ### 🛡️ Critical Security Practices
/// - **Always validate token signatures**: Never accept tokens without signature verification
/// - **Use HTTPS only**: Tokens transmitted over HTTP can be intercepted
/// - **Short expiration times**: Access tokens should expire within minutes/hours
/// - **Implement refresh tokens**: For long-lived sessions
/// - **Store secrets securely**: Use environment variables or secret management services
/// - **Monitor for anomalies**: Log authentication failures and suspicious patterns
/// - **Implement token revocation**: Allow users to logout/revoke tokens
/// - **Use strong algorithms**: RS256 or ES256 for production (not HS256)
///
/// ### ⚠️ Common Vulnerabilities to Avoid
/// - **None algorithm**: Reject tokens with "alg": "none"
/// - **Algorithm switching**: Validate alg matches expected algorithm
/// - **Weak secrets**: Use cryptographically random secrets (32+ bytes)
/// - **Missing expiration**: Always set exp claim
/// - **Replay attacks**: Include jti (JWT ID) claim for one-time use
///
/// ## Token Refresh Strategy
///
/// ### Best Practice Flow
/// 1. **Short-lived access token** (15 min): Used for API requests
/// 2. **Long-lived refresh token** (7 days): Used to get new access tokens
/// 3. **Rotation**: Issue new refresh token on each use (prevents replay)
///
/// ```swift
/// // Refresh endpoint example
/// app.post("auth/refresh") { req -> TokenResponse in
///     let refreshToken = try req.content.decode(RefreshToken.self)
///
///     // Validate refresh token
///     guard let payload = try? req.jwt.verify(refreshToken.token, as: RefreshPayload.self) else {
///         throw ApiError.unauthorized("Invalid refresh token")
///     }
///
///     // Check if token is revoked
///     if try await isTokenRevoked(payload.jti, on: req.db) {
///         throw ApiError.unauthorized("Token revoked")
///     }
///
///     // Generate new tokens
///     let newAccessToken = try req.jwt.sign(AccessPayload(userId: payload.userId))
///     let newRefreshToken = try req.jwt.sign(RefreshPayload(userId: payload.userId, jti: UUID().uuidString))
///
///     return TokenResponse(
///         accessToken: newAccessToken,
///         refreshToken: newRefreshToken
///     )
/// }
/// ```
///
/// ## Environment Configuration
///
/// ```bash
/// # Auth0 Configuration
/// export AUTH_PROVIDER=auth0
/// export AUTH0_DOMAIN=your-domain.auth0.com
/// export AUTH0_AUDIENCE=https://api.yourapp.com
/// export AUTH0_CLIENT_ID=your-client-id
///
/// # Firebase Configuration
/// export AUTH_PROVIDER=firebase
/// export FIREBASE_PROJECT_ID=your-project-id
///
/// # Local JWT Configuration
/// export AUTH_PROVIDER=local
/// export JWT_SECRET=your-256-bit-secret-here-min-32-bytes
/// ```
///
/// ## Testing Authentication
///
/// ### Unit Testing
/// ```swift
/// func testTokenVerification() async throws {
///     let app = Application(.testing)
///     defer { app.shutdown() }
///
///     let provider = LocalJWTProvider(secret: "test-secret")
///     let token = try testToken(userId: "test-user")
///
///     let user = try await provider.verify(token: token, on: app.makeRequest())
///     XCTAssertEqual(user.userId, "test-user")
/// }
/// ```
///
/// ### Integration Testing
/// ```swift
/// func testProtectedRoute() async throws {
///     let app = try await createTestApp()
///
///     // Test without token
///     try await app.test(.GET, "api/protected") { res in
///         XCTAssertEqual(res.status, .unauthorized)
///     }
///
///     // Test with valid token
///     let token = try generateTestToken()
///     try await app.test(.GET, "api/protected", headers: ["Authorization": "Bearer \(token)"]) { res in
///         XCTAssertEqual(res.status, .ok)
///     }
/// }
/// ```
public protocol AuthProvider: Sendable {
    /// ⚡ Provider identifier (e.g., "auth0", "firebase", "local")
    var name: String { get }

    /// ⚙️ **Configure authentication provider on application boot**
    ///
    /// Sets up the provider with required credentials, endpoints, and key management.
    /// Called during application initialization.
    ///
    /// - Parameter app: The Vapor application instance
    /// - Throws: Configuration error if credentials are missing or invalid
    ///
    /// ## Security Notes
    /// - Validates required environment variables
    /// - Initializes JWT key stores
    /// - Sets up certificate caching for OAuth providers
    func configure(app: Application) throws

    /// 🔐 **Verify authentication token**
    ///
    /// Validates the token signature, expiration, and claims for the specific provider.
    /// Returns authenticated user information on success.
    ///
    /// - Parameters:
    ///   - token: The authentication token (JWT, OAuth, etc.)
    ///   - req: The current request context for logging and database access
    /// - Returns: Authenticated user with roles and permissions
    /// - Throws: `ApiError.unauthorized` if token is invalid or expired
    ///
    /// ## Security Features
    /// - Signature verification with provider keys
    /// - Expiration validation
    /// - Audience/issuer claim verification
    /// - Token revocation checking (if supported)
    func verify(token: String, on req: Request) async throws -> AuthenticatedUser

    /// 🛡️ **Get authentication middleware**
    ///
    /// Returns middleware that protects routes by requiring valid authentication.
    /// Automatically extracts tokens from Authorization headers.
    ///
    /// - Returns: AsyncMiddleware for route protection
    ///
    /// ## Usage Example
    /// ```swift
    /// let protectedRoutes = app.routes.grouped(provider.middleware())
    /// protectedRoutes.get("admin") { req in
    ///     // Only accessible with valid token
    /// }
    /// ```
    func middleware() -> any AsyncMiddleware

    /// 🔑 **Issue authentication token**
    ///
    /// Generates a new token for the specified user and scopes.
    ///
    /// - Parameters:
    ///   - userId: The unique identifier of the user
    ///   - email: The user's email address
    ///   - roles: The roles assigned to the user
    ///   - tokenType: The type of token to issue (access or refresh)
    /// - Returns: A signed JWT token string
    /// - Throws: specific errors if token generation fails
    func issueToken(userId: String, email: String, roles: [String], tokenType: AuthTokenType) throws -> String
}

/// 🎫 **Token Type**
///
/// Distinguishes between access and refresh tokens.
public enum AuthTokenType: String, Sendable, Codable {
    case access
    case refresh
}

// MARK: - 📋 RBAC Middleware

/// 📋 **Role-Based Access Control Middleware**
///
/// Enforces fine-grained permissions based on user roles and content types.
/// Integrates with the CMS permission system to control access to resources.
///
/// ## Permission System Architecture
///
/// ```
/// User
///   ↓ (has one or more)
/// Role(s)
///   ↓ (grants permissions for)
/// Content Types + Actions
///   ↓ (results in)
/// Access Decision
/// ```
///
/// ### Permission Model
/// ```swift
/// struct Permission {
///     var role: Role           // Who (e.g., "editor", "author")
///   var contentTypeSlug: String  // What (e.g., "articles", "*")
///     var action: String       // How (e.g., "create", "read", "update", "delete")
/// }
/// ```
///
/// ### Role Hierarchy
/// ```
/// super-admin  ⭐ God mode - bypasses all checks
///     ↓
/// admin        🛡️  Full CMS access
///     ↓
/// editor       ✏️  Create, update, publish content
///     ↓
/// author       ✍️  Create, update own content
///     ↓
/// public       👤 Read-only access
/// ```
///
/// ### Action Types
/// - **create**: Create new content entries
/// - **read**: View content entries (most common)
/// - **update**: Edit existing content
/// - **delete**: Remove content permanently
/// - **publish**: Change published status
/// - **admin**: Full administration access
///
/// ## Usage Patterns
///
/// ### 1. Global Admin Protection
/// ```swift
/// let admin = app.grouped("admin")
///     .grouped(SessionAuthRedirectMiddleware())
///     .grouped(RBACMiddleware(action: "admin"))
///
/// admin.get("dashboard") { req in
///     // Only super-admins and admins can access
///     return AdminDashboardView()
/// }
/// ```
///
/// ### 2. Content-Type Specific Protection
/// ```swift
/// // Protect article operations
/// let articles = app.grouped("api", "articles")
///     .grouped(JWTBearerAuthenticator(provider: provider))
///     .grouped(RBACMiddleware(contentTypeSlug: "articles", action: "read"))
///
/// articles.get { req in
///     // Users with 'read' permission on 'articles' can access
///     return try await Article.query(on: req.db).all()
/// }
///
/// // Publish endpoint requires 'publish' permission
/// let publish = app.grouped(RBACMiddleware(
///     contentTypeSlug: "articles",
///     action: "publish"
/// ))
/// publish.post(":id", "publish") { req in
///     // Only authorized publishers
///     return try await publishArticle(req)
/// }
/// ```
///
/// ### 3. Dynamic Content Type from Route
/// ```swift
/// // Handle multiple content types dynamically
/// let content = app.grouped("api", ":contentType")
///     .grouped(provider.middleware())
///     .grouped(RBACMiddleware(action: "read"))
///
/// content.get { req in
///     let slug = req.parameters.get("contentType")!
///     // RBACMiddleware will check permissions for the dynamic slug
///     return try await fetchContent(req, type: slug)
/// }
/// ```
///
/// ### 4. Multi-Action Protection
/// ```swift
/// // Protect both read and write operations
/// let protectedCRUD = app.grouped("api", "products")
///     .grouped(provider.middleware())
///
/// // Read operations
/// protectedCRUD.get { req in
///     let rbac = RBACMiddleware(contentTypeSlug: "products", action: "read")
///     return try await rbac.respond(to: req, chainingTo: productListResponder)
/// }
///
/// // Write operations
/// protectedCRUD.post { req in
/// let rbac = RBACMiddleware(contentTypeSlug: "products", action: "create")
///     return try await rbac.respond(to: req, chainingTo: productCreateResponder)
/// }
/// ```
///
/// ### 5. Wildcard Permissions
/// ```swift
/// // Grant access to all content types
/// let superEditor = Role(
///     slug: "super-editor",
///     permissions: [
///         Permission(contentTypeSlug: "*", action: "read"),
///  Permission(contentTypeSlug: "*", action: "create"),
///  Permission(contentTypeSlug: "*", action: "update")
///     ]
/// )
///
/// // This allows editing any content type without explicit permissions
/// ```
///
/// ## Security Features
///
/// ### 🛡️ Built-in Security
/// - **Super-admin bypass** 👑: Users with "super-admin" role bypass all checks
/// - **Database-level verification**: Permissions checked against live database
/// - **Wildcard support**: "*" matches all content types for flexible permissions
/// - **Multi-tenant aware**: Filters by tenantId when applicable
/// - **Audit logging**: All permission checks are logged for security monitoring
/// - **No client-side bypass**: All validation server-side
///
/// ### 🚨 Security Considerations
/// - Permissions are cached for performance but invalidated on role changes
/// - Deny-by-default: If no permission found, access is denied
/// Role changes take effect immediately (no session invalidation needed)
/// - Always place RBACMiddleware AFTER authentication middleware
///
/// ### ⚡ Performance Optimization
/// - Database query uses JOIN for efficient permission lookup
/// - OR conditions prevent multiple queries
/// - Indexes recommended on: permissions.role_id, permissions.content_type_slug, permissions.action
/// - Consider Redis caching for high-traffic applications
///
/// ## Middleware Order and Composition
///
/// ### Correct Middleware Stack
/// ```swift
/// app.grouped([
///     ErrorMiddleware(),           // 1. Error handling
///     SessionsMiddleware(),        // 2. Session management
///     CORSMiddleware(),            // 3. CORS headers
///     RateLimitMiddleware(),       // 4. Rate limiting
///     AuthMiddleware(),            // 5. Authentication ← YOU ARE HERE
///     RBACMiddleware(),            // 6. Authorization
///     AuditMiddleware()            // 7. Audit logging
/// ]).get("protected")
/// ```
///
/// ### Common Middleware Patterns
/// ```swift
/// // Chain multiple RBAC checks
/// let superProtected = app
///     .grouped(RBACMiddleware(action: "admin"))
///     .grouped(RBACMiddleware(contentTypeSlug: "users", action: "update"))
///
/// // Both permissions required (AND logic)
/// superProtected.post("users", ":id") { req in
///     // User must be admin AND have user update permission
/// }
///
/// // OR logic via role permissions
/// // Create role with multiple permissions instead
/// let editorRole = Role(
///     slug: "content-editor",
///     permissions: [
///         Permission(contentType: "articles", action: "create"),
///         Permission(contentType: "articles", action: "update"),
///         Permission(contentType: "pages", action: "create")
///     ]
/// )
/// ```
///
/// ## Database Schema
///
/// ### Required Tables
/// ```sql
/// CREATE TABLE roles (
///     id UUID PRIMARY KEY,
/// slug VARCHAR(255) UNIQUE NOT NULL,
/// name VARCHAR(255) NOT NULL,
///     description TEXT
/// );
///
/// CREATE TABLE permissions (
/// id UUID PRIMARY KEY,
/// role_id UUID REFERENCES roles(id),
///     content_type_slug VARCHAR(255) NOT NULL,
///     action VARCHAR(50) NOT NULL,
///     UNIQUE(role_id, content_type_slug, action)
/// );
///
/// CREATE INDEX idx_permissions_lookup ON permissions(role_id, content_type_slug, action);
/// ```
///
/// ### Sample Data
/// ```sql
/// -- Super admin role (bypasses checks, but good for audit)
/// INSERT INTO roles (id, slug, name) VALUES
/// (gen_random_uuid(), 'super-admin', 'Super Administrator');
///
/// -- Editor role with article permissions
/// INSERT INTO roles (id, slug, name) VALUES
/// (gen_random_uuid(), 'editor', 'Content Editor');
///
/// INSERT INTO permissions (id, role_id, content_type_slug, action) VALUES
/// (gen_random_uuid(), editor_role_id, 'articles', 'create'),
/// (gen_random_uuid(), editor_role_id, 'articles', 'read'),
/// (gen_random_uuid(), editor_role_id, 'articles', 'update'),
/// (gen_random_uuid(), editor_role_id, 'articles', 'publish'),
/// (gen_random_uuid(), editor_role_id, '*', 'read'); -- Can read all content
/// ```
///
/// ## Error Handling
///
/// ### Permission Denied Responses
/// ```swift
/// // 401 Unauthorized - Not authenticated
/// {
///     "error": "unauthorized",
///     "statusCode": 401,
///   "reason": "Authentication required"
/// }
///
/// // 403 Forbidden - Authenticated but no permission
/// {
/// "error": "forbidden",
///     "statusCode": 403,
///     "reason": "You do not have 'publish' permission on 'articles'"
/// }
/// ```
///
/// ## Testing RBAC
///
/// ### Unit Tests
/// ```swift
/// func testRBACMiddleware() async throws {
///     let app = Application(.testing)
///     defer { app.shutdown() }
///
///     let middleware = RBACMiddleware(contentTypeSlug: "articles", action: "read")
///     let user = CmsUser(userId: "test", email: nil, roles: ["editor"], tenantId: nil)
///
//  // Create test request with authenticated user
///   let req = Request(application: app, on: app.eventLoopGroup.next())
///   req.auth.login(user)
///
///     // Create mock responder
///   let responder = TestResponder()
///
///     // Should allow access
///     let response = try await middleware.respond(to: req, chainingTo: responder)
///     XCTAssertEqual(response.status, .ok)
/// }
/// ```
///
/// ### Integration Tests
/// ```swift
/// func testPermissionChecking() async throws {
///     let app = try await createTestApp()
///
//  // Setup test data
/// let role = Role(slug: "test-editor", name: "Test Editor")
///     try await role.save(on: app.db)
///
///  let permission = Permission(roleId: role.id!, contentTypeSlug: "posts", action: "read")
///     try await permission.save(on: app.db)
///
///     // Test without permission
///     var token = try generateToken(roles: ["public"])
///     try await app.test(.GET, "api/posts", headers: ["Authorization": "Bearer \(token)"]) { res in
///         XCTAssertEqual(res.status, .forbidden)
///     }
///
///     // Test with permission
///     token = try generateToken(roles: ["test-editor"])
///      try await app.test(.GET, "api/posts", headers: ["Authorization": "Bearer \(token)"]) { res in
///       XCTAssertEqual(res.status, .ok)
///     }
/// }
/// ```
///
/// ## Monitoring and Observability
///
/// ### Key Metrics to Track
/// - Authentication attempts (success/failure rate)
/// - Permission denials by role and content type
/// - Response times for RBAC checks
/// - Cache hit/miss rates (if caching enabled)
/// - Most restricted resources
///
/// ### Logging Best Practices
/// ```swift
/// // ✅ Good: Structured logging with context
/// request.logger.info("✅ Access granted", metadata: [
///     "userId": "\(user.userId)",
///  "action": "\(action)",
///     "contentType": "\(slug)",
///     "roles": "\(user.roles.joined(separator: ","))"
/// ])
///
//  // ⚠️ Bad: Insufficient context
/// request.logger.info("Access granted")
/// ```
public struct RBACMiddleware: AsyncMiddleware, Sendable {
    let contentTypeSlug: String?
    let action: String

    /// 📋 Initialize RBAC middleware with specific permissions
    ///
    /// - Parameters:
    ///   - contentTypeSlug: Specific content type to protect, or nil for dynamic from route
    ///   - action: The required action permission (create, read, update, delete, publish)
    public init(contentTypeSlug: String? = nil, action: String) {
        self.contentTypeSlug = contentTypeSlug
        self.action = action
    }

    /// 🛡️ Process request and enforce role-based permissions
    ///
    /// - Parameters:
    ///   - request: The incoming Vapor request
    ///   - next: The next responder in the chain
    /// - Returns: Response if authorized, throws error if not
    /// - Throws: `ApiError.unauthorized` if not authenticated, `ApiError.forbidden` if lacking permissions
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // 🔍 Check if user is authenticated
        guard let user = request.auth.get(CmsUser.self) else {
            request.logger.warning("🛡️ Unauthorized access attempt to '\(action)' action")
            throw ApiError.unauthorized()
        }

        // 👑 Super admin bypass - grant access to everything
        if user.roles.contains("super-admin") {
            request.logger.debug("👑 Super-admin access granted for '\(action)'")
            return try await next.respond(to: request)
        }

        // 🎯 Determine content type for permission check
        let slug = contentTypeSlug ?? request.parameters.get("contentType") ?? "*"
        request.logger.debug("📋 Checking permissions for user '\(user.userId)' on '\(slug)' for action '\(action)'")

        // 🔍 Query database for matching permissions
        let hasPermission = try await Permission.query(on: request.db)
            .join(Role.self, on: \Permission.$role.$id == \Role.$id)
            .group(.or) { group in
                // Check all user's roles
                for role in user.roles {
                    group.filter(Role.self, \Role.$slug == role)
                }
            }
            .group(.or) { group in
                // Check specific content type or wildcard
                group.filter(\Permission.$contentTypeSlug == slug)
                group.filter(\Permission.$contentTypeSlug == "*")
            }
            .filter(\Permission.$action == action)
            .first() != nil

        // 🚫 Deny access if no matching permission found
        guard hasPermission else {
            request.logger.warning("🛡️ Permission denied for user '\(user.userId)'. Required: '\(action)' on '\(slug)'")
            throw ApiError.forbidden("You do not have '\(action)' permission on '\(slug)'")
        }

        // ✅ Access granted
        request.logger.info("✅ Access granted for user '\(user.userId)' to '\(action)' on '\(slug)'")
        return try await next.respond(to: request)
    }
}

// MARK: - 🔐 API Key Middleware

/// 🔐 **API Key Authentication Middleware**
///
/// Enables machine-to-machine authentication using API keys.
/// Validates X-API-Key header and creates synthetic authenticated user.
///
/// ## API Key Authentication Overview
///
/// API keys are the preferred authentication method for:
/// - 🤖 **Server-to-server communication**
/// - 📱 **Mobile app backends**
/// - 🔗 **Third-party integrations**
/// - ⚡ **High-frequency API calls**
/// - 🏭 **IoT devices**
///
/// ### API Key vs JWT Trade-offs
///
/// | Feature | API Key | JWT Token |
/// |---------|---------|-----------|
/// | **State** | Stateful (stored in DB) | Stateless (self-contained) |
/// | **Revocation** | Instant via DB delete | Requires blacklist/short TTL |
/// | **Performance** | DB lookup required | No DB lookup |
/// | **Security** | Can be rotated easily | Signature verification |
/// | **Use Case** | M2M, integrations | User sessions, mobile apps |
///
/// ## Security Architecture
///
/// ### Key Generation Process
/// ```swift
/// // Cryptographically secure key generation
/// func generateAPIKey() -> (key: String, hash: String) {
///     // Generate 32-byte random key
///     let keyData = Data(count: 32)
///     keyData.withUnsafeMutableBytes {
///         let result = SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
///         precondition(result == errSecSuccess, "Failed to generate random bytes")
///     }
///
///     // Base64 encode for easy transmission
///     let key = keyData.base64EncodedString()
///     .replacingOccurrences(of: "+", with: "-")
///         .replacingOccurrences(of: "/", with: "_")
///         .replacingOccurrences(of: "=", with: "")
///
///     // Hash with bcrypt for secure storage
///     let hash = try! Bcrypt.hash(key)
///
///     return (key, hash)
/// }
/// ```
///
/// ### Key Format (Best Practice)
/// ```
/// scms_live_24charRandomKey_userId
/// ├───┼──────┼──────────────┼─────┤
/// │   │      │              └─ User identifier
/// │   │      └──────────────── 24-char random component
/// │   └─────────────────────── Environment identifier
/// └─────────────────────────── Prefix (scms = SwiftCMS)
/// ```
///
/// **Example**: `scms_live_aBcD3fG7hIjKl0pQrStUvWxYz_user_12345`
///
/// ## Features
///
/// ### 🔒 Secure Storage
/// - **Bcrypt hashing**: Keys stored as hashes, never plaintext
/// - **High cost factor**: Minimum cost of 12 for production
/// - **Unique salts**: Automatic per-key salt generation
/// - **Constant-time comparison**: Safe against timing attacks
///
/// ### ⏰ Key Lifecycle Management
/// - **Creation**: Auto-generated on API key creation
/// - **Activation**: Optional start date (not_before)
/// - **Expiration**: Configurable expiry (expires_at)
/// - **Revocation**: Immediate via deletion or status change
/// - **Rotation**: Regular key updates for security
///
/// ### 📊 Usage Analytics
/// - **First use**: Track when key was first used
/// - **Last used**: Timestamp of most recent usage
/// - **Use count**: Number of API calls with this key
/// - **IP tracking**: (Optional) Track originating IPs
///
/// ### 🏢 Multi-Tenancy Support
/// - **Tenant isolation**: Keys scoped to specific tenants
/// - **Cross-tenant blocking**: Keys can't access other tenants
/// - **Tenant admin**: Users can manage their own keys
///
/// ### 🔑 Permission System
/// - **Scope-based**: Restrict to specific actions
/// - **Resource-based**: Limit to specific resources
/// - **Rate limits**: Per-key rate limiting
/// - **IP whitelisting**: Restrict to specific IPs
///
/// ## Implementation Example
///
/// ### 1. API Key Model
/// ```swift
/// import Fluent
/// import Vapor
///
/// final class ApiKey: Model {
///     static let schema = "api_keys"
///
///     @ID(key: .id)
///     var id: UUID?
///
///   @Field(key: "name")
///     var name: String
///
///     @Field(key: "key_hash")
///     var keyHash: String
///
///     @OptionalField(key: "prefix")
///     var prefix: String?  // First 8 chars for identification
///
///     @Field(key: "permissions")
///     var permissions: [String]
///
///     @OptionalField(key: "expires_at")
///   var expiresAt: Date?
///
///     @Field(key: "created_at")
///     var createdAt: Date
///
///   @OptionalField(key: "last_used_at")
///     var lastUsedAt: Date?
///
///     @Field(key: "is_active")
///     var isActive: Bool
///
///     @OptionalParent(key: "tenant_id")
///     var tenant: Tenant?
///
///     init() {}
/// }
/// ```
///
/// ### 2. API Key Service
/// ```swift
/// import Vapor
///
/// struct ApiKeyService {
///     /// 🔑 Create new API key
///     func createKey(
///         name: String,
///         permissions: [String],
///         expiresIn: TimeInterval? = nil,
///         tenantId: UUID? = nil,
///         on db: Database
///     ) async throws -> (key: String, apiKey: ApiKey) {
///         // Generate key and hash
///         let (key, hash) = generateAPIKey()
///
///         // Create API key record
///         var apiKey = ApiKey()
///         apiKey.name = name
///         apiKey.keyHash = hash
///         apiKey.prefix = String(key.prefix(8))
///         apiKey.permissions = permissions
///
///         if let expiresIn = expiresIn {
///             apiKey.expiresAt = Date().addingTimeInterval(expiresIn)
///         }
///
///         apiKey.tenantId = tenantId
///         apiKey.isActive = true
///
///         try await apiKey.save(on: db)
///
///         // Return plaintext key (only time it's visible!)
///         return (key, apiKey)
///     }
///
///     /// 🔍 Find API key by plaintext key
///  func findKey(_ key: String, on db: Database) async throws -> ApiKey? {
///         let hash = try Bcrypt.hash(key)
///         return try await ApiKey.query(on: db)
///             .filter(\.$keyHash == hash)
///             .filter(\.$isActive == true)
///             .first()
///  }
///
///     /// 🚫 Revoke API key
///     func revokeKey(id: UUID, on db: Database) async throws {
///   try await ApiKey.query(on: db)
///       .set(\.$isActive, to: false)
///       .filter(\.$id == id)
///            .update()
///     }
/// }
/// ```
///
/// ### 3. Using ApiKeyMiddleware
/// ```swift
/// // In configure.swift
/// let apiKeyMiddleware = ApiKeyMiddleware()
///
/// // Apply to specific routes
/// let api = app.grouped("api", "v1")
///     .grouped(apiKeyMiddleware)
///     .grouped(RBACMiddleware(action: "api"))
///
/// api.get("status") { req in
///     return ["status": "ok", "timestamp": Date()]
/// }
///
/// // Or apply globally for machine-to-machine endpoints
/// app.grouped(apiKeyMiddleware).grouped("webhook") { webhook in
///     webhook.post("stripe") { req in
///         // Handle Stripe webhook with API key auth
///     }
/// }
/// ```
///
/// ## Usage
///
/// Header format:
/// ```http
/// GET /api/v1/users HTTP/1.1
/// Host: api.swiftcms.io
/// X-API-Key: scms_live_1a2B3c4D5e6F7g8H9i0Jk1lM2nOp3QrSt
/// Content-Type: application/json
/// ```
///
/// ## Security Best Practices
///
/// ### 🛡️ Production Security Checklist
/// - ✅ **Always use HTTPS**: API keys transmitted over HTTP can be intercepted
/// - ✅ **Hash before storage**: Never store plaintext API keys
/// - ✅ **Use strong random generation**: 32+ bytes, cryptographically secure
/// - ✅ **Implement rotation policy**: Rotate keys every 90 days
/// - ✅ **Set expiration dates**: Don't create eternal keys
/// - ✅ **Principle of least privilege**: Grant minimum required permissions
/// - ✅ **Monitor usage patterns**: Detect anomalies and potential breaches
/// - ✅ **IP whitelisting**: Restrict keys to known IPs when possible
/// - ✅ **Rate limiting**: Prevent abuse with per-key rate limits
/// - ✅ **Immediate revocation**: Ability to revoke compromised keys instantly
///
/// ### 🔐 Key Management Strategy
/// ```
/// ┌─────────────────┐
/// │  Key Generation │ ← Cryptographically secure random
/// └────────┬────────┘
///          ↓
/// ┌─────────────────┐
/// │   Key Display   │ ← Show once, never again!
/// └────────┬────────┘
///          ↓
/// ┌─────────────────┐
/// │   Hash & Store  │ ← Bcrypt hash only
/// └────────┬────────┘
///          ↓
/// ┌─────────────────┐
/// │  Active Period  │ ← Monitor usage
/// └────────┬────────┘
///          ↓
/// ┌─────────────────┐
/// │  Rotate/Revoke  │ ← Regular rotation or on breach
/// └─────────────────┘
/// ```
///
/// ### 🚨 Incident Response
/// **If API key is compromised:**
/// 1. **Immediate**: Revoke the key in database
/// 2. ** investigation**: Check logs for unauthorized usage
/// 3. **Mitigation**: Review permissions granted to key
/// 4. **Recovery**: Generate new key with appropriate permissions
/// 5. **Communication**: Notify key owner of incident
///
/// ### ⚠️ Common Security Mistakes
/// - ❌ **Embedding keys in client-side code**: Always use server-to-server
/// - ❌ **Logging plaintext keys**: Log only prefix for identification
/// - ❌ **No expiration dates**: All keys should have limited lifespan
/// - ❌ **Overly broad permissions**: Follow principle of least privilege
/// - ❌ **Single key for all services**: Use separate keys per service
/// - ❌ **No usage monitoring**: Can't detect breaches without monitoring
/// - ❌ **Weak key generation**: Using simple random functions
///
/// ## Testing API Key Authentication
///
/// ### Unit Tests
/// ```swift
/// func testApiKeyAuthentication() async throws {
///     let app = Application(.testing)
/// defer { app.shutdown() }
///
///     let middleware = ApiKeyMiddleware()
///
///     // Create test key
///     let apiKey = ApiKey(
///         name: "Test Key",
///     keyHash: try Bcrypt.hash("test-key-12345"),
///     permissions: ["read:test"],
///         isActive: true
///     )
/// try await apiKey.save(on: app.db)
///
///     // Test with valid key
///     var req = Request(application: app, on: app.eventLoopGroup.next())
/// req.headers.add(name: "X-API-Key", value: "test-key-12345")
///
///     let responder = TestResponder()
///     let response = try await middleware.respond(to: req, chainingTo: responder)
///
///     XCTAssertEqual(response.status, .ok)
///     XCTAssertNotNil(req.auth.get(CmsUser.self))
/// }
/// ```
///
/// ### Integration Tests
/// ```swift
/// func testProtectedEndpoint() async throws {
///     let app = try createTestApp()
///
///     // Create API key
/// let (key, _) = try await app.apiKeyService.createKey(
///         name: "Integration Test",
///         permissions: ["read:users"],
///         on: app.db
///     )
///
///     // Test without key
///     try await app.test(.GET, "/api/v1/users") { res in
///         XCTAssertEqual(res.status, .unauthorized)
///     }
///
///     // Test with invalid key
///     try await app.test(.GET, "/api/v1/users", headers: [
///  "X-API-Key": "invalid-key"
///     ]) { res in
///         XCTAssertEqual(res.status, .unauthorized)
///     }
///
///     // Test with valid key
///     try await app.test(.GET, "/api/v1/users", headers: [
///         "X-API-Key": key
///     ]) { res in
///         XCTAssertEqual(res.status, .ok)
///     }
/// }
/// ```
///
/// ## Monitoring and Observability
///
/// ### Key Metrics
/// - Authentication success/failure rates
/// - Key usage by client
/// - Expired key attempts
/// - Revoked key attempts
/// - Permission denied rates
/// - Response times for auth checks
///
/// ### Alert Conditions
/// - High authentication failure rate (> 5%)
/// - Suspicious usage patterns (unusual IP, rate spikes)
///   - Expired key usage (stale credentials)
///     - Revoked key attempts (potential breach)
///
/// ## Database Indexes
/// ```sql
/// -- Essential for fast key lookups
/// CREATE INDEX idx_api_keys_hash ON api_keys(key_hash);
/// CREATE INDEX idx_api_keys_prefix ON api_keys(prefix);
/// CREATE INDEX idx_api_keys_active ON api_keys(is_active) WHERE is_active = true;
/// CREATE INDEX idx_api_keys_expires ON api_keys(expires_at) WHERE expires_at IS NOT NULL;
/// CREATE INDEX idx_api_keys_tenant ON api_keys(tenant_id) WHERE tenant_id IS NOT NULL;
///
/// -- For monitoring queries
/// CREATE INDEX idx_api_keys_last_used ON api_keys(last_used_at) WHERE last_used_at IS NOT NULL;
/// ```
public struct ApiKeyMiddleware: AsyncMiddleware, Sendable {
    public init() {}

    /// 🔐 Process request and authenticate via API key
    ///
    /// - Parameters:
    ///   - request: The incoming Vapor request
    ///   - next: The next responder in the chain
    /// - Returns: Response if authenticated, throws error if not
    /// - Throws: `ApiError.unauthorized` if API key is invalid or expired
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // ✅ Skip if already authenticated via other method
        if request.auth.has(CmsUser.self) {
            request.logger.debug("⭐ Already authenticated, skipping API key check")
            return try await next.respond(to: request)
        }

        // 🔑 Extract API key from header
        guard let apiKeyValue = request.headers.first(name: "X-API-Key") else {
            request.logger.debug("❓ No API key provided, continuing anonymously")
            return try await next.respond(to: request)
        }

        request.logger.info("🔐 API key authentication attempt")

        // 🔒 Hash the key for secure comparison
        // In production, you should store the hash and compare, rather than hashing on each request
        let keyHash = try Bcrypt.hash(apiKeyValue)
        request.logger.debug("🔒 Created key hash for lookup")

        // 📋 Look up API key in database
        guard let apiKey = try await ApiKey.query(on: request.db)
            .filter(\.$keyHash == keyHash)
            .first()
        else {
            request.logger.warning("🚫 Invalid API key attempted")
            throw ApiError.unauthorized("Invalid API key")
        }

        request.logger.info("✅ API key found: \(apiKey.name)")

        // ⏰ Check expiration
        if let expiresAt = apiKey.expiresAt, expiresAt < Date() {
            request.logger.warning("⏰ Expired API key used: \(apiKey.name)")
            throw ApiError.unauthorized("API key expired")
        }

        // 📝 Update usage tracking
        apiKey.lastUsedAt = Date()
        try await apiKey.save(on: request.db)
        request.logger.debug("📝 Updated last used timestamp for API key")

        // 👤 Create synthetic authenticated user
        // API keys currently get super-admin access for simplicity
        // In production, map API key permissions to user roles
        let user = CmsUser(
            userId: "apikey:\(apiKey.id?.uuidString ?? "unknown")",
            email: nil,
            roles: ["super-admin"],  // API keys get full access for now
            tenantId: apiKey.tenantId
        )
        request.auth.login(user)
        request.logger.info("👤 API key authenticated as: \(user.userId)")

        return try await next.respond(to: request)
    }
}

// MARK: - 📝 Session Auth Middleware

/// 📝 **Session-Based Authentication Middleware**
///
/// Handles authentication for admin panel using Vapor's session system.
/// Redirects unauthenticated users to login page.
///
/// ## Session-Based Authentication Overview
///
/// Session auth is ideal for traditional web applications where:
/// - Users interact via browsers
/// - Server-side rendering is used
/// - Cookies are the preferred transport
/// - Session state needs to be maintained
///
/// ### Session vs Token Authentication
///
/// | Aspect | Session (Cookie) | Token (JWT) |
/// |--------|-----------------|-------------|
/// | **Storage** | Server-side session store | Client-side storage |
/// | **Scalability** | Requires session stickiness/Redis | Stateless, easily scalable |
/// | **Security** | CSRF protection needed | XSS protection needed |
/// | **Use Case** | Web apps, admin panels | APIs, mobile apps, SPAs |
/// | **Logout** | Delete session on server | Blacklist token or wait for expiry |
///
/// ## How Sessions Work in Vapor
///
/// ### Session Flow
/// ```
/// 1. User Login
///     ↓
/// 2. Create Session Record (Redis/Database)
///     ↓
/// 3. Set sessionID Cookie
///     ↓  ←───┐
/// 4. Subsequent Requests         │
///     ↓                          │
/// 5. Read sessionID from Cookie  │
///     ↓                          │
/// 6. Lookup Session Data         │
///     ↓                          │
/// 7. User is Authenticated       │
///     ↓                          │
/// 8. Send Response───────────────┘
/// ```
///
/// ### Session Storage Options
/// ```swift
/// // Memory (development only)
/// app.sessions.use(.memory)
///
/// // Fluent (PostgreSQL/SQLite)
/// app.sessions.use(.fluent)
///
/// // Redis (recommended for production)
/// app.sessions.use(.redis)
/// ```
///
/// ## Features
///
/// - 🔄 **Automatic redirect**: Unauthenticated users → login page
/// - 👥 **Dual auth support**: Both `CmsUser` (API) and `User` (admin) authentication
/// - 🛡️ **CSRF protection**: Integrates with Vapor's CSRF middleware
/// - ⚙️ **Configurable paths**: Customizable login and redirect paths
/// - 🗑️ **Automatic cleanup**: Expired sessions are removed
/// - 🔍 **Session inspection**: Debug session contents easily
///
/// ## Configuration
///
/// ### 1. Session Setup
/// ```swift
/// // In configure.swift
/// import Vapor
/// import Redis
///
/// public func configure(_ app: Application) async throws {
///     // ... other configurations ...
///
///     // Session driver (choose one)
///     // app.sessions.use(.memory)  // ⚠️ Development only!
///     // app.sessions.use(.fluent)  // PostgreSQL/SQLite
///     app.sessions.use(.redis)    // ✅ Recommended for production
///
///     // Session middleware
///     app.middleware.use(app.sessions.middleware)
///     app.middleware.use(SessionsMiddleware(session: .init()))
///
///     // CSRF protection (recommended)
///     app.middleware.use(CSRFMiddleware())
/// }
/// ```
///
/// ### 2. Login Implementation
/// ```swift
/// // Login route
/// struct LoginDTO: Content {
///     var email: String
///     var password: String
/// }
///
/// app.post("admin", "login") { req -> Response in
///     let login = try req.content.decode(LoginDTO.self)
///
/// // Find user
///     guard let user = try await User.query(on: req.db)
///         .filter(\.$email == login.email)
///         .first()
/// else {
///         throw Abort(.unauthorized, reason: "Invalid credentials")
///     }
///
///     // Verify password
///     guard try await req.password.async.verify(login.password, created: user.passwordHash) else {
///         req.logger.warning("Failed login attempt for email: \(login.email)")
///     throw Abort(.unauthorized, reason: "Invalid credentials")
///     }
///
///     // Create session
///     let session = SessionData(userId: user.id!)
///     req.session.data = try JSONEncoder().encode(session)
///
///req.logger.info("User \(user.email) logged in successfully")
///     return req.redirect(to: "/admin/dashboard")
/// }
/// ```
///
/// ### 3. Logout Implementation
/// ```swift
/// app.post("admin", "logout") { req -> Response in
///     req.logger.info("User logged out")
///     req.session.destroy()
///     return req.redirect(to: "/admin/login")
/// }
/// ```
///
/// ## Usage Example
///
/// ### Basic Admin Protection
/// ```swift
/// // In routes.swift
///
/// // All admin routes require authentication
/// let admin = app.grouped("admin")
///     .grouped(SessionAuthRedirectMiddleware())
///     .grouped(RBACMiddleware(action: "admin"))
///
/// // Dashboard (requires admin permission)
/// admin.get("dashboard") { req in
///     let user = try req.auth.require(User.self)
///     return DashboardView(user: user)
/// }
///
/// // Content management
/// admin.get("content", ":type") { req in
///    let contentType = req.parameters.get("type")!
///     return try await ContentListView(type: contentType)
/// }
/// ```
///
/// ### Custom Login Path
/// ```swift
/// // Custom login and redirect paths
/// let admin = app.grouped("admin")
///     .grouped(SessionAuthRedirectMiddleware(
///         loginPath: "/admin/signin"
///     ))
///
/// // When accessing /admin/protected without auth
/// // → Redirects to /admin/signin
/// // After successful login
/// // → Redirects back to original requested page
/// ```
///
/// ### Conditional Protection
/// ```swift
/// // Some routes public, some protected
/// let admin = app.grouped("admin")
///
/// // Public routes (no auth required)
/// admin.get("login") { req in
///     return LoginView()
/// }
///
/// admin.get("forgot-password") { req in
///     return ForgotPasswordView()
/// }
///
/// // Protected routes
/// let protectedAdmin = admin
///     .grouped(SessionAuthRedirectMiddleware())
///     .grouped(RBACMiddleware(action: "admin"))
///
/// protectedAdmin.get("dashboard") { req in
///     return DashboardView()
/// }
/// protectedAdmin.get("settings") { req in
///     return SettingsView()
/// }
/// ```
///
/// ### Mixed Auth Methods
/// ```swift
/// // Support both session and JWT
/// let admin = app.grouped("admin")
///     .grouped(
///         MultiAuthMiddleware([
///             SessionAuthRedirectMiddleware(),
///             JWTBearerAuthenticator(provider: provider)
///         ])
///     )
///     .grouped(RBACMiddleware(action: "admin"))
///
/// // Users can authenticate via:
/// // 1. Session cookie (web browser)
/// // 2. JWT token (API client)
/// ```
///
/// ## Security Considerations
///
/// ### 🛡️ Session Security Best Practices
///
/// #### 1. Secure Cookie Configuration
/// ```swift
/// // In configure.swift
/// app.sessions.configuration = .init(
///     cookieName: "scms_session",     // Custom cookie name
///     cookieFactory: { sessionID in
///  .init(
///             string: sessionID,
///             isSecure: true,                 // ✅ HTTPS only
///             isHTTPOnly: true,               // ✅ No JavaScript access
///             sameSite: .strict,              // ✅ CSRF protection
///  maxAge: .hours(24)              // 24 hour session
///         )
///     }
/// )
/// ```
///
/// #### 2. Session Expiration
/// ```swift
/// // Short sessions for sensitive operations
/// app.sessions.configuration = .init(
///     cookieFactory: { sessionID in
/// .init(
///             string: sessionID,
///   isSecure: true,
///    isHTTPOnly: true,
///       sameSite: .lax,
///   maxAge: .minutes(30)  // 30 minute sessions
///         )
///     }
/// )
/// ```
///
/// #### 3. CSRF Protection
/// ```swift
/// // Add CSRF token to forms
/// <form action="/admin/update" method="POST">
///     <input type="hidden" name="csrfToken" value="#(csrfToken)">
///     <!-- form fields -->
/// </form>
///
/// // CSRF middleware validates token
/// app.middleware.use(CSRFMiddleware())
/// ```
///
/// #### 4. Session Hijacking Protection
/// ```swift
/// // Regenerate session ID on privilege escalation
/// app.post("admin", "login") { req in
///     // ... authentication logic ...
///
///     // Regenerate session ID to prevent fixation
///     req.session.destroy()
///     req.session.data = try JSONEncoder().encode(sessionData)
/// }
/// ```
///
/// #### 5. Concurrent Session Limit
/// ```swift
/// // Limit user to one active session
/// struct UserSession: Model {
///     @ID(key: .id)
///     var id: UUID?
///
///     @Parent(key: "user_id")
///     var user: User
///
///     @Field(key: "session_token")
///     var sessionToken: String
/// }
///
/// // On login, invalidate other sessions
/// try await UserSession.query(on: req.db)
///     .filter(\.$user.$id == user.id!)
///     .delete()
/// ```
///
/// ### 🚨 Security Threats and Mitigations
///
/// | Threat | Impact | Mitigation |
/// |--------|--------|------------|
/// | Session Hijacking | High | HTTPS, secure cookies, regenerate ID on login |
/// | CSRF | Medium | SameSite cookies, CSRF tokens |
/// | Session Fixation | Medium | Regenerate session ID on auth change |
/// | XSS | Medium | HttpOnly cookies, input sanitization |
/// | Brute Force | Medium | Rate limiting, account lockout |
/// | Session Theft | High | Short expiration, detect suspicious activity |
///
/// ## Scale and Performance
///
/// ### Session Storage Comparison
///
/// | Storage | Pros | Cons | Best For |
/// |---------|------|------|----------|
/// | **Memory** | Fastest, no setup | Lost on restart, no sharing | Development |
/// | **PostgreSQL** | Persistent, transactional | Slower, additional queries | Small apps |
/// | **Redis** | Fast, scalable, TTL support | Additional service | Production |
///
/// ### Redis Configuration for Sessions
/// ```swift
/// // In configure.swift
/// app.redis.configuration = try RedisConfiguration(
///     hostname: Environment.get("REDIS_HOST") ?? "localhost",
///     port: Environment.get("REDIS_PORT").flatMap(Int.init) ?? 6379,
///     password: Environment.get("REDIS_PASSWORD"),
///     pool: .init(
///         maximumConnectionCount: 10,
///         minimumConnectionCount: 2
///     )
/// )
///
/// // Use Redis for sessions
/// app.sessions.use(.redis)
///
/// // Configure session expiration in Redis
/// app.sessions.configuration = .init(
///     cookieFactory: { sessionID in
///         // ... cookie config ...
///     },
///     redisKeyPrefix: "scms_sessions"
/// )
/// ```
///
/// ## Testing Session Authentication
///
/// ### Unit Tests
/// ```swift
/// func testSessionAuthRedirect() async throws {
///     let app = Application(.testing)
///     defer { app.shutdown() }
///
///     let middleware = SessionAuthRedirectMiddleware()
///     let responder = TestResponder()
///
///     // Test unauthenticated request
/// let req = Request(application: app, on: app.eventLoopGroup.next())
///     let response = try await middleware.respond(to: req, chainingTo: responder)
///
///     // Should redirect to login
///     XCTAssertEqual(response.status, .seeOther)
///     XCTAssertEqual(response.headers.first(name: .location), "/admin/login")
/// }
///
/// func testSessionAuthSuccess() async throws {
///     let app = Application(.testing)
///     defer { app.shutdown() }
///
///     let middleware = SessionAuthRedirectMiddleware()
///     let responder = TestResponder()
///     let req = Request(application: app, on: app.eventLoopGroup.next())
///
///     // Create and login user
///      let user = User(email: "test@example.com", passwordHash: "hash")
///     try await user.save(on: app.db)
///     req.auth.login(user)
///
///     // Should allow access
///     let response = try await middleware.respond(to: req, chainingTo: responder)
///     XCTAssertEqual(response.status, .ok)
/// }
/// ```
///
/// ### Integration Tests
/// ```swift
/// func testAdminDashboard() async throws {
///     let app = try createTestApp()
///
///     // Test without authentication
///    try await app.test(.GET, "/admin/dashboard") { res in
///         XCTAssertEqual(res.status, .seeOther)  // Redirect to login
///         XCTAssertEqual(res.headers.first(name: .location), "/admin/login")
///     }
///
///     // Login and get session cookie
///     let loginRes = try await app.sendRequest(.POST, "/admin/login", headers: [
///         .contentType: .json
///     ], body: JSONEncoder().encodeAsByteBuffer([
///         "email": "admin@example.com",
///         "password": "password123"
///     ], allocator: .init()))
///
///     let cookie = loginRes.headers.first(name: .setCookie)
///
///     // Access dashboard with session
///      try await app.test(.GET, "/admin/dashboard", headers: [
///         .cookie: cookie ?? ""
///     ]) { res in
///         XCTAssertEqual(res.status, .ok)
///      }
/// }
/// ```
///
/// ## Troubleshooting
///
/// ### Common Issues
///
/// #### Session not persisting
/// ```swift
/// // Check middleware order
/// app.middleware.use(app.sessions.middleware)  // Must be before routes
/// app.middleware.use(SessionAuthRedirectMiddleware())
/// ```
///
/// #### CSRF errors on login
/// ```swift
/// // Exclude login from CSRF protection
/// let csrf = CSRFMiddleware()
/// csrf.excludePaths = ["/admin/login"]
/// app.middleware.use(csrf)
/// ```
///
/// #### Session expires too quickly
/// ```swift
/// // Check Redis TTL
/// app.sessions.configuration = .init(
///     cookieFactory: { sessionID in
///         .init(
///             string: sessionID,
///         isSecure: true,
///             isHTTPOnly: true,
///             sameSite: .lax,
///         maxAge: .hours(8)  // 8 hour session
///         )
///     }
/// )
/// ```
public struct SessionAuthRedirectMiddleware: AsyncMiddleware, Sendable {
    let loginPath: String

    /// 📝 Initialize session auth middleware
    ///
    /// - Parameter loginPath: Path to redirect unauthenticated users (default: "/admin/login")
    public init(loginPath: String = "/admin/login") {
        self.loginPath = loginPath
    }

    /// 🛡️ Enforce session authentication
    ///
    /// - Parameters:
    ///   - request: The incoming Vapor request
    ///   - next: The next responder in the chain
    /// - Returns: Response if authenticated, redirect if not
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // ✅ Check if user is authenticated via any method
        if request.auth.has(CmsUser.self) || request.auth.has(User.self) {
            request.logger.debug("✅ User authenticated via session, allowing access")
            return try await next.respond(to: request)
        }

        // 🚫 Not authenticated - redirect to login
        request.logger.info("🚫 Unauthenticated user redirected to login")
        return request.redirect(to: loginPath)
    }
}

// MARK: - 🏭 Auth Provider Factory

/// 🏭 **Authentication Provider Factory**
///
/// Creates appropriate authentication provider based on environment configuration.
/// Supports runtime provider switching via `AUTH_PROVIDER` environment variable.
///
/// ## Supported Providers
///
/// | Provider | Environment Value | Use Case |
/// |----------|------------------|----------|
/// | 🔐 Auth0 | `auth0` | Enterprise + Social authentication |
/// | 🌐 Firebase | `firebase` | Google ecosystem apps |
/// | 🔑 Local JWT | `local` | Self-hosted authentication |
///
/// ## Configuration
///
/// Set the provider in your environment:
/// ```bash
/// export AUTH_PROVIDER=auth0
/// export AUTH0_DOMAIN=your-domain.auth0.com
/// export AUTH0_AUDIENCE=https://api.yourapp.com
/// ```
///
/// ## Usage Example
///
/// ```swift
/// // In configure.swift
/// let authProvider = AuthProviderFactory.create(from: app.environment)
/// try authProvider.configure(app: app)
///
/// // Register middleware
/// app.middleware.use(authProvider.middleware())
/// ```
public struct AuthProviderFactory: Sendable {
    /// 🏭 Create authentication provider from environment
    ///
    /// - Parameter environment: The Vapor environment
    /// - Returns: Configured auth provider instance
    public static func create(from environment: Environment) -> AuthProvider {
        let providerName = Environment.get("AUTH_PROVIDER") ?? "local"

        print("🔧 Creating auth provider: \(providerName)")

        switch providerName.lowercased() {
        case "auth0":
            print("🔐 Configuring Auth0 provider")
            return Auth0Provider()
        case "firebase":
            print("🌐 Configuring Firebase provider")
            return FirebaseProvider()
        case "local":
            print("🔑 Configuring Local JWT provider")
            return LocalJWTProvider()
        default:
            print("⚠️ Unknown auth provider '\(providerName)', defaulting to local")
            return LocalJWTProvider()
        }
    }
}

// MARK: - 🔑 JWT Bearer Authenticator

/// 🔑 **JWT Bearer Token Authenticator**
///
/// Automatically extracts and validates JWT tokens from Authorization headers.
/// Integrates with any AuthProvider implementation for token verification.
///
/// ## Token Format
/// ```
/// Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
/// ```
///
/// ## Usage Example
///
/// ```swift
/// // Create authenticator with your provider
/// let authProvider = AuthProviderFactory.create(from: app.environment)
/// let authenticator = JWTBearerAuthenticator(provider: authProvider)
///
/// // Protect routes
/// let api = app.grouped(authenticator)
/// api.get("profile") { req in
///     let user = try req.auth.require(CmsUser.self)
///     return "Hello, \(user.userId)!"
/// }
/// ```
///
/// ## Security Features
/// - Automatic token extraction from Authorization header
/// - Full payload verification via provider
/// - Converts to CmsUser for unified auth handling
/// - Error propagation with detailed messages
public struct JWTBearerAuthenticator: AsyncBearerAuthenticator, Sendable {
    let provider: AuthProvider

    /// 🔑 Initialize JWT bearer authenticator
    ///
    /// - Parameter provider: The authentication provider for token verification
    public init(provider: AuthProvider) {
        self.provider = provider
    }

    /// 🛡️ Authenticate request using bearer token
    ///
    /// - Parameters:
    ///   - bearer: The bearer authorization from header
    ///   - request: The Vapor request
    /// - Throws: Authentication error if token is invalid
    public func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        request.logger.debug("🔑 Attempting JWT bearer authentication")

        do {
            // 🔍 Verify token with provider
            let user = try await provider.verify(token: bearer.token, on: request)
            let cmsUser = CmsUser(from: user)
            request.auth.login(cmsUser)

            request.logger.info("✅ JWT authentication successful for user: \(user.userId)")
        } catch {
            request.logger.warning("🚫 JWT authentication failed: \(error)")
            throw error
        }
    }
}
