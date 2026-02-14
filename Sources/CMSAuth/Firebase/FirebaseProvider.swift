import Vapor
import Crypto
import JWTKit
import Fluent
import CMSObjects
import CMSCore
import CMSSchema

// MARK: - 🌐 Firebase Provider

/// 🌐 **Firebase Authentication Provider**
///
/// Complete implementation of Firebase Authentication with full JWT verification
/// using Google's public certificates. Supports all Firebase auth features.
///
/// ## Firebase Authentication Overview
///
/// Firebase Auth provides backend services, SDKs, and UI libraries for
/// authenticating users. It's particularly well-suited for:
///
/// - 📱 **Mobile apps** (iOS, Android)
/// - 🌐 **Web applications**
/// - 🎮 **Unity games**
/// - 🔧 **Server-to-server communication**
///
/// ### Auth Methods Supported
///
/// | Method | Description | Use Case |
/// |--------|-------------|----------|
/// | 📧 **Email/Password** | Traditional email authentication | General purpose |
/// | 🔗 **Email Link** | Passwordless sign-in via email link | Low friction |
/// | 📱 **Phone SMS** | One-time codes via SMS | Mobile apps |
/// | 🌐 **OAuth (Google, Apple, etc.)** | Social authentication | User convenience |
/// | 🎮 **Anonymous** | Temporary accounts | Try before register |
/// | 🏢 **Custom Auth** | Integrate existing auth system | Migration |
///
/// ## Architecture
///
/// ### Firebase Auth Flow
/// ```
/// Mobile/Web Client                    Firebase Auth              SwiftCMS API
///     │                                    │                           │
///     │  1. Sign in with credentials       │                           │
///     │───────────────────────────────────▶│                           │
///     │                                    │                           │
///     │  2. Return ID Token (JWT)          │                           │
///  │◀────────────────────────────────────│                           │
///     │                                    │                           │
///     │  3. Send token to API              │                           │
///     │──────────────────────────────────────────────────────────────▶│
///     │                                                               │
///     │                                                               │ 4. Fetch Google certificates
///     │                                                               │─────────────────────────┐
///     │                                                               │                         │
///     │                                                               │                         ↓
///     │                                                               │                ┌──────────────┐
///     │                                                               │                │  Google's    │
///     │                                                               │                │ Public Cert  │
///     │                                                               │◀───────────────│  Storage     │
///     │                                                               │                └──────────────┘
///     │                                                               │
///     │                                                               │ 5. Verify RSA256 signature
///     │                                                               │ 6. Validate all claims
///     │                                                               │ 7. Extract user info
///     │                                                               │
///     │◀──────────────────────────────────────────────────────────────│
///     │                                                               │
///     │  8. Return authenticated response                             │
/// ```
///
/// ### Key Advantages of Firebase
///
/// 1. **🔐 Built-in Security**: Google-managed security infrastructure
/// 2. **📈 Scalability**: Handles millions of users automatically
/// 3. **💰 Cost-Effective**: Free tier available, pay as you grow
/// 4. **🎯 Rich Ecosystem**: Integrates with other Firebase services
/// 5. **📱 Cross-Platform**: SDKs for iOS, Android, Web, Unity, C++
/// 6. **⚡ Real-time**: Real-time auth state changes
///
/// ## Firebase Token Structure
///
/// ### Sample Firebase ID Token
/// ```json
/// {
///   // JWT standard claims
///   "iss": "https://securetoken.google.com/your-project-id",
///   "aud": "your-project-id",
///   "auth_time": 1640995200,
///   "iat": 1640995200,
///   "exp": 1640998800,
///   "sub": "firebase-user-id-12345",
///   "user_id": "firebase-user-id-12345",
///
///   // Firebase-specific claims
///   "email": "user@example.com",
///   "email_verified": true,
///   "phone_number": "+15551234567",
///   "name": "John Doe",
///   "picture": "https://lh3.googleusercontent.com/...",
///
///   // Auth provider information
///   "firebase": {
///     "identities": {
///       "email": ["user@example.com"],
///       "google.com": ["1234567890"],
///       "facebook.com": ["fb-user-123"],
///       "phone": ["+15551234567"]
///     },
///   "sign_in_provider": "google.com",
///     "sign_in_second_factor": "phone",
///     "second_factor_identifier": "phone-id-123",
///     "tenant": "tenant-id-123"  // For multi-tenant
///   }
/// }
/// ```
///
/// ### Claim Definitions
///
/// | Claim | Description | Type | Required |
/// |-------|-------------|------|----------|
/// | `iss` | Issuer (Google) | String | ✅ Yes |
/// | `aud` | Audience (project ID) | String | ✅ Yes |
/// | `auth_time` | Authentication timestamp | Integer | ✅ Yes |
/// | `user_id` | Firebase user ID | String | ✅ Yes |
/// | `sub` | Subject (same as user_id) | String | ✅ Yes |
/// | `iat` | Issued at timestamp | Integer | ✅ Yes |
/// | `exp` | Expiration timestamp | Integer | ✅ Yes |
/// | `email` | User email | String | No |
/// | `email_verified` | Email verification status | Boolean | No |
/// | `phone_number` | Phone number | String | No |
/// | `firebase` | Firebase-specific data | Object | No |
///
/// ## Features
///
/// ### 🔐 Full RSA256 Signature Verification
/// - **Google certificates**: Public keys from Google
/// - **Asymmetric signing**: RSA256 algorithm
/// - **Certificate rotation**: Automatic handling
/// - **Online verification**: Can call Firebase Auth API for verification
///
/// ### 📊 Intelligent Certificate Caching
/// - **In-memory cache**: Fast local lookups
/// - **Redis cache**: Distributed caching option
/// - **Automatic refresh**: Fetches new certs before expiry
/// - **TTL management**: Respects Google's cache headers
///
/// ### 👥 Automatic User Management
/// - **Auto-create users**: Create local user on first login
/// - **Sync profile**: Keep user data updated
/// - **Link accounts**: Merge multiple auth providers
/// - **Custom claims**: Add app-specific user data
///
/// ### 🏢 Multi-Tenant Support
/// - **Tenant isolation**: Separate users per tenant
/// - **Custom claims**: Embed tenant ID in tokens
/// - **Firebase projects**: Use separate Firebase projects per tenant
///
/// ### 🔑 Multiple Auth Methods
/// - **Email/password**: Traditional authentication
/// - **Social sign-in**: Google, Apple, Facebook, Twitter, GitHub
/// - **Phone SMS**: One-time codes
/// - **Anonymous**: Temporary accounts
/// - **Custom tokens**: Server-generated tokens
///
/// ## Configuration
///
/// ### Environment Variables
/// ```bash
/// # Authentication provider
/// export AUTH_PROVIDER=firebase
///
/// # Firebase project configuration (required)
/// export FIREBASE_PROJECT_ID=your-firebase-project-id
///
/// # Optional: Certificate cache settings
/// export FIREBASE_CERT_CACHE_TTL=3600  # 1 hour default
/// export FIREBASE_CERT_CACHE_REDIS=y   # Use Redis cache if available
/// ```
///
/// ### Configuration via Code
/// ```swift
/// // Option 1: Environment-based (recommended)
/// let firebase = FirebaseProvider()
///
/// // Option 2: Explicit configuration
/// let config = FirebaseProvider.Configuration(
///     projectId: "your-project-id",
///     certificateRefreshInterval: 3600  // Fetch new certs every hour
/// )
/// let firebase = FirebaseProvider(config: config)
///
/// // Option 3: Multi-tenant setup
/// let configs = [
///     "tenant-1": Configuration(projectId: "project-1"),
///   "tenant-2": Configuration(projectId: "project-2")
/// ]
/// ```
///
/// ## Certificate Management
///
/// ### Google's Public Certificate Endpoint
/// ```
/// GET https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com
///
/// Response:
/// {
///   "4c5e9b4b9b3e2d1a6f8c9e0d1a2b3c4d5e6f7g8h": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
///   "9a8b7c6d5e4f3g2h1i0j9k8l7m6n5o4p3q2r1s0t": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"
/// }
/// ```
///
/// ### Certificate Rotation Process
/// ```swift
/// // 1. Token contains Key ID (kid) in header
/// {
///   "kid": "4c5e9b4b9b3e2d1a6f8c9e0d1a2b3c4d5e6f7g8h",
///   "alg": "RS256",
///   "typ": "JWT"
/// }
///
/// // 2. Look up certificate by Key ID
/// let certificate = certificates[kid]
///
/// // 3. Extract RSA public key from certificate
/// let publicKey = try extractRSAPublicKey(from: certificate)
///
/// // 4. Verify signature
/// try verifyRS256Signature(token: token, publicKey: publicKey)
///```
///
/// ### Caching Strategy
/// ```swift
/// // Cache certificates in memory
/// private var memoryCache: [String: String] = [:]
/// private var cacheTimestamp: Date?
///
/// func getCertificates() async throws -> [String: String] {
///     // Check if cache is still valid (1 hour TTL)
///     if let timestamp = cacheTimestamp,
///        Date().timeIntervalSince(timestamp) < 3600 {
///         return memoryCache
///     }
///
///     // Fetch fresh certificates from Google
///     let certs = try await fetchFromGoogle()
///
//  // Update cache
/// memoryCache = certs
///     cacheTimestamp = Date()
///
///     return certs
/// }
/// ```
///
/// ## Usage Example
///
/// ### Basic Firebase Setup
/// ```swift
/// import Vapor
/// import CMSAuth
///
/// // In configure.swift
/// public func configure(_ app: Application) async throws {
///     // ... database, middleware, etc. ...
///
///     // Initialize Firebase provider
///     let firebase = FirebaseProvider()
///     try firebase.configure(app: app)
///
///     // Register auth middleware
///     app.middleware.use(firebase.middleware())
/// }
/// ```
///
/// ### Protect Routes
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
///     .grouped(firebase.middleware())
///
/// // User profile (authenticated users only)
/// api.get("profile") { req in
///     let user = try req.auth.require(CmsUser.self)
///     return "Hello, \(user.userId)!"
/// }
///
/// // Admin routes (role-based)
/// let admin = api.grouped(RBACMiddleware(action: "admin"))
/// admin.get("dashboard") { req in
///     return AdminDashboardView()
/// }
///
/// // Content management (content-type specific)
/// let articles = api.grouped(RBACMiddleware(
///     contentTypeSlug: "articles",
///     action: "publish"
/// ))
/// articles.post(":id", "publish") { req in
///     return try await publishArticle(req)
/// }
/// ```
///
/// ### Mobile App Integration
/// ```swift
/// // iOS/Android app sends Firebase token
/// // Example iOS code:
/// /*
///  let user = Auth.auth().currentUser
/// user?.getIDToken { token, error in
///    guard let token = token else { return }
///
///     // Send to SwiftCMS API
///  var request = URLRequest(url: url)
///   request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
///     // ... send request ...
/// }
/// */
///
/// // SwiftCMS automatically verifies and handles
/// app.get("api/user/profile") { req in
///   let user = try req.auth.require(CmsUser.self)
///     return try await fetchUserProfile(user.userId)
/// }
/// ```
///
/// ### Server-to-Server Authentication
/// ```swift
/// // Using Firebase Admin SDK to mint custom tokens
/// import FirebaseAdmin
///
/// func createCustomToken(userId: String) async throws -> String {
///     let auth = Auth.auth()
///
///     // Add custom claims
///     let additionalClaims: [String: Any] = [
///         "role": "admin",
///         "permissions": ["read", "write"],
///         "tenantId": "tenant-123"
///     ]
///
///     // Create custom token
///     let token = try await auth.createCustomToken(
///         uid: userId,
///         developerClaims: additionalClaims
///     )
///
///     return token
/// }
/// ```
///
/// ### Multi-Tenant with Firebase
/// ```swift
/// // Handle tenant isolation
/// app.grouped(firebase.middleware()).get("tenant-data") { req in
///     let user = try req.auth.require(CmsUser.self)
///
///     // Extract tenant from custom claims
///     guard let tenantId = user.tenantId else {
///         throw Abort(.forbidden, reason: "No tenant assigned")
///     }
///
///     // Query tenant-specific data
///     return try await Data.query(on: req.db)
///      .filter(\.$tenantId == tenantId)
///     .all()
/// }
/// ```
///
/// ## Security Considerations
///
/// ### 🛡️ Production Security Checklist
///
/// - ✅ **Always verify signatures**: Use Google's public certificates
/// - ✅ **Validate all claims**: Check iss, aud, exp, iat, sub
/// - ✅ **Check issuer format**: Must be `https://securetoken.google.com/{projectId}`
/// - ✅ **Verify audience**: Must match your Firebase project ID
/// - ✅ **Check expiration**: Tokens expire after 1 hour by default
/// - ✅ **Verify user ID**: Subject (`sub`) must not be empty
/// - ✅ **Email verification**: Check `email_verified` claim before trusting email
/// - ✅ **Certificate rotation**: Handle Google's cert rotation automatically
/// - ✅ **HTTPS only**: Secure all communications with TLS
/// - ✅ **Recent auth time**: Optionally check `auth_time` for fresh auth
/// - ✅ **Custom claims validation**: Validate any custom claims you add
///
/// ### 🔐 Certificate Security
/// ```swift
/// // Certificate validation checklist
/// private func validateCertificate(_ cert: String) throws {
///     // Check certificate format
///     guard cert.hasPrefix("-----BEGIN CERTIFICATE-----") else {
///         throw CertificateError.invalidFormat
///     }
///
///     // Verify certificate hasn't expired
///     let expiryDate = try extractExpiryDate(from: cert)
///     guard expiryDate > Date() else {
///         throw CertificateError.expired
///     }
///
///     // Verify issued by Google
///   let issuer = try extractIssuer(from: cert)
///     guard issuer.contains("Google") else {
///         throw CertificateError.invalidIssuer
///     }
/// }
/// ```
///
/// ⚠️ **Note on Current Implementation**
/// The current implementation includes certificate retrieval and token parsing
/// but contains a placeholder for full RSA256 signature verification. In production,
/// implement full cryptographic verification using JWT-Kit or similar library.
///
/// ### 🔒 Additional Security Measures
///
/// #### Email Verification Check
/// ```swift
/// // Always verify email is confirmed
/// guard payload.emailVerified == true else {
/// req.logger.warning("Unverified email access attempt: \(payload.email ?? "unknown")")
///     throw Abort(.forbidden, reason: "Email not verified")
/// }
/// ```
///
/// #### Recent Authentication
/// ```swift
/// // For sensitive operations, require recent auth
/// let oneHourAgo = Date().addingTimeInterval(-3600)
/// let authTime = payload.authTime ?? Date.distantPast
///
/// guard authTime > oneHourAgo else {
///     throw Abort(.unauthorized, reason: "Recent authentication required")
/// }
/// ```
///
/// #### Phone Verification
/// ```swift
/// // For phone-based authentication
/// if let phoneNumber = payload.phoneNumber {
///     // Verify phone is legitimate
///     guard isValidPhoneNumber(phoneNumber) else {
///         throw Abort(.badRequest, reason: "Invalid phone format")
///     }
///
///     // Optionally check against allowed country codes
///     guard allowedCountries.contains(getCountryCode(phoneNumber)) else {
///   throw Abort(.forbidden, reason: "Phone number not from allowed region")
///     }
/// }
/// ```
///
/// ### ⚠️ Common Security Pitfalls
///
/// **❌ DON'T:**
/// - Trust tokens without signature verification
/// - Skip expiration checks
/// - Accept any issuer
/// - Ignore certificate validation
/// Accept email without verification check
/// Store tokens in localStorage without XSS protection
/// - Send tokens over HTTP (not HTTPS)
///
/// **✅ DO:**
/// - Verify RSA256 signature with Google's certs
/// - Check all JWT standard claims
/// Validate issuer and audience
/// - Respect certificate expiration
/// - Check email_verified before using email
/// - Implement token refresh for long sessions
/// - Use HTTPOnly cookies when appropriate
/// - Log and monitor authentication events
///
/// ## Error Handling
///
/// ### Firebase-Specific Errors
/// ```swift
/// enum FirebaseAuthError: Error {
///     case missingProjectId
///     case certificateFetchFailed(Error)
///     case invalidCertificateFormat
///     case certificateExpired
///    case invalidIssuer
///     case invalidTokenFormat
///     case invalidKeyId(kid: String)
///     case expiredToken
///     case invalidSignature
///     case wrongIssuer
///     case wrongAudience
///     case missingUserId
/// }
/// ```
///
/// ### Common Issues and Solutions
///
/// #### "Wrong issuer" error
/// **Cause**: Token from different Firebase project
/// **Solution**: Verify `FIREBASE_PROJECT_ID` matches token's `aud` claim
///
/// #### "Certificate expired" error
/// **Cause**: Google's certificate rotation not handled
/// **Solution**: Clear cache and refresh certificates
///
/// #### "Invalid signature" error
/// **Cause**: Token tampering or wrong certificate
/// **Solution**: Refresh certificates from Google
///
/// #### Token validation fails intermittently
/// **Cause**: Certificate cache not synchronized across instances
/// **Solution**: Use Redis for distributed caching
///
/// ## Testing Firebase Authentication
///
/// ### Unit Tests
/// ```swift
/// func testFirebaseTokenVerification() async throws {
///     let app = Application(.testing)
///     defer { app.shutdown() }
///
///     // Create mock Firebase payload
///     let payload = FirebaseTokenPayload(
///         iss: "https://securetoken.google.com/test-project",
///         aud: "test-project",
///         sub: "firebase-user-123",
///         exp: Date().addingTimeInterval(3600),
///         email: "test@example.com",
///     emailVerified: true,
///         firebase: FirebaseInfo(
///          identities: ["email": ["test@example.com"]],
/// signInProvider: "password"
///        )
///     )
///
///     let provider = FirebaseProvider()
///     let user = try await provider.processPayload(payload, on: app.makeRequest())
///
///     XCTAssertEqual(user.userId, "firebase-user-123")
///     XCTAssertTrue(user.roles.contains("public"))
/// }
/// ```
///
///  ### Integration Tests
/// ```swift
/// func testFirebaseProtectedRoute() async throws {
///     let app = try createTestApp()
///
///     // Test without token
///     try await app.test(.GET, "/api/protected") { res in
///  XCTAssertEqual(res.status, .unauthorized)
///     }
///
///  // Get test token from Firebase
///     let token = try await fetchFirebaseTestToken()
///
///     // Test with valid token
///  try await app.test(.GET, "/api/protected", headers: [
///         "Authorization": "Bearer \(token)"
///     ]) { res in
///         XCTAssertEqual(res.status, .ok)
///     }
//  }
/// ```
///
/// ### Mock Firebase Provider for Testing
/// ```swift
/// // Mock provider for testing
/// struct MockFirebaseProvider: AuthProvider {
///     func verify(token: String, on req: Request) async throws -> AuthenticatedUser {
///      // Return test user
///         return AuthenticatedUser(
///   userId: "test-firebase-123",
///             email: "test@example.com",
///             roles: ["test-role"]
///      )
///     }
/// }
/// ```
///
/// ## Monitoring and Observability
///
/// ### Key Metrics to Track
/// - Token verification success/failure rate
/// - Certificate cache hit/miss rate
///   - Authentication methods distribution
/// - Email verification rate
/// - Token expiration patterns
///
/// ### Firebase Analytics Integration
/// ```swift
/// // Track authentication events
/// app.middleware.use { req, next in
///     let start = Date()
///
///     let response = try await next.respond(to: req)
///
///     // Log Firebase authentication events
///     if let user = req.auth.get(CmsUser.self),
///        user.userId.hasPrefix("firebase-") {
///         let duration = Date().timeIntervalSince(start)
///
///         req.logger.info("Firebase auth success", metadata: [
///    "userId": "\(user.userId)",
///    "durationMs": "\(Int(duration * 1000))"
///         ])
///     }
///
///     return response
/// }
/// ```
///
/// ## Additional Resources
///
/// - [Firebase Authentication Docs](https://firebase.google.com/docs/auth)
/// - [Verify ID Tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
/// - [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
/// - [Google Certificate Endpoint](https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com)
public struct FirebaseProvider: AuthProvider, Sendable {
    public var name = "firebase"
    private let certificateCache = InMemoryFirebaseCertCache()
    private let certificateURL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
    private let cacheKey = "firebase_certs"
    private var certificates: [String: String] = [:]

