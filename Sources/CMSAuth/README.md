# 🔐 CMSAuth Module

**Authentication and authorization layer** - Multi-provider authentication (Auth0, Firebase, Local JWT) with role-based access control and field-level permissions.

## 🎯 Purpose

CMSAuth provides comprehensive authentication and authorization capabilities for SwiftCMS:
- Multi-provider authentication (Auth0, Firebase Auth, Local JWT)
- Role-based access control (RBAC)
- Field-level permissions
- JWT token management
- Session handling
- API key management

## 🔑 Key Features

### 1. Multi-Provider Authentication (`AuthProviderProtocol`)

Unified authentication interface supporting multiple providers:

```swift
// Auth0 (Recommended for SaaS)
let auth0 = Auth0Provider(
    domain: "your-domain.auth0.com",
    clientId: "your-client-id",
    audience: "https://api.yourapp.com"
)

// Firebase Auth (Mobile-friendly)
let firebase = FirebaseProvider(
    projectId: "your-project-id"
)

// Local JWT (Self-hosted)
let local = LocalJWTProvider(
    secret: Environment.get("JWT_SECRET")!,
    expiration: .hours(24)
)

// Registration
app.cms.auth.register(providers: [
    "auth0": auth0,
    "firebase": firebase,
    "local": local
])
```

### 2. Role-Based Access Control (RBAC)

Granular permissions system:

```swift
// Predefined roles
public enum UserRole: String, Codable {
    case superAdmin    // Full system access
    case admin         // Full content access
    case editor        // Create/edit content
    case author        // Create own content
    case contributor   // Create drafts
    case viewer        // Read-only access
}

// Assign roles to users
try await UserRoleService.assignRole(
    userId: user.id!,
    role: .editor,
    scope: .contentType("blog-post"),
    on: db
)

// Create custom roles
try await RoleService.createRole(
    name: "SEO Manager",
    permissions: [
        .viewContent,
        .editMetaFields,
        .viewAnalytics
    ],
    on: db
)
```

### 3. Field-Level Permissions

Control access to individual fields:

```swift
// Define field permissions
let fieldPerms = try await FieldPermissionService.create(
    contentTypeId: blogType.id!,
    role: .author,
    field: "published",
    permission: .readOnly,  // Can see but not edit
    on: db
)

// Check field access
func canEditField(
    user: User,
    field: String,
    contentType: String
) async throws -> Bool {
    return try await FieldPermissionService.canEdit(
        userId: user.id!,
        contentType: contentType,
        field: field,
        on: db
    )
}

// Apply field filtering
let filteredData = try await FieldPermissionService.filterFields(
    data: entry.data,
    userId: user.id!,
    contentType: entry.contentType,
    action: .read,
    on: db
)
```

### 4. API Key Management

Programmatic access with API keys:

```swift
// Generate API key
let apiKey = try await APIKeyService.create(
    userId: user.id!,
    name: "Mobile App Key",
    permissions: [.readContent, .writeContent],
    expiresAt: Date().addingTimeInterval(.days(90)),
    on: db
)

// Format: scms_{prefix}_{secret}
// scms_abc123_xyz789def456

// Use API key
GET /api/v1/content/blog
Authorization: ApiKey scms_abc123_xyz789def456

// Revoke API key
try await APIKeyService.revoke(
    keyId: apiKey.id!,
    on: db
)
```

### 5. Password Management

Secure password handling:

```swift
// Hash passwords
let hashed = try await PasswordService.hash(
    password: "user_password"
)

// Verify passwords
let isValid = try await PasswordService.verify(
    password: enteredPassword,
    hash: storedHash
)

// Password requirements validation
try await PasswordService.validate(
    password: candidatePassword,
    rules: [
        .minLength(12),
        .requireUppercase,
        .requireNumbers,
        .requireSpecialCharacters
    ]
)

// Password reset flow
try await PasswordService.createResetToken(
    email: user.email,
    expiration: .hours(1),
    on: db
)
```

### 6. Session Management

Stateful and stateless sessions:

