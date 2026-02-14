import Vapor
import CMSCore

/// Helper to register well-known plugins that are built as part of the app.
public struct PluginLoader {
    public static func registerPlugins(registry: PluginRegistry) {
        // Plugins will be registered here as they are implemented in Wave 4
        // e.g. registry.register("seo") { SEOModule() }
        // e.g. registry.register("analytics") { AnalyticsModule() }
    }
}