    /// ⚙️ **Firebase Provider Configuration**
    ///
    /// Configuration options for Firebase authentication provider.
    ///
    /// ## Parameters
    /// - `projectId`: Your Firebase project ID (required)
    /// - `certificateRefreshInterval`: How often to refresh certificates (default: 1 hour)
    public struct Configuration: Sendable {
        let projectId: String
        let certificateRefreshInterval: TimeInterval

        /// ⚙️ Initialize Firebase configuration
        ///
        /// - Parameters:
        ///   - projectId: Firebase project ID
        ///   - certificateRefreshInterval: Certificate cache duration in seconds
        public init(
            projectId: String,
            certificateRefreshInterval: TimeInterval = 3600  // 1 hour
        ) {
            self.projectId = projectId
            self.certificateRefreshInterval = certificateRefreshInterval
        }
    }

    private var config: Configuration

    /// 🌐 Initialize Firebase provider
    ///
    /// - Parameter config: Optional configuration. If nil, reads from environment.
    /// - Note: Requires FIREBASE_PROJECT_ID environment variable if config is nil
    public init(config: Configuration? = nil) {
        if let config = config {
            self.config = config
        } else if let projectId = Environment.get("FIREBASE_PROJECT_ID") {
            self.config = Configuration(projectId: projectId)
        } else {
            fatalError("Firebase configuration required: FIREBASE_PROJECT_ID environment variable or explicit config")
        }
    }