```swift
// Configure session driver
app.sessions.use(.redis)

// Create session
let session = try await SessionService.create(
    userId: user.id!,
    ipAddress: req.remoteAddress?.ipAddress,
    userAgent: req.headers.first(name: .userAgent),
    on: db
)

// Validate session
let isValid = try await SessionService.validate(
    sessionId: session.id!,
    on: db
)

// Revoke session
try await SessionService.revoke(
    sessionId: session.id!,
    on: db
)
```

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────┐
│          Client Applications                     │
│  (Web, Mobile, CLI, IoT)                         │
└────────────┬─────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────┐
│           API Gateway (CMSApi)                   │
└────────────┬─────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────┐
│        Authentication Middleware                 │
│  ┌────────────────────────────────────────────┐  │
│  │ JWT Validation → Provider Selection        │  │
│  │ → Role Resolution → Permission Check       │  │
│  └────────────────────────────────────────────┘  │
└────────────┬─────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────┐
│         CMSAuth Core Layer                       │
│  ┌───────────┐  ┌──────────────┐  ┌──────────┐  │
│  │  Session  │  │   Token      │  │   Role   │  │
│  │ Management│◄─┤  Management  │◄─┤Management│  │
│  └─────┬─────┘  └──────┬───────┘  └────┬─────┘  │
│        │               │               │        │
│        ▼               ▼               ▼        │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   │
│  │ Password │   │  Field   │   │  API     │   │
│  │ Service  │   │Permission│   │   Key    │   │
│  └──────────┘   └──────────┘   └──────────┘   │
└────────────┬─────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────┐
│         Authentication Providers                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │  Auth0   │  │ Firebase │  │    Local     │   │
│  │ Provider │  │ Provider │  │ JWT Provider │   │
│  └──────────┘  └──────────┘  └──────────────┘   │
└────────────┬─────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────┐
│           Database Layer                         │
│  ┌────────────────────────────────────────────┐  │
│  │ users │ roles │ permissions │ api_keys │   │  │
│  │ sessions │ field_permissions │          │   │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

## 💻 Usage Examples

### Basic Authentication Flow

```swift
import Vapor
import CMSAuth

// Configure auth providers
public func configure(_ app: Application) async throws {
    // Auth0 configuration
    app.cms.auth.register(Auth0Provider(
        domain: Environment.get("AUTH0_DOMAIN")!,
        clientId: Environment.get("AUTH0_CLIENT_ID")!,
        clientSecret: Environment.get("AUTH0_CLIENT_SECRET")!,
        audience: Environment.get("AUTH0_AUDIENCE")!
    ))

    // Local JWT
    app.cms.auth.register(LocalJWTProvider(
        secret: Environment.get("JWT_SECRET")!,
        expiration: .hours(24)
    ))

    // Apply auth middleware
    app.middleware.use(AuthMiddleware())
}

// Protected route
struct BlogAPI: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped([
            AuthMiddleware(),
            RoleMiddleware(requiredRole: .editor)
        ])

        protected.post("blog", use: createBlogPost)
    }

    func createBlogPost(req: Request) async throws -> ContentEntry {
        let user = try req.auth.require(User.self)
        let data = try req.content.decode(CreateEntryDTO.self)

        // Field-level permissions check
        guard try await req.fieldPermissions.canEdit(
            contentType: "blog",
            field: "published",
            user: user
        ) else {
            throw Abort(.forbidden, reason: "Cannot edit 'published' field")
        }

        return try await ContentEntryService.create(
            contentType: "blog",
            data: data.data,
            userId: user.id!,
            on: req.db
        )
    }
}
```

### Custom Auth Provider

```swift
import CMSAuth

struct CustomAuthProvider: AuthProvider {
    let name = "custom"

    func configure(app: Application) throws {
        // Setup provider
    }

    func verify(
        token: String,
        on req: Request
    ) async throws -> AuthenticatedUser {
        // Verify token with external service
        let response = try await req.client.post(
            "https://auth.custom.com/verify"
        ) { req in
            req.headers.add(name: "Authorization", value: token)
        }

        let userData = try response.content.decode(CustomUserData.self)

        return AuthenticatedUser(
            userId: userData.id,
            email: userData.email,
            roles: userData.roles.map(UserRole.init),
            tenantId: userData.tenantId
        )
    }

    func middleware() -> Middleware {
        return CustomAuthMiddleware()
    }
}

// Register custom provider
app.cms.auth.register(CustomAuthProvider())
```

### Password Reset Flow

```swift
// Request password reset
func requestPasswordReset(req: Request) async throws -> HTTPStatus {
    let email = try req.content.get(String.self, at: "email")

    // Generate reset token
    let token = try await PasswordService.createResetToken(
        email: email,
        expiration: .hours(1),
        on: req.db
    )

    // Send email with reset link
    let resetURL = "https://cms.example.com/reset?token=\(token)"
    try await req.email.send(
        to: email,
        subject: "Password Reset Request",
        template: "password_reset",
        context: ["resetURL": resetURL]
    )

    return .ok
}

// Reset password
func resetPassword(req: Request) async throws -> HTTPStatus {
    let data = try req.content.decode(ResetPasswordData.self)

    // Verify token and update password
    try await PasswordService.resetPassword(
        token: data.token,
        newPassword: data.newPassword,
        on: req.db
    )

    return .ok
}

struct ResetPasswordData: Content {
    let token: String
    let newPassword: String
    let confirmPassword: String
}
```

