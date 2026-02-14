import Vapor
import Fluent
import Queues
import CMSSchema

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
