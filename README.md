# SwiftCMS

**A Type-Safe, High-Performance Headless CMS for Apple-Native Teams**

![Swift 6.1+](https://img.shields.io/badge/Swift-6.1%2B-orange.svg)
![Vapor 4](https://img.shields.io/badge/Vapor-4-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)

SwiftCMS brings Strapi's flexibility to Swift's performance — runtime-defined content types with type-safe client SDKs, built for teams shipping iOS and macOS apps.

## 🚀 Quick Start

Get SwiftCMS running locally in under 5 minutes:

```bash
git clone https://github.com/artfularchivesstudio-spec/SwiftCMS.git && cd Swift-CMS
cp .env.example .env
make setup    # Starts PostgreSQL, Redis, Meilisearch
swift run App serve --hostname 0.0.0.0 --port 8080
```

Access the admin panel: http://localhost:8080/admin
- Email: `admin@swiftcms.dev`
- Password: `admin123`

API available:
- REST: http://localhost:8080/api/v1
- GraphQL: http://localhost:8080/graphql (if enabled)
- WebSocket: ws://localhost:8080/ws

## ✨ Features

### Core CMS Features
- **Dynamic Content Types** - Runtime-defined with JSON Schema validation
- **Content Lifecycle** - Draft → Review → Published → Archived workflow
- **Version History** - Track changes with diff and restore capabilities
- **i18n & Localization** - Multi-language support with fallback chains
- **Media Management** - Upload and manage images, videos, documents
- **Full-Text Search** - Powered by Meilisearch with typo tolerance
- **Role-Based Access Control** - Granular permissions for users & roles
- **API Keys** - Machine-to-machine authentication

### Developer Experience
- **Type-Safe Swift SDK** - Auto-generated client libraries
- **Plugin System** - Extend functionality with custom modules
- **Event System** - Webhooks, EventBus, and real-time notifications
- **GraphQL API** - Flexible queries and mutations
- **WebSocket Support** - Real-time updates and collaborative editing
- **CLI Tools** - Migration, seeding, and SDK generation

### Production Ready
- **Pluggable Authentication** - Auth0, Firebase, or Local JWT
- **Scalable Storage** - Local filesystem or AWS S3
- **Background Jobs** - Scheduled posts, webhook retries, import/export
- **Docker + Kubernetes** - Production-ready container deployment
- **OpenTelemetry** - Observability and monitoring support
- **Rate Limiting** - Built-in protection against abuse

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   iOS/macOS     │    │   Web Frontend   │    │   Admin Panel   │
│   (SwiftUI)     │    │   (React/Vue)    │    │   (Leaf/HTMX)   │
└─────────┬───────┘    └──────────┬───────┘    └─────────┬───────┘
          │                       │                      │
          └───────────────────────┴──────────────────────┘
                                  │
          ┌───────────────────────┼──────────────────────┐
          │                       │                      │
┌─────────▼───────┐    ┌──────────▼───────┐    ┌────────▼────────┐
│   REST API      │    │   GraphQL API    │    │ WebSocket API   │
│  /api/v1        │    │   /graphql       │    │     /ws         │
└─────────┬───────┘    └──────────┬───────┘    └────────┬────────┘
          │                       │                     │
          └───────────────────────┴─────────────────────┘
                                  │
          ┌───────────────────────┼──────────────────────┐
          │                       │                      │
┌─────────▼───────┐    ┌──────────▼───────┐    ┌────────▼────────┐
│   Content       │    │   Auth           │    │   Search        │
│   Media         │    │   Users/Roles    │    │   Jobs          │
│   Schema        │    │   Permissions    │    │   Events        │
└─────────┬───────┘    └──────────┬───────┘    └────────┬────────┘
          │                       │                     │
          └───────────────────────┴─────────────────────┘
                                  │
          ┌───────────────────────┼──────────────────────┐
          │                       │                      │
┌─────────▼───────┐    ┌──────────▼───────┐    ┌────────▼────────┐
│  PostgreSQL     │    │     Redis        │    │   Meilisearch   │
│  (JSONB)        │    │   (Cache/Jobs)   │    │   (Search)      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📚 Documentation

- [Installation Guide](./docs/installation.md) - Get started quickly
- [Configuration Guide](./docs/configuration.md) - Environment variables, auth setup, and more
- [Plugin Development](./docs/plugin-development.md) - Create custom extensions
- [API Documentation](./docs/api/) - REST, GraphQL, and WebSocket APIs
- [Examples](./examples/) - Blog and e-commerce starters

## 🎯 Use Cases

### Perfect For:
- **iOS/macOS Apps** - Native Swift client SDK generation
- **Multi-platform Content** - Single CMS for web, mobile, and desktop
- **Agile Teams** - Iterate on content structure without code changes
- **Agencies** - Build client sites with dynamic content requirements
- **Startups** - Scale from prototype to production with the same stack

### Real-World Examples:
- Mobile news apps with editorial workflow
- E-commerce product catalogs with search
- Marketing websites with flexible landing pages
- SaaS documentation with version control
- Multi-tenant CMS platforms

## 🛠️ Technology Stack

| Layer | Technology |
|------|------------|
| **Language** | Swift 6.1+ |
| **Web Framework** | Vapor 4.x |
| **Database** | PostgreSQL 16+ with JSONB |
| **ORM** | Fluent 4.x |
| **Cache/Queue** | Redis 7+ |
| **Search** | Meilisearch |
| **Auth** | Auth0, Firebase, Local JWT |
| **Storage** | Local filesystem or AWS S3 |
| **Template Engine** | Leaf |
| **Admin UI** | HTMX + Alpine.js + DaisyUI |
| **iOS SDK** | Auto-generated Swift Package |
| **Container** | Docker + Kubernetes |
| **Observability** | OpenTelemetry |

## 📱 Client SDK Generation

SwiftCMS automatically generates type-safe client SDKs for your content types:

```bash
# Generate iOS/macOS SDK
swift run cms generate-sdk swift \
  --output ./ClientSDK \
  --package-name MyAppAPI

# Use in your app
import MyAppAPI

let client = SwiftCMSClient(baseURL: "https://api.yourapp.com")
let posts = try await client.getContent(contentType: "posts")
```

## 🚀 Deployment

### Docker (Recommended)

```bash
docker build -t swiftcms .
docker compose up -d
```

### Kubernetes

```bash
kubectl apply -f k8s/
```

See [Deployment Guide](./docs/deployment.md) for production setup.

## 🧪 Testing

```bash
# Run all tests
swift test

# Run specific module tests
swift test --filter CMSCoreTests

# Run with coverage
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/AppPackageTests.xctest/Contents/MacOS/AppPackageTests -instr-profile .build/debug/codecov/default.profdata
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for:
- Development setup
- Code style guidelines
- Pull request process
- Testing requirements

## 📖 Examples

- **[Blog Starter](./examples/blog-swiftui/)** - SwiftUI iOS blog app
- **[E-commerce Catalog](./examples/ecommerce/)** - Product catalog with search

Each example includes:
- Complete setup instructions
- Content type definitions
- Sample data
- Deployment guides

## 📄 License

MIT License - see [LICENSE](./LICENSE) file for details.

## 🆘 Support

- **Documentation**: [docs/](./docs/)
- **Issues**: [GitHub Issues](https://github.com/artfularchivesstudio-spec/SwiftCMS/issues)
- **Discussions**: [GitHub Discussions](https://github.com/artfularchivesstudio-spec/SwiftCMS/discussions)

---

**Built with ❤️ for the Swift Community**
