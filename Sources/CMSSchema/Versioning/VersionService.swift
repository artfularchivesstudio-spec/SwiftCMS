import Vapor
import Fluent
import CMSObjects

/// Service for managing content entry versions.
public struct VersionService: Sendable {

    /// List all versions for a content entry.
    public static func listVersions(
        entryId: UUID,
        on db: Database
    ) async throws -> [ContentVersionResponseDTO] {
        let versions = try await ContentVersion.query(on: db)
            .filter(\.$entry.$id == entryId)
            .sort(\.$version, .descending)
            .all()
        return versions.map { $0.toResponseDTO() }
    }

    /// Get a specific version.
    public static func getVersion(
        entryId: UUID,
        version: Int,
        on db: Database
    ) async throws -> ContentVersionResponseDTO {
        guard let v = try await ContentVersion.query(on: db)
            .filter(\.$entry.$id == entryId)
            .filter(\.$version == version)
            .first()
        else {
            throw ApiError.notFound("Version \(version) not found")
        }
        return v.toResponseDTO()
    }

    /// Restore a content entry to a previous version.
    /// Creates a new version with the historical data.
    public static func restore(
        entryId: UUID,
        version: Int,
        on db: Database,
        userId: String? = nil
    ) async throws -> ContentEntryResponseDTO {
        guard let historicalVersion = try await ContentVersion.query(on: db)
            .filter(\.$entry.$id == entryId)
            .filter(\.$version == version)
            .first()
        else {
            throw ApiError.notFound("Version \(version) not found")
        }

        guard let entry = try await ContentEntry.find(entryId, on: db) else {
            throw ApiError.notFound("Entry not found")
        }

        // Set entry data to historical version
        entry.data = historicalVersion.data
        entry.updatedBy = userId
        try await entry.save(on: db)

        // Create new version record
        let currentMax = try await ContentVersion.query(on: db)
            .filter(\.$entry.$id == entryId)
            .sort(\.$version, .descending)
            .first()?.version ?? 0

        let newVersion = ContentVersion(
            entryID: entryId,
            version: currentMax + 1,
            data: historicalVersion.data,
            changedBy: userId
        )
        try await newVersion.save(on: db)

        return entry.toResponseDTO()
    }

    /// Compare two versions and return a diff.
    public static func diff(
        entryId: UUID,
        fromVersion: Int,
        toVersion: Int,
        on db: Database
    ) async throws -> AnyCodableValue {
        guard let from = try await ContentVersion.query(on: db)
            .filter(\.$entry.$id == entryId)
            .filter(\.$version == fromVersion)
            .first()
        else {
            throw ApiError.notFound("Version \(fromVersion) not found")
        }

        guard let to = try await ContentVersion.query(on: db)
            .filter(\.$entry.$id == entryId)
            .filter(\.$version == toVersion)
            .first()
        else {
            throw ApiError.notFound("Version \(toVersion) not found")
        }

        return computeDiff(from: from.data, to: to.data)
    }

    /// Compute field-level diff between two data objects.
    private static func computeDiff(
        from: AnyCodableValue,
        to: AnyCodableValue
    ) -> AnyCodableValue {
        guard let fromDict = from.dictionaryValue,
              let toDict = to.dictionaryValue else {
            return .dictionary(["from": from, "to": to])
        }

        var changes: [String: AnyCodableValue] = [:]
        let allKeys = Set(fromDict.keys).union(Set(toDict.keys))

        for key in allKeys {
            let fromVal = fromDict[key]
            let toVal = toDict[key]

            if fromVal == nil && toVal != nil {
                changes[key] = .dictionary([
                    "type": "added",
                    "value": toVal ?? .null
                ])
            } else if fromVal != nil && toVal == nil {
                changes[key] = .dictionary([
                    "type": "removed",
                    "value": fromVal ?? .null
                ])
            } else if fromVal != toVal {
                changes[key] = .dictionary([
                    "type": "changed",
                    "from": fromVal ?? .null,
                    "to": toVal ?? .null
                ])
            }
        }

        return .dictionary(changes)
    }
}
