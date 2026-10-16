#if DEBUG
    public import Domain
    import Synchronization

    public final class FakeShiftRepository: ShiftRepository {
        public enum Call: Equatable, Sendable {
            case startShift
            case endShift
            case reopenShift
        }

        public let summary = StreamBroadcaster<ShiftSummary?>(nil)

        private struct State {
            var calls: [Call] = []
            var failure: RepositoryError?
            var heldCalls: AsyncStream<Void>?
            var heldCallsContinuation: AsyncStream<Void>.Continuation?
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

        public func observeShiftSummary() -> AsyncStream<ShiftSummary?> {
            summary.stream()
        }

        public func startShift() async throws(RepositoryError) {
            try await record(.startShift)
        }

        public func endShift() async throws(RepositoryError) {
            try await record(.endShift)
        }

        public func reopenShift() async throws(RepositoryError) {
            try await record(.reopenShift)
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
