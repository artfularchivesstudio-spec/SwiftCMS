import Vapor
import Fluent
import CMSObjects
import Queues

// MARK: - Content Preview

/// Provides draft content preview with short-lived tokens.
public struct ContentPreviewService: Sendable {

    /// Generate a preview token (1hr expiry) for a draft entry.
    public static func generatePreviewToken(
        entryId: UUID,
        contentType: String
    ) throws -> String {
        let payload: [String: String] = [
            "sub": "preview",
            "entry_id": entryId.uuidString,
            "content_type": contentType,
            "exp": "\(Date().addingTimeInterval(3600).timeIntervalSince1970)"
        ]
        let data = try JSONEncoder().encode(payload)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Validate a preview token and return the entry ID.
    public static func validatePreviewToken(_ token: String) -> (entryId: UUID, contentType: String)? {
        var base64 = token
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONDecoder().decode([String: String].self, from: data),
              let entryIdStr = payload["entry_id"],
              let entryId = UUID(uuidString: entryIdStr),
              let contentType = payload["content_type"],
              let expStr = payload["exp"],
              let exp = Double(expStr),
              Date(timeIntervalSince1970: exp) > Date()
        else {
            return nil
        }
        return (entryId, contentType)
    }
}

// MARK: - Preview Controller Extension

/// Add preview routes to the content API.
public struct PreviewController: RouteCollection {
    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let content = routes.grouped(":contentType")

        // Generate preview token (requires auth)
        content.post(":entryId", "preview-token", use: generateToken)

        // Access preview (token-based, no auth required)
        content.get(":entryId", "preview", use: preview)
    }

    /// POST /api/v1/:contentType/:entryId/preview-token
    @Sendable
    func generateToken(req: Request) async throws -> Response {
        let contentType = try req.parameters.require("contentType")
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid entry ID")
        }

        // Verify entry exists
        guard let _ = try await ContentEntry.query(on: req.db)
            .filter(\.$contentType == contentType)
            .filter(\.$id == entryId)
            .first()
        else {
            throw ApiError.notFound("Entry not found")
        }

        let token = try ContentPreviewService.generatePreviewToken(
            entryId: entryId, contentType: contentType
        )

        let res = Response(status: .ok)
        try res.content.encode(["token": token])
        return res
    }

    /// GET /api/v1/:contentType/:entryId/preview?token=...
    @Sendable
    func preview(req: Request) async throws -> ContentEntryResponseDTO {
        guard let token = req.query[String.self, at: "token"] else {
            throw ApiError.unauthorized("Preview token required")
        }

        guard let validated = ContentPreviewService.validatePreviewToken(token) else {
            throw ApiError.unauthorized("Invalid or expired preview token")
        }

        guard let entry = try await ContentEntry.find(validated.entryId, on: req.db) else {
            throw ApiError.notFound("Entry not found")
        }

        return entry.toResponseDTO()
    }
}

// MARK: - Version Pruning Job

/// Background job that prunes old content versions.
/// Runs daily. Respects max_versions (50) and max_age_days (365).
/// Always keeps version 1 and the current version.
public struct VersionPruningJob: AsyncScheduledJob, Sendable {
    let maxVersions: Int
    let maxAgeDays: Int

    public init(maxVersions: Int = 50, maxAgeDays: Int = 365) {
        self.maxVersions = maxVersions
        self.maxAgeDays = maxAgeDays
    }

    public func run(context: QueueContext) async throws {
        let db = context.application.db
        let cutoffDate = Calendar.current.date(
            byAdding: .day, value: -maxAgeDays, to: Date()
        ) ?? Date()

        // Get all unique entry IDs that have versions
        let allVersions = try await ContentVersion.query(on: db)
            .sort(\.$entry.$id)
            .sort(\.$version, .descending)
            .all()

        // Group by entry ID
        var grouped: [UUID: [ContentVersion]] = [:]
        for version in allVersions {
            let entryId = version.$entry.id
            grouped[entryId, default: []].append(version)
        }

        var pruned = 0

        for (_, versions) in grouped {
            guard versions.count > 2 else { continue } // Keep at least 2

            let sorted = versions.sorted { $0.version > $1.version }
            let currentVersion = sorted.first
            let firstVersion = sorted.last

            for version in sorted {
                // Never delete current or first version
                if version.id == currentVersion?.id || version.id == firstVersion?.id {
                    continue
                }

                // Prune if exceeds max count or max age
                let index = sorted.firstIndex(where: { $0.id == version.id }) ?? 0
                let exceedsCount = index >= maxVersions
                let exceedsAge = version.createdAt.map { $0 < cutoffDate } ?? false

                if exceedsCount || exceedsAge {
                    try await version.delete(on: db)
                    pruned += 1
                }
            }
        }

        if pruned > 0 {
            context.logger.info("Version pruning: removed \(pruned) old versions")
        }
    }
}
