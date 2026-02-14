import Vapor

// MARK: - Application Entry Point

/// 🚀 **SwiftCMS Application Entry Point**
///
/// The main entry point for the SwiftCMS headless content management system.
/// This struct implements the `@main` attribute, making it the application's starting point.
///
/// ## Application Lifecycle
/// 1. 🏗️ **Environment Detection**: Automatically detects the current environment (development, production, testing)
/// 2. 📝 **Logging Bootstrap**: Initializes the logging system with environment-specific configuration
/// 3. 📦 **Application Creation**: Builds the Vapor application instance
/// 4. ⚙️ **Configuration**: Calls the comprehensive `configure(_:)` function to set up all subsystems
/// 5. 🚀 **Execution**: Starts the application server and begins handling requests
/// 6. 🧹 **Graceful Shutdown**: Ensures clean shutdown when the application terminates
///
/// ## Environment Variables
/// - `DATABASE_URL`: PostgreSQL connection string for production databases
/// - `REDIS_URL`: Redis connection string for caching, sessions, and queues
/// - `MULTI_TENANT`: Enable/disable multi-tenant mode (true/false)
/// - `ALLOWED_ORIGINS`: Comma-separated list of allowed CORS origins
///
/// Example usage:
/// ```bash
/// # Development mode (default)
/// swift run App
///
/// # Production mode
/// DATABASE_URL="postgres://user:pass@localhost/db" \
/// REDIS_URL="redis://localhost" \
/// swift run App --env production
/// ```
@main
struct SwiftCMSApp {

    /// 🚀 Launches the SwiftCMS application.
    ///
    /// This method orchestrates the entire application bootstrap process:
    /// - Detects the runtime environment
    /// - Initializes logging with appropriate verbosity
    /// - Creates the Vapor application instance
    /// - Configures all subsystems (database, cache, auth, etc.)
    /// - Starts the HTTP server to handle incoming requests
    ///
    /// - Note: Uses Swift 6.0+ structured concurrency with async/await
    /// - Important: Automatically handles graceful shutdown on termination
    static func main() async throws {
        // 🏗️ Detect runtime environment (development/production/testing)
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        // 📦 Create application instance
        let app = try await Application.make(env)
        defer { Task { try await app.asyncShutdown() } }

        app.logger.info("🚀 SwiftCMS starting up...")
        app.logger.info("Environment: \(env.name)")
        app.logger.info("Working directory: \(app.directory.workingDirectory)")

        // ⚙️ Configure all subsystems
        app.logger.info("Configuring application subsystems...")
        try await configure(app)
        app.logger.info("✅ Configuration complete")

        // 🚀 Start the server
        app.logger.info("Starting HTTP server...")
        try await app.execute()
    }
}
