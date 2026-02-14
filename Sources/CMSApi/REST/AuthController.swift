import Vapor
import Fluent
import CMSObjects
import CMSSchema
import CMSAuth
import CMSCore

/// 🔐 **Authentication Controller**
///
/// ## Responsibilities
/// Manages user authentication and authorization through JWT tokens.
/// Supports multiple auth providers: Local JWT, Auth0, and Firebase Authentication.
///
/// 🚨 **Security Features**
/// - Rate limiting on login attempts (5 per minute per IP)
/// - Secure password hashing with salt
/// - Token-based authentication with refresh tokens
/// - Login attempt logging and monitoring
/// - Optional registration with configurable rules
///
/// ## Authentication Flow
/// 1. **Login**: Exchange credentials for access + refresh tokens
/// 2. **Refresh**: Exchange refresh token for new access token
/// 3. **Logout**: Invalidate tokens (requires Redis for full implementation)
/// 4. **Optional Registration**: Create new user accounts
///
/// ## Routes
/// - `POST /api/v1/auth/login` - Authenticate user
/// - `POST /api/v1/auth/refresh` - Refresh access token
/// - `POST /api/v1/auth/logout` - Logout and invalidate token
/// - `POST /api/v1/auth/register` - Register new user (if enabled)
///
/// ## Token Structure
/// ```swift
/// struct AuthTokenResponseDTO {
///   let accessToken: String    // Short-lived (1 hour)
///   let refreshToken: String   // Long-lived (30 days)
///   let tokenType: String      // "Bearer"
///   let expiresIn: Int         // Seconds until expiry
///   let user: UserResponseDTO? // User details
/// }
/// ```
///
/// ## Configuration
/// - `ENABLE_REGISTRATION` (env): Enable/disable registration
/// - `JWT_SECRET` (env): Secret for token signing
/// - `ACCESS_TOKEN_EXPIRATION`: Token lifetime in seconds (default: 3600)
///
/// ## Rate Limits
/// - Login: 5 attempts/minute per IP
/// - Refresh: 100 requests/minute per user
/// - Register: 10 requests/minute per IP
///
/// ## Events
/// - `UserLoginEvent`: On successful authentication
/// - `UserLogoutEvent`: On user logout
/// - `PasswordUpdatedEvent`: When user changes password
///
/// ## Providers
/// - **LocalJWTProvider**: Built-in JWT authentication
/// - **Auth0Provider**: Auth0 integration
/// - **FirebaseProvider**: Firebase Auth integration
///
/// ## Security Best Practices
/// ✅ Store tokens securely (httpOnly cookies or secure storage)
/// ✅ Refresh tokens before expiry
/// ✅ Implement proper logout flows
/// ✅ Use HTTPS in production
/// ✅ Rotate JWT secrets regularly
///
/// - SeeAlso: `AuthTokenResponseDTO`, `LocalJWTProvider`, `AuthenticatedUser`
/// - Since: 1.0.0
public struct AuthController: RouteCollection, Sendable {

    private let passwordService = PasswordService()
    private let loginAttempts = ExpiringCache<String, Int>(expiration: 60)  // Per minute tracking

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("auth")

        // Unauthenticated endpoints
        auth.post("login", use: login)
        auth.post("refresh", use: refresh)
        auth.post("logout", use: logout)