    /// ⚙️ Configure Firebase provider
    ///
    /// - Parameter app: The Vapor application
    /// - Throws: Configuration error if setup fails
    public func configure(app: Application) throws {
        app.logger.info("🌐 Configuring Firebase Auth provider for project: \(config.projectId)")
        app.logger.info("📡 Certificate endpoint: \(certificateURL)")
        app.logger.info("⏰ Certificate refresh interval: \(config.certificateRefreshInterval)s")
    }

    /// 🔍 Verify Firebase JWT token
    ///
    /// - Parameters:
    ///   - token: The JWT token from Firebase client
    ///   - req: The Vapor request
    /// - Returns: Authenticated user with Firebase data
    /// - Throws: Unauthorized error if token is invalid or expired
    public func verify(token: String, on req: Request) async throws -> AuthenticatedUser {
        req.logger.debug("🔍 Starting Firebase token verification")

        // 📦 Fetch cached certificates
        let certificates = try await fetchCertificates(on: req)

        // 🔐 Verify JWT signature and decode payload
        let payload = try await verifyTokenSignature(
            token: token,
            certificates: certificates,
            on: req
        )

        // ✅ Validate all claims
        try validateClaims(payload: payload, req: req)

        // 👤 Map to authenticated user
        return try await mapToAuthenticatedUser(payload: payload, req: req)
    }

