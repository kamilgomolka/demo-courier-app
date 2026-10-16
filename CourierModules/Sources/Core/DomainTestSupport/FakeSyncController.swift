#if DEBUG
    public import Domain
    import Synchronization

    public final class FakeSyncController: SyncControlling {
        private struct State {
            var triggers: [SyncTrigger] = []
            var loadCallCount = 0
            var resetCallCount = 0
            var loadFailure: SyncError?
            var resetFailure: RepositoryError?
        }

        private let state = Mutex(State())

        public init() {}

        public var triggers: [SyncTrigger] {
            state.withLock { $0.triggers }
        }

        public var loadCallCount: Int {
            state.withLock { $0.loadCallCount }
        }

        public var resetCallCount: Int {
            state.withLock { $0.resetCallCount }
        }

        public var loadFailure: SyncError? {
            get { state.withLock { $0.loadFailure } }
            set { state.withLock { $0.loadFailure = newValue } }
        }

        public var resetFailure: RepositoryError? {
            get { state.withLock { $0.resetFailure } }
            set { state.withLock { $0.resetFailure = newValue } }
        }

        public func requestSync(_ trigger: SyncTrigger) async {
            state.withLock { $0.triggers.append(trigger) }
        }

        public func loadInitialData() async throws(SyncError) {
            let failure = state.withLock { state -> SyncError? in
                state.loadCallCount += 1
                return state.loadFailure
            }
            if let failure {
                throw failure
            }
        }

        public func resetLocalData() async throws(RepositoryError) {
            let failure = state.withLock { state -> RepositoryError? in
                state.resetCallCount += 1
                return state.resetFailure
            }
            if let failure {
                throw failure
            }
        }
    }
#endif
