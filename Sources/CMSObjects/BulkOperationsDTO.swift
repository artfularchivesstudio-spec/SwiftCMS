import Vapor
import Foundation

/// DTO for bulk operations on content entries.
public struct BulkOperationDTO: Content, Sendable, Validatable {
    /// Array of entry IDs to operate on.
    public let entryIds: [UUID]
    /// Operation to perform: publish, unpublish, delete, changeLocale.
    public let action: BulkAction
    /// Target locale (for changeLocale action).
    public let locale: String?
    /// Target status (for status change actions).
    public let status: ContentStatus?

    public init(
        entryIds: [UUID],
        action: BulkAction,
        locale: String? = nil,
        status: ContentStatus? = nil
    ) {
        self.entryIds = entryIds
        self.action = action
        self.locale = locale
        self.status = status
    }

    public static func validations(_ validations: inout Validations) {
        validations.add("entryIds", as: [UUID].self, required: true)
        validations.add("action", as: String.self, required: true)
    }
}

/// Bulk action types.
public enum BulkAction: String, Codable, Sendable {
    case publish
    case unpublish
    case delete
    case changeLocale
    case archive
    case restore
}

/// DTO for bulk operation results.
public struct BulkOperationResultDTO: Content, Sendable {
    /// Number of successfully processed entries.
    public let successCount: Int
    /// Number of failed entries.
    public let failureCount: Int
    /// IDs of successfully processed entries.
    public let successIds: [UUID]
    /// IDs of failed entries with error messages.
    public let failures: [BulkFailure]
    /// Action that was performed.
    public let action: BulkAction
    /// Whether the action can be undone.
    public let canUndo: Bool
    /// Undo token if applicable.
    public let undoToken: String?

    public init(
        successCount: Int,
        failureCount: Int,
        successIds: [UUID],
        failures: [BulkFailure],
        action: BulkAction,
        canUndo: Bool = false,
        undoToken: String? = nil
    ) {
        self.successCount = successCount
        self.failureCount = failureCount
        self.successIds = successIds
        self.failures = failures
        self.action = action
        self.canUndo = canUndo
        self.undoToken = undoToken
    }
}

/// Bulk operation failure details.
public struct BulkFailure: Content, Sendable {
    /// ID of the entry that failed.
    public let entryId: UUID
    /// Error message.
    public let error: String

    public init(entryId: UUID, error: String) {
        self.entryId = entryId
        self.error = error
    }
}

/// DTO for bulk operations on media files.
public struct BulkMediaOperationDTO: Content, Sendable, Validatable {
    /// Array of media file IDs to operate on.
    public let fileIds: [UUID]
    /// Operation to perform: delete, move.
    public let action: BulkMediaAction
    /// Target folder path (for move action).
    public let targetPath: String?

    public init(
        fileIds: [UUID],
        action: BulkMediaAction,
        targetPath: String? = nil
    ) {
        self.fileIds = fileIds
        self.action = action
        self.targetPath = targetPath
    }

    public static func validations(_ validations: inout Validations) {
        validations.add("fileIds", as: [UUID].self, required: true)
        validations.add("action", as: String.self, required: true)
    }
}

/// Bulk media action types.
public enum BulkMediaAction: String, Codable, Sendable {
    case delete
    case move
}

/// DTO for bulk media operation results.
public struct BulkMediaResultDTO: Content, Sendable {
    /// Number of successfully processed files.
    public let successCount: Int
    /// Number of failed files.
    public let failureCount: Int
    /// IDs of successfully processed files.
    public let successIds: [UUID]
    /// IDs of failed files with error messages.
    public let failures: [BulkFailure]
    /// Action that was performed.
    public let action: BulkMediaAction

    public init(
        successCount: Int,
        failureCount: Int,
        successIds: [UUID],
        failures: [BulkFailure],
        action: BulkMediaAction
    ) {
        self.successCount = successCount
        self.failureCount = failureCount
        self.successIds = successIds
        self.failures = failures
        self.action = action
    }
}