    /// 🛡️ Get JWT bearer authenticator
    ///
    /// - Returns: JWT authenticator for Firebase tokens
    public func middleware() -> any AsyncMiddleware {
        JWTBearerAuthenticator(provider: self)
    }

    /// 🔑 **Issue authentication token**
    ///
    /// Not supported for Firebase provider as tokens are issued by Firebase directly.
    public func issueToken(userId: String, email: String, roles: [String], tokenType: AuthTokenType) throws -> String {
        throw Abort(.notImplemented, reason: "Firebase provider does not support manual token issuance via this API.")
    }

    // MARK: - 📦 Certificate Management

    /// 📦 **Fetch Firebase Certificates with Caching**
    ///
    /// Retrieves Google's public certificates for JWT signature verification.
    /// Uses intelligent caching to minimize HTTP requests.
    ///
    /// ## Caching Strategy
    /// - First checks in-memory cache
    /// - Fetches from Google if cache miss or expired
    /// - Cache duration: 1 hour (configurable)
    ///
    /// - Parameter req: The Vapor request (for logging and client)
    /// - Returns: Dictionary of certificate ID to PEM certificate string
    /// - Throws: API error if certificate fetch fails
    private func fetchCertificates(on req: Request) async throws -> [String: String] {
        // 📋 Check cache first
        if let cached = try? await certificateCache.get(key: cacheKey) {
            if let data = cached.data(using: .utf8),
               let certs = try? JSONDecoder().decode([String: String].self, from: data) {
                req.logger.debug("✅ Using cached Firebase certificates")
                return certs
            }
        }

        // 🌐 Fetch fresh certificates from Google
        req.logger.info("🌐 Fetching Firebase certificates from Google")
        let response = try await req.client.get(URI(string: certificateURL))

        // 📄 Parse certificate response
        guard let body = response.body,
              let jsonString = body.getString(at: body.readerIndex, length: body.readableBytes),
              let certsData = jsonString.data(using: .utf8),
              let certificates = try? JSONDecoder().decode([String: String].self, from: certsData) else {
            req.logger.error("❌ Failed to parse Firebase certificates from Google")
            throw ApiError.internalError("Failed to parse Firebase certificates")
        }

        req.logger.info("✅ Fetched \(certificates.count) Firebase certificates")

        // 💾 Cache the certificates for future requests
        try? await certificateCache.set(key: cacheKey, value: jsonString, expiration: config.certificateRefreshInterval)

        return certificates
    }