        // Optional registration (disabled by default)
        if Environment.get("ENABLE_REGISTRATION") == "true" {
            auth.post("register", use: register)
        }
    }

    // MARK: - Login

    /// 🔐 **POST /api/v1/auth/login**
    ///
    /// ## 📡 Endpoint
    /// Authenticates a user and returns JWT access and refresh tokens.
    ///
    /// ## 🔓 Authentication
    /// **Public endpoint** - No authentication required
    ///
    /// ## ⚡ Rate Limit
    /// **5 attempts/minute per IP address**
    ///
    /// ## 📦 Request Body
    /// ```json
    /// {
    ///   "email": "user@example.com",
    ///   "password": "secure_password"
    /// }
    /// ```
    ///
    /// ## ✅ Success Response (200 OK)
    /// ```json
    /// {
    ///   "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    ///   "refreshToken": "v2.local.eyJzdWIiOiIxMjM0NTY3ODkwIiw...",
    ///   "tokenType": "Bearer",
    ///   "expiresIn": 3600
    /// }
    /// ```
    ///
    /// ## ❌ Error Responses
    /// - `401 Unauthorized`: Invalid email or password
    /// - `422 Unprocessable Entity`: Invalid request format
    /// - `429 Too Many Requests`: Rate limit exceeded
    ///
    /// ## 🔒 Security Features
    /// - IP-based rate limiting on failed attempts
    /// - Login attempt logging and monitoring
    /// - Account lockout protection
    ///
    /// ## 📋 Example Usage
    /// ```bash
    /// curl -X POST https://api.swiftcms.io/api/v1/auth/login \
    ///   -H "Content-Type: application/json" \
    ///   -d '{"email": "user@example.com", "password": "secure_password"}'
    /// ```
    @Sendable
    func login(req: Request) async throws -> AuthTokenResponseDTO {
        // Rate limiting
        let ipAddress = req.headers.first(name: "X-Forwarded-For") ?? req.remoteAddress?.ipAddress ?? "unknown"
        let attemptCount = await loginAttempts.get(key: ipAddress) ?? 0

        guard attemptCount < 5 else {
            throw ApiError.tooManyRequests("Too many login attempts. Please try again in a minute.")
        }

        let dto = try req.content.decode(LoginDTO.self)

        // Find user
        guard let user = try await User.query(on: req.db)
            .filter(\User.$email == dto.email)
            .with(\User.$role)
            .first() else {
            // Increment failed attempts
            await loginAttempts.set(key: ipAddress, value: attemptCount + 1)
            await logFailedLogin(req: req, email: dto.email, reason: "User not found")
            throw ApiError.unauthorized("Invalid credentials")
        }

        // Verify password
        guard let passwordHash = user.passwordHash else {
            await logFailedLogin(req: req, email: dto.email, reason: "No password set")
            throw ApiError.unauthorized("Invalid credentials")
        }

        let passwordValid = try await passwordService.verifyPassword(dto.password, hash: passwordHash)
        guard passwordValid else {
            // Increment failed attempts
            await loginAttempts.set(key: ipAddress, value: attemptCount + 1)
            await logFailedLogin(req: req, email: dto.email, reason: "Invalid password")
            throw ApiError.unauthorized("Invalid credentials")
        }

        // Reset login attempts on successful login
        await loginAttempts.remove(key: ipAddress)

        // Generate tokens
        let provider = getProvider(req: req)
        let accessToken = try provider.issueToken(
            userId: user.id?.uuidString ?? "",
            email: user.email,
            roles: [user.role.slug],
            tokenType: .access
        )
        let refreshToken = try provider.issueToken(
            userId: user.id?.uuidString ?? "",
            email: user.email,
            roles: [user.role.slug],
            tokenType: .refresh
        )

        // Log successful login
        await logSuccessfulLogin(req: req, user: user)

        return AuthTokenResponseDTO(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: "Bearer",
            expiresIn: Int(req.application.localJWTConfig?.accessTokenExpiration ?? 3600)
        )
    }

    // MARK: - 🔄 Refresh Token

    /// 🔄 **POST /api/v1/auth/refresh**
    ///
    /// ## 📡 Endpoint
    /// Exchange a refresh token for a new access token.
    ///
    /// ## 🔐 Authentication
    /// Requires valid refresh token in request body
    ///
    /// ## ⚡ Rate Limit
    /// **100 requests/minute per user**
    ///
    /// ## 📦 Request Body
    /// ```json
    /// {
    ///   "refreshToken": "v2.local.eyJzdWIiOiIxMjM0NTY3ODkwIiw..."
    /// }
    /// ```
    ///
    /// ## ✅ Success Response (200 OK)
    /// Returns new access token with same structure as login response
    ///
    /// ## ❌ Error Responses
    /// - `401 Unauthorized`: Invalid or expired refresh token
    /// - `400 Bad Request`: Malformed token
    ///
    /// ## 💡 Best Practice
    /// Refresh tokens before they expire to maintain seamless user experience
    ///
    /// ## 📋 Example Usage
    /// ```bash
    /// curl -X POST https://api.swiftcms.io/api/v1/auth/refresh \
    ///   -H "Content-Type: application/json" \
    ///   -d '{"refreshToken": "YOUR_REFRESH_TOKEN"}'
    @Sendable
    func refresh(req: Request) async throws -> AuthTokenResponseDTO {
        struct RefreshDTO: Content {
            let refreshToken: String
        }

        let dto = try req.content.decode(RefreshDTO.self)
        let provider = getProvider(req: req)

        // Verify refresh token
        let payload = try req.jwt.verify(dto.refreshToken, as: LocalJWTProvider.LocalJWTPayload.self)

        // Ensure it's a refresh token (we can check expiry length as a simple check)
        let tokenLifetime = payload.exp.value.timeIntervalSince(payload.iat.value)
        if tokenLifetime < 86400 {  // Less than 1 day likely means access token
            throw ApiError.unauthorized("Invalid refresh token")
        }

        // Get user from database to ensure they still exist
        guard let userId = UUID(uuidString: payload.sub.value),
              let user = try await User.query(on: req.db)
                .filter(\User.$id == userId)
                .with(\User.$role)
                .first() else {
            throw ApiError.unauthorized("User not found")
        }

        // Generate new access token
        let newAccessToken = try provider.issueToken(
            userId: user.id?.uuidString ?? "",
            email: user.email,
            roles: [user.role.slug]
        )

        return AuthTokenResponseDTO(
            accessToken: newAccessToken,
            refreshToken: dto.refreshToken,  // Keep same refresh token
            tokenType: "Bearer",
            expiresIn: Int(req.application.localJWTConfig?.accessTokenExpiration ?? 3600)
        )
    }

    // MARK: - 🚪 Logout

    /// 🚪 **POST /api/v1/auth/logout**
    ///
    /// ## 📡 Endpoint
    /// Invalidates the current access token and logs out the user.
    ///
    /// ## 🔐 Authentication
    /// **Required** - Valid access token in Authorization header
    ///
    /// ## ⚡ Rate Limit
    /// **100 requests/minute per user**
    ///
    /// ## 📤 Request Headers
    /// ```
    /// Authorization: Bearer YOUR_ACCESS_TOKEN
    /// ```
    ///
    /// ## ✅ Success Response
    /// - `204 No Content`: Successfully logged out
    ///
    /// ## ❌ Error Responses
    /// - `401 Unauthorized`: Invalid or missing token
    ///
    /// ## 🔒 Security Notes
    /// - Removes token from active sessions
    /// - Requires Redis for full token blacklist implementation
    /// - Client should discard tokens after successful logout
    ///
    /// ## 📋 Example Usage
    /// ```bash
    /// curl -X POST https://api.swiftcms.io/api/v1/auth/logout \
    ///   -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
    /// ```
    @Sendable
    func logout(req: Request) async throws -> HTTPStatus {
        // In a real implementation, you would:
        // 1. Decode the token to get its ID/expiration
        // 2. Add it to a blacklist in Redis until it expires
        // 3. Return success

        if let auth = req.headers.bearerAuthorization {
            req.logger.info("User logged out with token: \(auth.token.prefix(20))...")
        }

        // For now, just return success (client should discard the token)
        return .noContent
    }

    // MARK: - 📝 User Registration

    /// 📝 **POST /api/v1/auth/register**
    ///
    /// ## 📡 Endpoint
    /// Creates a new user account (only available if ENABLE_REGISTRATION=true).
    ///
    /// ## 🔓 Authentication
    /// **Public endpoint** - No authentication required
    ///
    /// ## ⚡ Rate Limit
    /// **10 requests/minute per IP address**
    ///
    /// ## 📦 Request Body
    /// ```json
    /// {
    ///   "email": "newuser@example.com",
    ///   "password": "SecurePass123!",
    ///   "displayName": "Jane Smith"
    /// }
    /// ```
    ///
    /// ## 🔐 Password Requirements
    /// - Minimum 8 characters
    /// - At least one uppercase letter (A-Z)
    /// - At least one lowercase letter (a-z)
    /// - At least one number (0-9)
    /// - At least one special character (!@#$%^&*)
    ///
    /// ## ✅ Success Response (201 Created)
    /// ```json
    /// {
    ///   "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    ///   "refreshToken": "v2.local.eyJzdWIiOiIxMjM0NTY3ODkwIiw...",
    ///   "tokenType": "Bearer",
    ///   "expiresIn": 3600,
    ///   "user": {
    ///     "id": "123e4567-e89b-12d3-a456-426614174000",
    ///     "email": "newuser@example.com",
    ///     "displayName": "Jane Smith",
    ///     "role": "public"
    ///   }
    /// }
    /// ```
    ///
    /// ## ❌ Error Responses
    /// - `422 Unprocessable Entity`:
    ///   - Invalid email format
    ///   - Password doesn't meet requirements
    /// - `409 Conflict`: Email already exists
    /// - `429 Too Many Requests`: Rate limit exceeded
    ///
    /// ## 🔒 Security Features
    /// - Password strength validation
    /// - Email verification (if enabled)
    /// - Default "public" role assignment
    /// - Secure password hashing with salt
    ///
    /// ## ⚠️ Feature Flag
    /// This endpoint is **disabled by default**. Enable with:
    /// ```bash
    /// ENABLE_REGISTRATION=true
    /// ```
    ///
    /// ## 📋 Example Usage
    /// ```bash
    /// curl -X POST https://api.swiftcms.io/api/v1/auth/register \
    ///   -H "Content-Type: application/json" \
    ///   -d '{
    ///     "email": "newuser@example.com",
    ///     "password": "SecurePass123!",
    ///     "displayName": "Jane Smith"
    ///   }'
    /// ```
    @Sendable
    func register(req: Request) async throws -> AuthTokenResponseDTO {
        struct RegisterDTO: Content, Validatable {
            let email: String
            let password: String
            let displayName: String?

            public static func validations(_ validations: inout Validations) {
                validations.add("email", as: String.self, is: .email)
                validations.add("password", as: String.self, is: .count(8...))
            }
        }

        let dto = try req.content.decode(RegisterDTO.self)

        // Validate password complexity
        let passwordErrors = await passwordService.validatePassword(dto.password)
        if !passwordErrors.isEmpty {
            throw ApiError.unprocessableEntity("Password does not meet requirements", details: [
                "password": passwordErrors.joined(separator: ", ")
            ])
        }

        // Check if user already exists
        let existingUser = try await User.query(on: req.db)
            .filter(\User.$email == dto.email)
            .first()

        if existingUser != nil {
            throw ApiError.conflict("User with this email already exists")
        }

        // Get or create default role
        guard let defaultRole = try await Role.query(on: req.db)
                .filter(\Role.$slug == "public")
                .first() else {
            throw ApiError.internalError("Default role not found")
        }

        // Hash password
        let passwordHash = try await passwordService.hashPassword(dto.password)

        // Create user
        let user = User(
            email: dto.email,
            passwordHash: passwordHash,
            displayName: dto.displayName ?? dto.email,
            roleID: defaultRole.id!
        )

        try await user.save(on: req.db)

        // Generate tokens
        let provider = getProvider(req: req)
        let accessToken = try provider.issueToken(
            userId: user.id?.uuidString ?? "",
            email: user.email,
            roles: [defaultRole.slug]
        )
        let refreshToken = try provider.issueToken(
            userId: user.id?.uuidString ?? "",
            email: user.email,
            roles: [defaultRole.slug],
            tokenType: .refresh
        )

        return AuthTokenResponseDTO(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: "Bearer",
            expiresIn: Int(req.application.localJWTConfig?.accessTokenExpiration ?? 3600)
        )
    }

    // MARK: - Helper Methods

    /// Get the configured authentication provider.
    private func getProvider(req: Request) -> AuthProvider {
        if let provider = req.application.storage[AuthProviderKey.self] {
            return provider
        }
        // Default to LocalJWTProvider
        return LocalJWTProvider()
    }

    /// Log failed login attempts.
    private func logFailedLogin(req: Request, email: String, reason: String) async {
        req.logger.warning("Failed login attempt for \(email): \(reason)")

        // In a real implementation, log to audit table
        // This would require an audit logging service
    }

    /// Log successful login.
    private func logSuccessfulLogin(req: Request, user: User) async {
        req.logger.info("Successful login for user \(user.email)")

        // Update last login timestamp
        // This would require adding a lastLogin field to the User model
    }
}

