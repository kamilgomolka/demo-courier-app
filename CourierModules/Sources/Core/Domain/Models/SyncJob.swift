public import Foundation

public enum SyncJobKind: Codable, Hashable, Sendable {
    case updateStatus(taskID: TaskID, status: TaskStatus, exceptionReason: ExceptionReason?)
    case reorder(orderedTaskIDs: [TaskID])

    public var taskID: TaskID? {
        guard case .updateStatus(let taskID, _, _) = self else { return nil }
        return taskID
    }
}

public struct SyncJob: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: SyncJobKind
    public var createdAt: Date
    public var notBefore: Date
    public var attemptCount: Int
    public var lastFailure: String?

    public init(
        id: UUID = UUID(),
        kind: SyncJobKind,
        createdAt: Date,
        notBefore: Date,
        attemptCount: Int = 0,
        lastFailure: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.notBefore = notBefore
        self.attemptCount = attemptCount
        self.lastFailure = lastFailure
    }
}