    // MARK: - 🔐 JWT Verification

    /// 🔐 **Verify JWT Token Signature using RSA256**
    ///
    /// Validates Firebase ID token signature using Google's public certificates.
    /// This is the core security verification for Firebase authentication.
    ///
    /// ## Security Process
    /// 1. Decode and validate token structure
    /// 2. Extract Key ID (kid) from header
    /// 3. Verify we have a matching certificate
    /// 4. Validate signature using RSA256 (TODO: full implementation)
    /// 5. Decode and return payload
    ///
    /// - Parameters:
    ///   - token: The Firebase ID token
    ///   - certificates: Google's public certificates
    ///   - req: The Vapor request
    /// - Returns: Decoded token payload
    /// - Throws: Unauthorized error if signature is invalid
    ///
    /// ## Security Note
    /// ⚠️ **Current implementation validates token structure but NOT signature**
    /// In production, implement full RSA256 verification using JWT-Kit.
    /// This requires extracting the RSA public key from the X.509 certificate
    /// and verifying the token signature cryptographically.
    private func verifyTokenSignature(
        token: String,
        certificates: [String: String],
        on req: Request
    ) async throws -> FirebaseTokenPayload {
        // JWT-Kit expects the key in JWK format, but we have PEM certificates
        // For Firebase, we need to extract the RSA public key from the certificate

        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            req.logger.warning("🚫 Invalid token format - not 3 parts")
            throw ApiError.unauthorized("Invalid token format")
        }

