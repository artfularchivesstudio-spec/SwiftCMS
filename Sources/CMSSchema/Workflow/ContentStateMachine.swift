import CMSObjects

/// Enforces the content lifecycle state machine.
public struct ContentStateMachine: Sendable {

    /// Returns the allowed transitions from a given state.
    public static func allowedTransitions(from state: ContentStatus) -> [ContentStatus] {
        switch state {
        case .draft:
            return [.review, .published]
        case .review:
            return [.draft, .published]
        case .published:
            return [.draft, .archived]
        case .archived:
            return [.draft, .deleted]
        case .deleted:
            return []  // Terminal state
        }
    }

    /// Check if a transition from one state to another is valid.
    public static func canTransition(from: ContentStatus, to: ContentStatus) -> Bool {
        allowedTransitions(from: from).contains(to)
    }

    /// Validate and return the transition, or throw an error.
    public static func validateTransition(
        from: ContentStatus,
        to: ContentStatus
    ) throws {
        guard canTransition(from: from, to: to) else {
            throw ApiError.unprocessableEntity(
                "Invalid state transition from '\(from.rawValue)' to '\(to.rawValue)'. " +
                "Allowed transitions: \(allowedTransitions(from: from).map(\.rawValue).joined(separator: ", "))"
            )
        }
    }
}