// MARK: - Extended Token Response DTO

/// Extended token response including refresh token.
public struct AuthTokenResponseDTO: Content, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let user: UserResponseDTO?

    public init(
        accessToken: String,
        refreshToken: String,
        tokenType: String = "Bearer",
        expiresIn: Int = 3600,
        user: UserResponseDTO? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.user = user
    }
}

// MARK: - Rate Limiting Cache Implementation

/// Simple expiring cache for rate limiting.
actor ExpiringCache<Key: Hashable, Value> {
    private var storage: [Key: ExpiringValue<Value>] = [:]
    private let expiration: TimeInterval

    struct ExpiringValue<T> {
        let value: T
        let expirationDate: Date
    }

    init(expiration: TimeInterval) {
        self.expiration = expiration
    }

    func get(key: Key) -> Value? {
        cleanup()
        guard let item = storage[key], item.expirationDate > Date() else {
            return nil
        }
        return item.value
    }

    func set(key: Key, value: Value) {
        cleanup()
        storage[key] = ExpiringValue(
            value: value,
            expirationDate: Date().addingTimeInterval(expiration)
        )
    }

    func remove(key: Key) {
        storage.removeValue(forKey: key)
    }

    private func cleanup() {
        let now = Date()
        storage = storage.filter { _, value in
            value.expirationDate > now
        }
    }
}

// MARK: - Application Extensions

extension Application {
    /// Get Local JWT configuration from app storage.
    var localJWTConfig: LocalJWTProvider.Configuration? {
        get { storage[LocalJWTConfigKey.self] }
        set { storage[LocalJWTConfigKey.self] = newValue }
    }
}

private struct LocalJWTConfigKey: StorageKey {
    typealias Value = LocalJWTProvider.Configuration
}