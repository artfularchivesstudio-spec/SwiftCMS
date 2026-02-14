// swift-tools-version:6.0
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
        .library(name: "CMSOpenAPI", targets: ["CMSOpenAPI"]),
        .executable(name: "cms", targets: ["CMSCLI"]),
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
        // GraphQL (Graphiti + Pioneer) — Wave 3
        .package(url: "https://github.com/GraphQLSwift/Graphiti.git", from: "1.15.1"),
        .package(url: "https://github.com/d-exclaimation/pioneer", from: "1.0.0"),
        // Snapshot Testing
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
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
                "CMSOpenAPI",
            ]
        ),

        // ─── CMSCLI (Management CLI) ────────────────────────────────
        .executableTarget(
            name: "CMSCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                "CMSCore",
                "CMSSchema",
                "CMSObjects",
            ]
        ),

        // ─── CMSObjects (Shared DTOs) ───────────────────────────────
        .target(
            name: "CMSObjects",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ]
        ),

        // ─── CMSCore (Module System) ────────────────────────────────
        .target(
            name: "CMSCore",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                "CMSObjects",
            ],
            exclude: ["Observability/README.md"]
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
                "CMSCore",
                "CMSObjects",
                "CMSEvents",
            ]
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
            ]
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
            ]
        ),

        // ─── CMSSearch ──────────────────────────────────────────────
        .target(
            name: "CMSSearch",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                "CMSCore",
                "CMSSchema",
                "CMSObjects",
                "CMSEvents",
            ]
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
                "CMSMedia",
            ]
        ),

        // ─── CMSApi (REST + GraphQL) ────────────────────────────────
        .target(
            name: "CMSApi",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "Graphiti", package: "Graphiti"),
                .product(name: "Pioneer", package: "pioneer"),
                "CMSCore",
                "CMSSchema",
                "CMSObjects",
                "CMSAuth",
                "CMSEvents",
                "CMSMedia",
                "CMSSearch",
            ]
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
            ]
        ),

        // ─── CMSOpenAPI (OpenAPI + SDK Generation) ───────────────────
        .target(
            name: "CMSOpenAPI",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                "CMSCore",
                "CMSSchema",
                "CMSObjects",
            ]
        ),

        // ─── Tests ──────────────────────────────────────────────────
        .testTarget(
            name: "AppTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                "App",
            ]
        ),
        .testTarget(
            name: "CMSObjectsTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                "CMSObjects",
            ]
        ),
        .testTarget(
            name: "CMSCoreTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                "CMSCore",
            ]
        ),
        .testTarget(
            name: "CMSEventsTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                "CMSEvents",
            ]
        ),
        .testTarget(
            name: "CMSSchemaTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                "CMSSchema",
            ]
        ),
        .testTarget(
            name: "CMSAuthTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                "CMSAuth",
            ]
        ),
        .testTarget(
            name: "CMSApiTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                "CMSApi",
                "CMSSchema",
                "CMSObjects",
                "CMSAuth",
            ],
            exclude: ["GraphQLTests.md"]
        ),
        .testTarget(
            name: "CMSAdminTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "Leaf", package: "leaf"),
                "CMSAdmin",
                "CMSSchema",
                "CMSObjects",
            ]
        ),
    ]
)
