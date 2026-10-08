public import Domain
import Synchronization

public final class FakeTaskRepository: TaskRepository {
    public enum Call: Equatable, Sendable {
        case startDelivery(TaskID)
        case markDelivered(TaskID)
        case undoDelivery(TaskID)
        case commitDelivery(TaskID)
        case reportException(TaskID, ExceptionReason)
        case reorderQueue([TaskID])
    }

    public let queue = StreamBroadcaster<[DeliveryTask]>([])
    public let completed = StreamBroadcaster<[DeliveryTask]>([])

    private struct State {
        var calls: [Call] = []
        var failure: RepositoryError?
        var taskBroadcasters: [TaskID: StreamBroadcaster<DeliveryTask?>] = [:]
    }

    private let state = Mutex(State())

    public init() {}

    public var calls: [Call] {
        state.withLock { $0.calls }
    }

    public var failure: RepositoryError? {
        get { state.withLock { $0.failure } }
        set { state.withLock { $0.failure = newValue } }
    }

    public func send(_ task: DeliveryTask?, for id: TaskID) {
        broadcaster(for: id).send(task)
    }

    public func activeTaskObserverCount(for id: TaskID) -> Int {
        broadcaster(for: id).activeObserverCount
    }

    public func observeQueue() -> AsyncStream<[DeliveryTask]> {
        queue.stream()
    }

    public func observeTask(id: TaskID) -> AsyncStream<DeliveryTask?> {
        broadcaster(for: id).stream()
    }

    public func observeCompleted() -> AsyncStream<[DeliveryTask]> {
        completed.stream()
    }

    public func startDelivery(id: TaskID) async throws(RepositoryError) {
        try record(.startDelivery(id))
    }

    public func markDelivered(id: TaskID) async throws(RepositoryError) {
        try record(.markDelivered(id))
    }

    public func undoDelivery(id: TaskID) async throws(RepositoryError) {
        try record(.undoDelivery(id))
    }

    public func commitDelivery(id: TaskID) async throws(RepositoryError) {
        try record(.commitDelivery(id))
    }

    public func reportException(id: TaskID, reason: ExceptionReason) async throws(RepositoryError) {
        try record(.reportException(id, reason))
    }

    public func reorderQueue(orderedTaskIDs: [TaskID]) async throws(RepositoryError) {
        try record(.reorderQueue(orderedTaskIDs))
    }

    private func broadcaster(for id: TaskID) -> StreamBroadcaster<DeliveryTask?> {
        state.withLock { state in
            if let existing = state.taskBroadcasters[id] {
                return existing
            }
            let created = StreamBroadcaster<DeliveryTask?>(nil)
            state.taskBroadcasters[id] = created
            return created
        }
    }

    private func record(_ call: Call) throws(RepositoryError) {
        let failure = state.withLock { state -> RepositoryError? in
            state.calls.append(call)
            return state.failure
        }
        if let failure {
            throw failure
        }
    }
}
