#if DEBUG
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
            var heldCalls: AsyncStream<Void>?
            var heldCallsContinuation: AsyncStream<Void>.Continuation?
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
            try await record(.startDelivery(id))
        }

        public func markDelivered(id: TaskID) async throws(RepositoryError) {
            try await record(.markDelivered(id))
        }

        public func undoDelivery(id: TaskID) async throws(RepositoryError) {
            try await record(.undoDelivery(id))
        }

        public func commitDelivery(id: TaskID) async throws(RepositoryError) {
            try await record(.commitDelivery(id))
        }

        public func reportException(id: TaskID, reason: ExceptionReason) async throws(RepositoryError) {
            try await record(.reportException(id, reason))
        }

        public func reorderQueue(orderedTaskIDs: [TaskID]) async throws(RepositoryError) {
            try await record(.reorderQueue(orderedTaskIDs))
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

        public func holdCalls() {
            let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
            state.withLock {
                $0.heldCalls = stream
                $0.heldCallsContinuation = continuation
            }
        }

        public func releaseCalls() {
            let continuation = state.withLock { state -> AsyncStream<Void>.Continuation? in
                defer {
                    state.heldCalls = nil
                    state.heldCallsContinuation = nil
                }
                return state.heldCallsContinuation
            }
            continuation?.finish()
        }

        private func record(_ call: Call) async throws(RepositoryError) {
            let (failure, heldCalls) = state.withLock { state -> (RepositoryError?, AsyncStream<Void>?) in
                state.calls.append(call)
                return (state.failure, state.heldCalls)
            }
            if let heldCalls {
                for await _ in heldCalls {}
            }
            if let failure {
                throw failure
            }
        }
    }
#endif
