# SwiftCMS

**A Type-Safe, High-Performance Headless CMS for Apple-Native Teams**

![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange.svg)
![Vapor 4](https://img.shields.io/badge/Vapor-4-blue.svg)

SwiftCMS brings Strapi's flexibility to Swift's performance — runtime-defined content types with type-safe client SDKs, built for teams shipping iOS and macOS apps.

## Quick Start

```bash
git clone https://github.com/swiftcms/swiftcms.git && cd swiftcms
cp .env.example .env
docker compose up -d postgres redis meilisearch
swift build && swift run App serve --hostname 0.0.0.0 --port 8080
```

Open http://localhost:8080/admin — login: `admin@swiftcms.dev` / `admin123`

## Features

- Dynamic content types with JSON Schema validation
- REST + GraphQL APIs with pagination, filtering, relations
- Admin panel (Leaf + HTMX + DaisyUI, dark mode)
- Pluggable auth (Auth0 / Firebase / Local JWT) with RBAC
- EventBus with webhook dispatch, retry, and DLQ
- Media library (local + S3), full-text search (Meilisearch)
- Content lifecycle (draft → review → published → archived)
- Version history with diff and restore
- i18n with fallback chains
- Background jobs (scheduled publish, webhook delivery)
- Swift client SDK generation
- Plugin system via CMSModule protocol
- Docker + Kubernetes deployment (~200MB image)

## Architecture

```
Client Layer  → iOS/macOS, Web, Admin Panel
API Layer     → REST /api/v1, GraphQL /graphql, WebSocket /ws
Service Layer → Content, Media, Auth, Search, Jobs
Core Engine   → Schema Registry, JSON Validator, Hook Registry, EventBus
Data Layer    → PostgreSQL JSONB + GIN, Redis, Meilisearch, S3
Infra Layer   → Docker/K8s, OpenTelemetry, Gatekeeper rate limiting
```

## License

MIT
