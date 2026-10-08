public import Domain
import Synchronization

public final class FakeShiftRepository: ShiftRepository {
    public enum Call: Equatable, Sendable {
        case startShift
        case endShift
    }

    public let summary = StreamBroadcaster<ShiftSummary?>(nil)

    private struct State {
        var calls: [Call] = []
        var failure: RepositoryError?
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
        try record(.startShift)
    }

    public func endShift() async throws(RepositoryError) {
        try record(.endShift)
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
