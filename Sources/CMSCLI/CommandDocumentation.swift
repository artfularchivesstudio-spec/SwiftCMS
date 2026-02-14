// MARK: - Root Command

/// 🖥️ **`cms` - SwiftCMS Command-Line Interface**
///
/// The main entry point for the SwiftCMS CLI tool providing server management,
/// database operations, SDK generation, and content migration capabilities.
///
/// ## Overview
/// The CMS CLI is a comprehensive command-line tool built with `swift-argument-parser`
/// that enables developers to:
/// - Start and manage SwiftCMS servers
/// - Run database migrations and seeding
/// - Generate type-safe client SDKs (Swift & TypeScript)
/// - Import content from Strapi projects
/// - Export content as static bundles
///
/// ## Usage
/// ```bash
/// cms <command> [options] [arguments]
/// cms --help
/// cms <command> --help
/// ```
///
/// ## Available Commands
/// - `serve` - Start the HTTP server
/// - `migrate` - Run database migrations
/// - `seed` - Seed database with defaults
/// - `generate-sdk` - Generate client SDKs
/// - `import-strapi` - Import from Strapi
/// - `export` - Export content bundles
///
/// ## Examples
/// ```bash
/// # Start server with defaults
/// cms serve
///
/// # Generate TypeScript SDK
/// cms generate-sdk typescript --output ./src/cms
///
/// # Import Strapi project
/// cms import-strapi --path ./strapi-project --dry-run
///
/// # Run migrations in production
/// DATABASE_URL=postgres://... cms migrate --yes
/// ```
///
/// ## Environment Variables
/// - `DATABASE_URL` - PostgreSQL connection string
/// - `JWT_SECRET` - JWT signing secret
/// - `LOG_LEVEL` - Logging verbosity (trace, debug, info, warning, error)
///
/// ## Thread Safety
/// The CLI is built with async/await and is thread-safe. Each command runs
/// in isolated execution context.