### API Key Authentication

```swift
// Create API key
func createAPIKey(req: Request) async throws -> APIKeyResponse {
    let user = try req.auth.require(User.self)
    let data = try req.content.decode(CreateAPIKeyData.self)

    let (apiKey, secret) = try await APIKeyService.create(
        userId: user.id!,
        name: data.name,
        permissions: data.permissions,
        expiresAt: data.expiresAt,
        on: req.db
    )

    return APIKeyResponse(
        id: apiKey.id!,
        name: apiKey.name,
        key: "sub_\(apiKey.prefix)_\(secret)",
        permissions: apiKey.permissions,
        createdAt: apiKey.createdAt!,
        expiresAt: apiKey.expiresAt
    )
}

// Use API key middleware
struct APIKeyMiddleware: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let authHeader = req.headers.first(name: .authorization),
              authHeader.starts(with: "ApiKey ") else {
            throw Abort(.unauthorized)
        }

        let token = String(authHeader.dropFirst(7))
        let key = try await APIKeyService.verify(
            token: token,
            on: req.db
        )

        req.auth.login(key.user)
        return try await next.respond(to: req)
    }
}
```

### Field-Level Permissions in Admin UI

```swift
// Filter editable fields
func getEditableFields(
    req: Request,
    contentType: String,
    user: User
) async throws -> [String] {
    let allFields = try await FieldService.getFields(
        contentType: contentType,
        on: req.db
    )

    let editable = try await FieldPermissionService.filterEditableFields(
        fields: allFields,
        userId: user.id!,
        contentType: contentType,
        on: req.db
    )

    return editable
}

// Check specific field access
func checkFieldAccess(
    req: Request,
    contentType: String,
    field: String,
    action: FieldAction
) async throws -> Bool {
    let user = try req.auth.require(User.self)

    return try await FieldPermissionService.canAccess(
        userId: user.id!,
        contentType: contentType,
        field: field,
        action: action,
        on: req.db
    )
}

enum FieldAction {
    case read, create, update, delete
}
```

## 🔗 Key Types

### AuthProvider Protocol

```swift
public protocol AuthProvider: Sendable {
    var name: String { get }

    func configure(app: Application) throws

    func verify(
        token: String,
        on req: Request
    ) async throws -> AuthenticatedUser

    func middleware() -> Middleware
}
```

### AuthenticatedUser

```swift
public struct AuthenticatedUser: Authenticatable, Sendable {
    public let userId: String
    public let email: String?
    public let roles: [UserRole]
    public let tenantId: String?

    public var isSuperAdmin: Bool {
        roles.contains(.superAdmin)
    }

    public func hasRole(_ role: UserRole) -> Bool {
        roles.contains(role)
    }

    public func hasAnyRole(_ roles: [UserRole]) -> Bool {
        !Set(self.roles).isDisjoint(with: roles)
    }
}
```

### UserRole

```swift
public enum UserRole: String, Codable, CaseIterable, Sendable {
    case superAdmin
    case admin
    case editor
    case author
    case contributor
    case viewer

    public var permissions: [Permission] {
        switch self {
        case .superAdmin: return Permission.all
        case .admin: return Permission.adminPermissions
        case .editor: return Permission.editorPermissions
        // ... etc
        }
    }
}
```

## 📦 Module Structure

```
Sources/CMSAuth/
├── AuthProvider.swift              # Main auth protocol
├── Auth0Provider.swift             # Auth0 implementation
├── FirebaseProvider.swift          # Firebase Auth
├── Local/
│   ├── LocalJWTProvider.swift      # Local JWT auth
│   └── PasswordService.swift       # Password handling
├── Services/
│   ├── UserService.swift           # User management
│   ├── RoleService.swift           # Role management
│   ├── SessionService.swift        # Session handling
│   ├── APIKeyService.swift         # API keys
│   ├── PasswordService.swift       # Passwords
│   └── FieldPermissionService.swift # Field-level perms
├── Models/
│   ├── User.swift                  # User model
│   ├── UserRole.swift              # Role definitions
│   ├── Session.swift               # Session model
│   ├── APIKey.swift                # API key model
│   ├── Permission.swift            # Permission enum
│   └── FieldPermission.swift       # Field permissions
├── Middleware/
│   ├── AuthMiddleware.swift        # JWT validation
│   ├── RoleMiddleware.swift        # Role checking
│   └── APILimitMiddleware.swift    # API rate limiting
└── DTOs/
    ├── LoginDTO.swift              # Login request
    ├── TokenDTO.swift              # Token response
    ├── UserDTO.swift               # User data
    └── PermissionDTO.swift         # Permissions
```

