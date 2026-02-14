import Vapor
import Fluent
import CMSObjects

/// Handles locale-aware content retrieval with fallback chains.
public struct LocaleService: Sendable {

    /// Default fallback chains for common locales.
    public static let defaultFallbacks: [String: [String]] = [
        "en-GB": ["en-US", "en"],
        "en-AU": ["en-GB", "en-US", "en"],
        "fr-CA": ["fr-FR", "fr"],
        "pt-BR": ["pt-PT", "pt"],
        "es-MX": ["es-ES", "es"],
        "zh-TW": ["zh-CN", "zh"]
    ]

    /// Get a content entry with locale fallback.
    public static func getWithFallback(
        contentType: String,
        id: UUID,
        locale: String,
        on db: Database,
        fallbackChain: [String]? = nil
    ) async throws -> ContentEntry? {
        // Try exact locale first
        if let entry = try await ContentEntry.query(on: db)
            .filter(\.$contentType == contentType)
            .filter(\.$id == id)
            .filter(\.$locale == locale)
            .filter(\.$deletedAt == nil)
            .first() {
            return entry
        }

        // Try fallback chain
        let chain = fallbackChain ?? defaultFallbacks[locale] ?? []
        for fallbackLocale in chain {
            if let entry = try await ContentEntry.query(on: db)
                .filter(\.$contentType == contentType)
                .filter(\.$id == id)
                .filter(\.$locale == fallbackLocale)
                .filter(\.$deletedAt == nil)
                .first() {
                return entry
            }
        }

        // Final fallback: try without locale filter
        return try await ContentEntry.query(on: db)
            .filter(\.$contentType == contentType)
            .filter(\.$id == id)
            .filter(\.$deletedAt == nil)
            .first()
    }
}