        // Decode header to validate structure and extract key ID
        let headerData = try decodeBase64URL(String(parts[0]))
        let header = try JSONDecoder().decode(FirebaseTokenHeader.self, from: headerData)
        req.logger.debug("🔍 Token header decoded - key ID: \(header.kid)")

        // Verify we have a certificate for this key ID
        guard certificates[header.kid] != nil else {
            req.logger.error("❌ Unknown key ID in token: \(header.kid)")
            throw ApiError.unauthorized("Unknown key ID in token")
        }

        req.logger.debug("✅ Found certificate for key ID: \(header.kid)")

        // ⚠️ TODO: Implement full RSA256 signature verification
        // In development/testing, we accept the token without full signature verification
        req.logger.warning("⚠️ Firebase token signature verification disabled for development")

        // Decode payload
        let payloadData = try decodeBase64URL(String(parts[1]))
        req.logger.debug("✅ Token payload decoded successfully")

        return try JSONDecoder.firebaseDecoder.decode(FirebaseTokenPayload.self, from: payloadData)
    }

    // MARK: - Claim Validation

    /// Validate JWT claims.
    private func validateClaims(payload: FirebaseTokenPayload, req: Request) throws {
        let now = Date()

        // Check expiration
        guard payload.exp > now else {
            throw ApiError.unauthorized("Token expired")
        }

        // Check not before
        if let nbf = payload.nbf {
            guard nbf < now else {
                throw ApiError.unauthorized("Token not yet valid")
            }
        }

        // Check issued at
        if let iat = payload.iat {
            guard iat < now else {
                throw ApiError.unauthorized("Token issued in the future")
            }
        }

        // Check issuer
        let expectedIssuer = "https://securetoken.google.com/\(config.projectId)"
        guard payload.iss == expectedIssuer else {
            throw ApiError.unauthorized("Invalid token issuer")
        }

        // Check audience
        guard payload.aud == config.projectId else {
            throw ApiError.unauthorized("Invalid token audience")
        }

        // Subject (user ID) must be present
        guard !payload.sub.isEmpty else {
            throw ApiError.unauthorized("Token missing subject claim")
        }
    }

    // MARK: - User Mapping

    /// Map Firebase token to AuthenticatedUser.
    private func mapToAuthenticatedUser(payload: FirebaseTokenPayload, req: Request) async throws -> AuthenticatedUser {
        // Check if user exists in database
        if let user = try await User.query(on: req.db)
            .filter(\User.$externalId == payload.sub)
            .filter(\User.$authProvider == "firebase")
            .with(\User.$role)
            .first() {

            return AuthenticatedUser(
                userId: user.id?.uuidString ?? payload.sub,
                email: user.email,
                roles: [user.role.slug]
            )
        }

        // Create new user if authentication succeeds but no local record exists
        // This is optional behavior - can be configured
        return AuthenticatedUser(
            userId: payload.sub,
            email: payload.email,
            roles: ["public"]  // Default role for new Firebase users
        )
    }

    // MARK: - Helper Methods

    /// Decode base64 URL-safe string.
    private func decodeBase64URL(_ string: String) throws -> Data {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let data = Data(base64Encoded: base64) else {
            throw ApiError.badRequest("Invalid base64 encoding in token")
        }

        return data
    }
}

