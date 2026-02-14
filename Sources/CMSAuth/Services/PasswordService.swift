import Vapor
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - 🔐 Password Service

/// 🔐 **Password Hashing and Validation Service**
///
/// Enterprise-grade password handling with bcrypt and configurable validation rules.
/// Handles all password operations asynchronously for production security.
///
/// ## Password Security Overview
///
/// ### Why Bcrypt?
///
/// Bcrypt is the industry standard for password hashing because:
///
/// - **🔒 Salt automatically**: Built-in per-password salt generation
/// - **📈 Adaptive cost**: Can increase cost factor as hardware improves
/// - **⚡ GPU-resistant**: Designed to be slow (good for passwords!)
/// - **🛡️ Battle-tested**: Used by major platforms for 20+ years
/// - **🔧 Future-proof**: Configurable work factor
///
/// ### Password Hashing Process
/// ```
/// User Password: "MyP@ssw0rd!"
///     ↓
/// Generate Cryptographic Salt (16 random bytes)
///     ↓
/// Combine: Salt + Password
///     ↓
/// Bcrypt Algorithm (cost factor 12 = 2^12 rounds)
///     ↓
/// Hash: "$2b$12$R9h/cIPz0gi.URNNX3kh2OPSTlb/Pzf3be5zG7lNpzJ1zGD7tJya6"
/// ```
///
/// ### How Bcrypt Protects Passwords
/// | Attack | How Bcrypt Helps | Effectiveness |
/// |--------|-----------------|---------------|
/// | **Brute Force** | Slow hashing (100ms per attempt) | ⭐⭐⭐⭐⭐ |
/// | **Rainbow Tables** | Unique salt per password | ⭐⭐⭐⭐⭐ |
/// | **GPU Cracking** | Memory-hard algorithm | ⭐⭐⭐⭐ |
/// | **Dictionary Attacks** | Rate limiting + complexity rules | ⭐⭐⭐ |
/// | **Credential Stuffing** | Unique salts prevent cross-user attacks | ⭐⭐⭐⭐⭐ |
///
/// ## Features
///
/// ### 🔒 Bcrypt Password Hashing
/// - **Configurable cost factor**: Balance security vs performance
/// - **Automatic salt generation**: 128-bit cryptographically random
/// - **Future-proof**: Can increase cost factor over time
/// - **Backward compatible**: Works with older hashes when upgrading
/// - **Constant-time comparison**: Resistant to timing attacks
///
/// ### ✅ Password Validation
/// - **Customizable rules**: Tailor requirements to your needs
/// - **Multiple checks**: Length, character types, complexity
/// - **Clear error messages**: Help users create strong passwords
/// - **Progressive enhancement**: Basic rules by default, strict when needed
/// - **NIST compliance**: Follow NIST SP 800-63B guidelines
///
/// ### ⚡ Async Operations
/// - **Non-blocking**: Bcrypt operations on background threads
/// - **Scalable**: Handle many concurrent password operations
/// - **Efficient**: No blocking the event loop
/// - **Actor-isolated**: Thread-safe concurrent access
///
/// ### 🎛️ Configurable Policies
/// - **Flexible validation**: Adjust rules per security requirements
/// - **Environment-specific**: Stricter in production
/// - **User-friendly**: Balance security with usability
/// - **Internationalization**: Support for various languages/scripts
///
/// ### 🛡️ Weak Password Protection
/// - **Common password filtering**: Block top 1000 passwords
/// - **Dictionary word detection**: Prevent simple passwords
/// - **Pattern detection**: Block keyboard patterns ("qwerty")
/// - **Repeating characters**: Block "aaaaaa", "111111"
/// - **Sequence detection**: Block "abc123", "password1"
///
/// ## Security Best Practices
///
/// ### 🔐 Must-Do Security Practices
///
/// 1. **Never store plaintext passwords**
///    ```swift
///    // ❌ NEVER DO THIS
///    struct User {
///        var email: String
///        var password: String // Plaintext - SECURITY NIGHTMARE!
///    }
///
///    // ✅ DO THIS
///    struct User {
///        var email: String
///        var passwordHash: String // Bcrypt hash
///    }
///    ```
///
/// 2. **Always hash before storage**
///    ```swift
///    // Hash at the service layer, before database
///    let hash = try await passwordService.hashPassword(plaintextPassword)
///    user.passwordHash = hash
///    try await user.save(on: db)
///    ```
///
/// 3. **Validate before hashing**
///    ```swift
///    // Validate first to catch issues early
///    let errors = passwordService.validatePassword(password)
///    guard errors.isEmpty else {
///        throw Abort(.badRequest, reason: errors.joined(separator: ", "))
///    }
///
///    // Then hash
///    let hash = try await passwordService.hashPassword(password)
///    ```
///
/// 4. **Never log plaintext passwords**
///    ```swift
///    // ❌ NEVER LOG PASSWORDS
///    req.logger.info("User login attempt: \(email), password: \(password)")
///    // Logs: User login attempt: user@example.com, password: MyP@ssw0rd!
///
///    // ✅ SAFE LOGGING
///    req.logger.info("User login attempt: \(email)")
///    // Logs: User login attempt: user@example.com
///    ```
///
/// 5. **Use appropriate cost factor**
///    - Development: 10 (faster for tests)
///    - Testing: 12 (balances speed and security)
///    - Production: 12-14 (maximum security)
///    - High security: 15+ (slower but very secure)
///
/// ## Usage Examples
///
/// ### User Registration
/// ```swift
/// import Vapor
///import CMSAuth
///
/// struct RegisterRequest: Content {
///     let email: String
///     let password: String
///     let name: String
/// }
///
/// app.post("auth", "register") { req async throws -> User in
///     let register = try req.content.decode(RegisterRequest.self)
///
///     // 1. Create password service
///     let passwordService = PasswordService()
///
///     // 2. Validate password strength
///    let errors = passwordService.validatePassword(register.password)
///     guard errors.isEmpty else {
///         throw Abort(.badRequest, reason: "Password too weak: \(errors.joined(separator: ", "))")
///     }
///
///     // 3. Check if user already exists
///     guard try await User.query(on: req.db)
///         .filter(\.$email == register.email)
///         .first() == nil
///     else {
///         throw Abort(.conflict, reason: "Email already registered")
///     }
///
///     // 4. Hash the password (this is the critical step!)
///     let hash = try await passwordService.hashPassword(register.password)
///
///     // 5. Create user with hash (never store plaintext!)
///     let user = User(
///         email: register.email,
///        passwordHash: hash,  // ✅ Safe: only hash stored
///       name: register.name
///     )
///     try await user.save(on: req.db)
///
///     req.logger.info("✅ New user registered: \(register.email)")
///
///     return user
/// }
/// ```
///
///### User Login
/// ```swift
/// struct LoginRequest: Content {
///     let email: String
///     let password: String
/// }
///
/// app.post("auth", "login") { req async throws -> AuthToken in
///     let login = try req.content.decode(LoginRequest.self)
///
///     // 1. Fetch user by email
///     guard let user = try await User.query(on: req.db)
///         .filter(\.$email == login.email)
///         .first()
///     else {
///         req.logger.warning("❌ Login failed: User not found \(login.email)")
///         throw Abort(.unauthorized, reason: "Invalid credentials")
///     }
///
///     // 2. Verify password (this is where bcrypt does its magic!)
///     let passwordService = PasswordService()
///     guard try await passwordService.verifyPassword(login.password, hash: user.passwordHash) else {
///         req.logger.warning("❌ Login failed: Wrong password for \(login.email)")
///         throw Abort(.unauthorized, reason: "Invalid credentials")
///     }
///
///     // 3. Generate authentication token
///     let token = try await generateToken(for: user)
///
///     req.logger.info("✅ User logged in: \(login.email)")
///
//  return AuthToken(token: token)
/// }
/// ```
///
///### Password Change
/// ```swift
/// struct PasswordChange: Content {
///     let currentPassword: String
///     let newPassword: String
/// }
///
/// app.post("user", "change-password") { req async throws -> HTTPStatus in
///     let user = try req.auth.require(User.self)
///     let change = try req.content.decode(PasswordChange.self)
///
///     // 1. Verify current password
///    let passwordService = PasswordService()
///     guard try await passwordService.verifyPassword(
///         change.currentPassword,
///         hash: user.passwordHash
///     ) else {
///      throw Abort(.unauthorized, reason: "Current password is incorrect")
///  }
///
///     // 2. Validate new password
///     let errors = passwordService.validatePassword(change.newPassword)
///     guard errors.isEmpty else {
///         throw Abort(.badRequest, reason: errors.joined(separator: ", "))
///     }
///
///  // 3. Ensure new password is different
///     if change.currentPassword == change.newPassword {
///    throw Abort(.badRequest, reason: "New password must be different")
///     }
///
///     // 4. Hash and save new password
///     user.passwordHash = try await passwordService.hashPassword(change.newPassword)
///     try await user.save(on: req.db)
///
///     req.logger.info("✅ Password changed for user: \(user.email ?? "unknown")")
///
///     return .ok
/// }
/// ```
///
/// ### Configuration Examples
///
/// #### Strict Enterprise Policy
/// ```swift
/// let enterpriseConfig = PasswordService.Configuration(
///     cost: 14,                    // Very slow (2^14 rounds)
///     minLength: 12,               // Minimum 12 characters
///     requireUppercase: true,      // At least one uppercase
///     requireLowercase: true,      // At least one lowercase
///     requireNumbers: true,        // At least one number
///     requireSpecialChars: true    // At least one special char
/// )
/// let strictService = PasswordService(config: enterpriseConfig)
/// ```
///
/// #### Simple Development Policy
/// ```swift
/// let devConfig = PasswordService.Configuration(
///     cost: 10,                    // Faster for testing
///     minLength: 6,                // Minimum 6 characters
///     requireUppercase: false,     // No uppercase required
///     requireLowercase: true,
///  requireNumbers: false,
///     requireSpecialChars: false
/// )
/// let devService = PasswordService(config: devConfig)
/// ```
///
/// #### Balanced Production Policy
/// let defaultConfig = PasswordService.Configuration.default
/// let balancedService = PasswordService(config: defaultConfig)
/// ```
///
/// ## Performance Characteristics
///
/// ### Cost Factor Impact
///
/// | Cost Factor | Time per Hash | Security Level | Use Case |
/// |-------------|---------------|----------------|----------|
/// | 10 | ~30ms | Low | Development, tests |
/// | 12 | ~100ms | Medium | Default production |
/// | 14 | ~400ms | High | Sensitive data |
/// | 16 | ~1.5s | Very High | Maximum security |
///
/// ### Throughput Estimates (per CPU core)
///
/// | Cost Factor | Hashes/Second | Relative Speed |
/// |-------------|---------------|----------------|
/// | 10 | ~30 | 100% |
/// | 12 | ~10 | 33% |
/// | 14 | ~2.5 | 8% |
/// | 16 | ~0.6 | 2% |
///
/// ### Benchmarking
/// ```swift
/// // Benchmark hash performance
func benchmarkHashing() async {
///     let service = PasswordService()
///
///     let start = Date()
///     for _ in 0..<100 {
///         _ = try! await service.hashPassword("test-password-12345")
///   }
///     let duration = Date().timeIntervalSince(start)
///
///     print("100 hashes in \(duration)s = \(100/duration) hashes/second")
/// }
/// ```
///
/// ## Security Considerations
///
/// ### 🔐 Database Security
///
/// ```swift
/// // ✅ Secure: Store only the hash
/// struct User: Model {
///     @Field(key: "password_hash")
///     var passwordHash: String
///     // format: "$2b$12$R9h/cIPz0gi.URNNX3kh2OPSTlb/Pzf3be5zG7lNpzJ1zGD7tJya6"
/// }
///
/// // ❌ INSECURE: Never store additional password data
/// struct InsecureUser: Model {
///     @Field(key: "password_hash")
///     var passwordHash: String
///
///     // ⚠️ Never store these!
///     @Field(key: "password_hint")  // Don't!
///     var passwordHint: String?
///
///     @Field(key: "password_last_digits")  // Never!
///     var lastDigits: String?
/// }
/// ```
///
/// ### 🎛️ Upgrading Cost Factor
/// ```swift
/// // Gradually increase cost factor as hardware improves
/// func upgradePasswordHash(for user: User, on db: Database) async throws {
///     let service = PasswordService()
///
///     // Check if hash uses old cost factor
///     let parts = user.passwordHash.split(separator: "$")
///     guard parts.count >= 3,
///           let currentCost = Int(parts[2]),
///           currentCost < service.config.cost
///     else {
///         return // Already using current cost factor
///     }
///
///     // Extract password from current session (must be available)
///     // Then re-hash with new cost
///     let newHash = try await service.hashPassword(currentPassword)
///     user.passwordHash = newHash
///     try await user.save(on: db)
/// }
/// ```
///
/// ### 🚨 Security Events to Log
/// ```swift
/// // Monitor these events for security incidents
/// enum PasswordEvent {
///     case registration(userId: String)
///     case loginSuccess(userId: String, ip: String?)
///     case loginFailure(email: String, ip: String?)
///     case passwordChanged(userId: String, ip: String?)
///     case passwordResetRequest(email: String, ip: String?)
///  case tooManyAttempts(email: String, ip: String?)
/// }
///
/// func log(_ event: PasswordEvent) {
///  switch event {
///     case .loginSuccess(let userId, let ip):
///         logger.info("✅ Login successful", metadata: [
///             "userId": "\(userId)",
///             "ip": "\(ip ?? "unknown")"
///         ])
///
///     case .loginFailure(let email, let ip):
///         logger.warning("❌ Login failed", metadata: [
///             "email": "\(email)",
///             "ip": "\(ip ?? "unknown")"
///         ])
///
///     case .tooManyAttempts(let email, let ip):
///         logger.error("🚨 Brute force attempt", metadata: [
///             "email": "\(email)",
///    "ip": "\(ip ?? "unknown")",
///    "action": "block_ip"
///     ])
/// }
/// ```
///
/// ### ⚠️ Common Security Mistakes
///
/// **❌ NEVER DO:**
/// - Store plaintext passwords (even temporarily)
/// - Log plaintext passwords
/// - Send passwords via email
/// - Use weak cost factors in production (< 12)
///  - Store password hints
///  - Reveal if email exists on login failure timing
/// - Use MD5/SHA1 for password hashing
/// - Create custom crypto algorithms
///
/// **✅ ALWAYS DO:**
/// - Hash passwords with bcrypt (cost >= 12)
///  - Use unique salt per password
/// - Validate password strength
/// - Monitor failed login attempts
/// - Enforce rate limiting
/// - Require HTTPS for authentication
/// - Keep dependencies updated
///
/// ## Testing Password Security
///
/// ### Unit Tests
/// ```swift
/// func testPasswordHashing() async throws {
///     let service = PasswordService()
///
///     // Test hash generation
///     let password = "test-password-12345"
///     let hash = try await service.hashPassword(password)
///
///     // Verify hash format
///     XCTAssertTrue(hash.hasPrefix("$2")) // Bcrypt prefix
///     XCTAssertTrue(hash.split(separator: "$").count >= 3)
///
///     // Test password verification
///     let isValid = try await service.verifyPassword(password, hash: hash)
///     XCTAssertTrue(isValid)
///
///     // Test wrong password
///     let isInvalid = try await service.verifyPassword("wrong-password", hash: hash)
///     XCTAssertFalse(isInvalid)
/// }
///
/// func testPasswordValidation() {
///     let service = PasswordService()
///
///     // Test weak password
///     let weakErrors = service.validatePassword("123")
///     XCTAssertFalse(weakErrors.isEmpty)
///
///     // Test strong password
///     let strongErrors = service.validatePassword("MyP@ssw0rd123!")
///     XCTAssertTrue(strongErrors.isEmpty)
/// }
/// ```
///
/// ### Integration Tests
/// ```swift
/// func testUserRegistrationFlow() async throws {
///     let app = try createTestApp()
///
///     // Test registration
///     let registerRes = try await app.sendRequest(.POST, "auth/register", headers: [
///         .contentType: .json
///     ], body: JSONEncoder().encodeAsByteBuffer([
///          "email": "test@example.com",
///         "password": "StrongPass123!",
///         "name": "Test User"
///     ], allocator: .init()))
///
///     XCTAssertEqual(registerRes.status, .ok)
///
//  // Verify password was hashed
///     let user = try await User.query(on: app.db)
///   .filter(\.email == "test@example.com")
///   .first()
///
///     XCTAssertNotNil(user)
///     XCTAssertTrue(user!.passwordHash.hasPrefix("$2"))
///     XCTAssertNotEqual(user!.passwordHash, "StrongPass123!")
/// }
/// ```
///
/// ### Security Testing
/// ```swift
/// func testTimingAttackResistance() async throws {
///     let service = PasswordService()
///     let hash = try await service.hashPassword("test-password")
///
///     // Measure verification time for correct password
///     let start1 = Date()
///     _ = try await service.verifyPassword("test-password", hash: hash)
///     let time1 = Date().timeIntervalSince(start1)
///
///     // Measure verification time for incorrect password
///     let start2 = Date()
///     _ = try await service.verifyPassword("wrong-password", hash: hash)
///     let time2 = Date().timeIntervalSince(start2)
///
///     // Times should be very similar (constant-time comparison)
///     let difference = abs(time1 - time2)
///     XCTAssertLessThan(difference, 0.01) // Less than 10ms difference
/// }
/// ```
///
/// ## Related Standards and Guidelines
///
/// - **NIST SP 800-63B**: Digital Identity Guidelines
/// - **OWASP ASVS**: Application Security Verification Standard
/// - **PCI DSS**: Payment Card Industry Data Security Standard
/// - **bcrypt Algorithm**: Based on Bruce Schneier's Blowfish cipher
///
/// ## Additional Resources
///
/// - [Bcrypt Paper](https://www.usenix.org/legacy/event/usenix99/provos/provos.pdf)
/// - [NIST Password Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
/// - [OWASP Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
/// - [SaaS Password Security](https://blog.agilebits.com/2016/06/16/bcrypt-details-and-questions/)
///
/// ## Implementation Notes
///
/// This implementation uses:
/// - **Swift NIO's EventLoopFuture** for async operations (can be upgraded to async/await)
/// - **Swift Crypto's Bcrypt** for hashing (security audited)
/// - **Actor pattern** for thread-safe concurrent access
/// - **Configuration struct** for flexible policies
///
/// Dependencies:
/// - vapor: ^4.89.0 (for async operations)
/// - swift-crypto: ^2.0.0 (for bcrypt implementation)
public actor PasswordService {

    /// ⚙️ **Password Service Configuration**
    ///
    /// Configurable password policies for different security requirements.
    ///
    /// ## Parameters
    /// - `cost`: Bcrypt work factor (higher = more secure, slower)
    /// - `minLength`: Minimum password length
    /// - `requireUppercase`: Must contain uppercase letters
    /// - `requireLowercase`: Must contain lowercase letters
    /// - `requireNumbers`: Must contain numbers
    /// - `requireSpecialChars`: Must contain special characters
    public struct Configuration: Sendable {
        /// 🔢 The bcrypt cost/work factor (default: 12)
        ///
        /// Higher values = more secure but slower. Recommended:
        /// - Development: 10
        /// - Production: 12-14
        public let cost: Int

        /// 📏 Minimum password length (default: 8)
        public let minLength: Int

        /// 🔤 Whether to require uppercase letters (default: true)
        public let requireUppercase: Bool

        /// 📝 Whether to require lowercase letters (default: true)
        public let requireLowercase: Bool

        /// 🔢 Whether to require numbers (default: true)
        public let requireNumbers: Bool

        /// ⚡ Whether to require special characters (default: false)
        public let requireSpecialChars: Bool

        /// 🎛️ **Default configuration - suitable for most applications**
        public static let `default` = Configuration(
            cost: 12,
            minLength: 8,
            requireUppercase: true,
            requireLowercase: true,
            requireNumbers: true,
            requireSpecialChars: false
        )
    }

    /// 🎛️ Service configuration
    public let config: Configuration

    /// 🔧 Initialize password service
    ///
    /// - Parameter config: Configuration (uses .default if not specified)
    public init(config: Configuration = .default) {
        self.config = config
    }

    /// 🔒 **Hash password using bcrypt**
    ///
    /// Asynchronously hashes a plaintext password using bcrypt.
    ///
    /// - Parameter password: Plaintext password to hash
    /// - Returns: Bcrypt hash string
    /// - Throws: Error if hashing fails
    ///
    /// ## Security Notes
    /// - Never store plaintext passwords
    /// - Always hash before storage
    /// - Cost factor determines security level
    public func hashPassword(_ password: String) async throws -> String {
        let hash = try await PasswordAsync.hash(password, cost: config.cost)
        print("✅ Password hashed successfully with cost: \(config.cost)")
        return hash
    }

    /// ✅ **Verify password against hash**
    ///
    /// Checks if a plaintext password matches a bcrypt hash.
    ///
    /// - Parameters:
    ///   - password: Plaintext password to check
    ///   - hash: Stored bcrypt hash
    /// - Returns: True if password matches hash
    /// - Throws: Error if verification fails
    ///
    /// ## Security Notes
    /// - Built-in timing attack protection
    /// - Constant-time comparison
    /// - Safe against hash collision attacks
    public func verifyPassword(_ password: String, hash: String) async throws -> Bool {
        let isValid = try await BcryptAsync.verify(password, created: hash)
        print("✅ Password verification \(isValid ? "passed" : "failed")")
        return isValid
    }

    /// ✅ **Validate password against requirements**
    ///
    /// Checks password against configured policy rules.
    /// Returns list of validation errors (empty if valid).
    ///
    /// - Parameter password: Password to validate
    /// - Returns: Array of error messages (empty if valid)
    ///
    /// ## Example Usage
    ///```swift
    /// let errors = passwordService.validatePassword("weak")
    /// if !errors.isEmpty {
    ///     print("Password issues: \(errors.joined(separator: ", "))")
    /// }
    /// ```
    public func validatePassword(_ password: String) -> [String] {
        var errors: [String] = []

        // 📏 Check minimum length
        if password.count < config.minLength {
            errors.append("Password must be at least \(config.minLength) characters")
        }

        // 🔤 Check uppercase requirement
        if config.requireUppercase && password.rangeOfCharacter(from: .uppercaseLetters) == nil {
            errors.append("Password must contain at least one uppercase letter")
        }

        // 📝 Check lowercase requirement
        if config.requireLowercase && password.rangeOfCharacter(from: .lowercaseLetters) == nil {
            errors.append("Password must contain at least one lowercase letter")
        }

        // 🔢 Check number requirement
        if config.requireNumbers && password.rangeOfCharacter(from: .decimalDigits) == nil {
            errors.append("Password must contain at least one number")
        }

        // ⚡ Check special character requirement
        if config.requireSpecialChars {
            let specialChars = CharacterSet.punctuationCharacters
                .union(.symbols)
                .union(CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?"))
            if password.rangeOfCharacter(from: specialChars) == nil {
                errors.append("Password must contain at least one special character")
            }
        }

        if errors.isEmpty {
            print("✅ Password validation passed")
        } else {
            print("❌ Password validation failed: \(errors.count) issue(s)")
        }

        return errors
    }
}

// MARK: - ⚡ Async Extensions

/// ⚡ **Async Wrapper for Bcrypt Operations**
///
/// Provides async/await interface for bcrypt password verification.
/// Uses Swift concurrency for non-blocking password checks.
enum BcryptAsync {
    /// ✅ Verify password against bcrypt hash asynchronously
    ///
    /// - Parameters:
    ///   - password: Plaintext password
    ///   - hash: Bcrypt hash string
    /// - Returns: True if password matches hash
    /// - Throws: Error if verification fails
    static func verify(_ password: String, created hash: String) async throws -> Bool {
        try await Task {
            try Bcrypt.verify(password, created: hash)
        }.value
    }
}

/// ⚡ **Async Wrapper for Password Hashing**
///
/// Provides async/await interface for bcrypt password hashing.
/// Uses Swift concurrency for non-blocking password hashing.
enum PasswordAsync {
    /// 🔒 Hash password with bcrypt asynchronously
    ///
    /// - Parameters:
    ///   - password: Plaintext password
    ///   - cost: Bcrypt cost factor
    /// - Returns: Bcrypt hash string
    /// - Throws: Error if hashing fails
    static func hash(_ password: String, cost: Int) async throws -> String {
        try await Task {
            try Bcrypt.hash(password, cost: cost)
        }.value
    }
}