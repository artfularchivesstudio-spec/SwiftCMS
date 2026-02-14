// swift-tools-version:5.10
// SwiftCMS - A Type-Safe, High-Performance Headless CMS for Apple-Native Teams

import PackageDescription

let package = Package(
    name: "SwiftCMS",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "App", targets: ["App"]),
        .library(name: "CMSObjects", targets: ["CMSObjects"]),
        .library(name: "CMSCore", targets: ["CMSCore"]),
        .library(name: "CMSSchema", targets: ["CMSSchema"]),
        .library(name: "CMSAuth", targets: ["CMSAuth"]),
        .library(name: "CMSMedia", targets: ["CMSMedia"]),
        .library(name: "CMSEvents", targets: ["CMSEvents"]),
        .library(name: "CMSSearch", targets: ["CMSSearch"]),
        .library(name: "CMSJobs", targets: ["CMSJobs"]),
        .library(name: "CMSApi", targets: ["CMSApi"]),
        .library(name: "CMSAdmin", targets: ["CMSAdmin"]),
    ],
    dependencies: [
        // Vapor & Fluent
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.6.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.3.0"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.10.0"),
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.1.1"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0"),
        // CLI
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        // JSON Schema Validation
        .package(url: "https://github.com/kylef/JSONSchema.swift.git", from: "0.6.0"),
        // AWS S3 via Soto
        .package(url: "https://github.com/soto-project/soto.git", from: "7.0.0"),
    ],
    targets: [
        // ─── Application ─────────────────────────────────────────────
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Redis", package: "redis"),
                .product(name: "QueuesRedisDriver", package: "queues-redis-driver"),
                "CMSCore",
                "CMSSchema",
                "CMSApi",
                "CMSAdmin",
                "CMSAuth",
                "CMSMedia",
                "CMSSearch",
                "CMSEvents",
                "CMSJobs",
                "CMSObjects",
            ],
            path: "Sources/App"
        ),

        // ─── CMSObjects (Shared DTOs) ───────────────────────────────
        .target(
            name: "CMSObjects",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources/CMSObjects"
        ),

        // ─── CMSCore (Module System) ────────────────────────────────
        .target(
            name: "CMSCore",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                "CMSObjects",
            ],
            path: "Sources/CMSCore"
        ),

        // ─── CMSEvents (EventBus) ───────────────────────────────────
        .target(
            name: "CMSEvents",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "Redis", package: "redis"),
                "CMSCore",
                "CMSObjects",
            ],
            path: "Sources/CMSEvents"
        ),

        // ─── CMSSchema (Models, Migrations, Engine) ─────────────────
        .target(
            name: "CMSSchema",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "JSONSchema", package: "JSONSchema.swift"),
                .product(name: "QueuesRedisDriver", package: "queues-redis-driver"),
                "CMSCore",
                "CMSObjects",
                "CMSEvents",
            ],
            path: "Sources/CMSSchema"
        ),

        // ─── CMSAuth ────────────────────────────────────────────────
        .target(
            name: "CMSAuth",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "JWTKit", package: "jwt-kit"),
                "CMSCore",
                "CMSSchema",
                "CMSObjects",
            ],
            path: "Sources/CMSAuth"
        ),

        // ─── CMSMedia ───────────────────────────────────────────────
        .target(
            name: "CMSMedia",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "SotoS3", package: "soto"),
                "CMSCore",
                "CMSSchema",
                "CMSObjects",
                "CMSEvents",
                "CMSAuth",
            ],
            path: "Sources/CMSMedia"
        ),

        // ─── CMSSearch ──────────────────────────────────────────────
        .target(
            name: "CMSSearch",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                "CMSCore",
                "CMSSchema",
                "CMSObjects",
                "CMSEvents",
            ],
            path: "Sources/CMSSearch"
        ),

        // ─── CMSJobs ────────────────────────────────────────────────
        .target(
            name: "CMSJobs",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "QueuesRedisDriver", package: "queues-redis-driver"),
                "CMSCore",
                "CMSSchema",
                "CMSObjects",
                "CMSEvents",
            ],
            path: "Sources/CMSJobs"
        ),

        // ─── CMSApi (REST + GraphQL) ────────────────────────────────
        .target(
            name: "CMSApi",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                "CMSCore",
                "CMSSchema",
                "CMSObjects",
                "CMSAuth",
                "CMSEvents",
                "CMSMedia",
                "CMSSearch",
            ],
            path: "Sources/CMSApi"
        ),

        // ─── CMSAdmin ───────────────────────────────────────────────
        .target(
            name: "CMSAdmin",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "Leaf", package: "leaf"),
                "CMSCore",
                "CMSSchema",
                "CMSObjects",
                "CMSAuth",
                "CMSEvents",
                "CMSMedia",
            ],
            path: "Sources/CMSAdmin"
        ),

        // ─── Tests ──────────────────────────────────────────────────
        .testTarget(
            name: "AppTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                "App",
            ],
            path: "Tests/AppTests"
        ),
        .testTarget(
            name: "CMSObjectsTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                "CMSObjects",
            ],
            path: "Tests/CMSObjectsTests"
        ),
        .testTarget(
            name: "CMSCoreTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                "CMSCore",
            ],
            path: "Tests/CMSCoreTests"
        ),
        .testTarget(
            name: "CMSEventsTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                "CMSEvents",
            ],
            path: "Tests/CMSEventsTests"
        ),
        .testTarget(
            name: "CMSSchemaTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                "CMSSchema",
            ],
            path: "Tests/CMSSchemaTests"
        ),
        .testTarget(
            name: "CMSAuthTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                "CMSAuth",
            ],
            path: "Tests/CMSAuthTests"
        ),
    ]
)