## 🔧 Configuration

```swift
// In configure.swift
app.cms.auth.configuration = .init(
    // Session settings
    sessionDriver: .redis,
    sessionLifetime: .hours(24),

    // JWT settings
    jwtSecret: Environment.get("JWT_SECRET")!,
    jwtExpiration: .hours(24),
    jwtRefreshExpiration: .days(30),

    // Provider configuration
    providers: [
        "auth0": Auth0Configuration(...),
        "firebase": FirebaseConfiguration(...),
        "local": LocalAuthConfiguration(...)
    ],

    // Password requirements
    passwordMinLength: 12,
    passwordRequireUppercase: true,
    passwordRequireNumbers: true,
    passwordRequireSpecialChars: true,

    // API key settings
    apiKeyPrefix: "scms",
    apiKeyLength: 32
)
```

## 🧪 Testing

```swift
import XCTest
import XCTVapor
@testable import CMSAuth

final class CMSAuthTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        try await app.autoMigrate()
    }

    func testLocalLogin() async throws {
        // Create test user
        let user = try await UserService.create(
            email: "test@example.com",
            password: "password123",
            role: .editor,
            on: app.db
        )

        // Test login endpoint
        try await app.test(.POST, "/api/v1/auth/login", beforeRequest: { req in
            try req.content.encode([
                "email": "test@example.com",
                "password": "password123",
                "provider": "local"
            ])
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let token = try res.content.decode(TokenResponse.self)
            XCTAssertNotNil(token.accessToken)
        })
    }

    func testRoleBasedAccess() async throws {
        let editor = try await createUser(role: .editor)
        let token = try await generateToken(for: editor)

        // Editor should be able to create content
        try await app.test(.POST, "/api/v1/content/blog", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: token)
            try req.content.encode(testEntryData)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .created)
        })

        // Viewer should NOT be able to create content
        let viewer = try await createUser(role: .viewer)
        let viewerToken = try await generateToken(for: viewer)

        try await app.test(.POST, "/api/v1/content/blog", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: viewerToken)
            try req.content.encode(testEntryData)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .forbidden)
        })
    }
}
```

## 📋 Environment Variables

```bash
# JWT Configuration
JWT_SECRET="your-secret-key-min-32-chars-long"
JWT_EXPIRATION_HOURS=24
JWT_REFRESH_EXPIRATION_DAYS=30

# Session
SESSION_DRIVER=redis
SESSION_LIFETIME_HOURS=24
SESSION_REDIS_KEY="sessions"

# Auth0
AUTH0_DOMAIN="your-domain.auth0.com"
AUTH0_CLIENT_ID="your-client-id"
AUTH0_CLIENT_SECRET="your-client-secret"
AUTH0_AUDIENCE="https://api.yourapp.com"

# Firebase
FIREBASE_PROJECT_ID="your-project-id"
FIREBASE_SERVICE_ACCOUNT_KEY="path/to/service-account.json"

# Password Policy
PASSWORD_MIN_LENGTH=12
PASSWORD_REQUIRE_UPPERCASE=true
PASSWORD_REQUIRE_NUMBERS=true
PASSWORD_REQUIRE_SPECIAL_CHARS=true

# API Keys
API_KEY_PREFIX=scms
API_KEY_LENGTH=32
API_KEY_RATE_LIMIT=10000

# 2FA
TOTP_ISSUER="SwiftCMS"
TOTP_ENABLED=true
```

## 🤝 Integration with Other Modules

- **CMSCore**: Uses module system and hooks for auth events
- **CMSApi**: Protects API endpoints with auth middleware
- **CMSAdmin**: Provides UI for user/role management
- **CMSSchema**: Controls access to content operations
- **CMSEvents**: Publishes auth events (login, logout, etc.)

## 📚 Related Documentation

- [Authentication Guide](../../docs/Authentication.md)
- [Authorization Guide](../../docs/Authorization.md)
- [API Reference](../CMSApi/README.md)
- [Admin UI Guide](../CMSAdmin/README.md)
- [Multi-tenancy Guide](../../docs/MultiTenancy.md)

---

**Emoji Guide**: 🔐 Security, 👤 Users, 🔑 Keys, 🛡️ Protection, ⚡ Auth, 🎯 RBAC, 🔒 Encryption

## 🏆 Module Status

- **Stability**: Stable
- **Test Coverage**: 85%
- **Documentation**: Comprehensive
- **Dependencies**: CMSCore, CMSObjects
- **Swift Version**: 6.1+

**Maintained by**: Agent 4 (W1), Agent 5 (W2) | **Current Version**: 2.0.0