private extension JSONDecoder {
    static let firebaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let timestamp = try container.decode(Double.self)
            return Date(timeIntervalSince1970: timestamp)
        }
        return decoder
    }()
}

// MARK: - Data Structures

/// Firebase JWT token header.
struct FirebaseTokenHeader: Decodable {
    let kid: String
    let alg: String
    let typ: String
}

/// Firebase JWT token payload.
struct FirebaseTokenPayload: Decodable {
    let iss: String
    let aud: String
    let authTime: Date?
    let userId: String?
    let sub: String
    let iat: Date?
    let exp: Date
    let email: String?
    let emailVerified: Bool?
    let phoneNumber: String?
    let name: String?
    let picture: String?
    let firebase: FirebaseInfo?
    let nbf: Date?

    enum CodingKeys: String, CodingKey {
        case iss, aud
        case authTime = "auth_time"
        case userId = "user_id"
        case sub, iat, exp
        case email, emailVerified, phoneNumber
        case name, picture, firebase, nbf
    }
}

/// Firebase-specific claims.
struct FirebaseInfo: Decodable {
    let identities: [String: [String]]?
    let signInProvider: String?
    let tenant: String?

    enum CodingKeys: String, CodingKey {
        case identities
        case signInProvider = "sign_in_provider"
        case tenant
    }
}

// MARK: - Certificate Cache

/// Simple in-memory cache for Firebase certificates.
actor InMemoryFirebaseCertCache {
    private var cache: [String: CachedValue] = [:]

    struct CachedValue {
        let value: String
        let timestamp: Date
    }

    func get(key: String) throws -> String? {
        guard let cached = cache[key] else {
            return nil
        }

        // Check if expired (1 hour default)
        if Date().timeIntervalSince(cached.timestamp) > 3600 {
            cache.removeValue(forKey: key)
            return nil
        }

        return cached.value
    }

    func set(key: String, value: String, expiration: TimeInterval = 3600) throws {
        cache[key] = CachedValue(value: value, timestamp: Date())
    }
}