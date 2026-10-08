public enum RepositoryError: Error, Equatable, Sendable {
    case invalidTransition
    case anotherTaskInTransit
    case taskNotFound
    case undoWindowClosed
    case exceptionDetailsRequired
    case shiftHasTaskInTransit
    case shiftNotActive
    case taskNotInActiveShift
    case invalidShiftTransition
    case storageFailure(String)
}

public enum SyncError: Error, Equatable, Sendable, CustomStringConvertible {
    case offline
    case timedOut
    case connectionLost
    case server(status: Int)
    case decodingFailed
    case cancelled
    case storageFailure(String)

    public var description: String {
        switch self {
        case .offline: "Offline"
        case .timedOut: "Request timed out"
        case .connectionLost: "Connection lost"
        case .server(let status): "Server error \(status)"
        case .decodingFailed: "Invalid server response"
        case .cancelled: "Cancelled"
        case .storageFailure(let message): "Local storage failure: \(message)"
        }
    }
}
