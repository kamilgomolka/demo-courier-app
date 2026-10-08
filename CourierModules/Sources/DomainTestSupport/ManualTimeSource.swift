public import Domain
public import Foundation
import Synchronization

public final class ManualTimeSource: TimeSource {
    private struct Sleeper {
        let deadline: Date
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var current: Date
        var sleepers: [UUID: Sleeper] = [:]
    }

    private let state: Mutex<State>

    public init(start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        state = Mutex(State(current: start))
    }

    public func now() -> Date {
        state.withLock { $0.current }
    }

    public var pendingSleeperCount: Int {
        state.withLock { $0.sleepers.count }
    }

    public func sleep(until deadline: Date) async throws {
        let sleeperID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let immediateOutcome: Result<Void, any Error>? = state.withLock { state in
                    if Task.isCancelled {
                        return .failure(CancellationError())
                    }
                    guard deadline > state.current else {
                        return .success(())
                    }
                    state.sleepers[sleeperID] = Sleeper(deadline: deadline, continuation: continuation)
                    return nil
                }
                if let immediateOutcome {
                    continuation.resume(with: immediateOutcome)
                }
            }
        } onCancel: {
            let sleeper = state.withLock { $0.sleepers.removeValue(forKey: sleeperID) }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    public func advance(by interval: TimeInterval) {
        let dueSleepers = state.withLock { state -> [Sleeper] in
            state.current = state.current.addingTimeInterval(interval)
            let dueIdentifiers = state.sleepers.filter { $0.value.deadline <= state.current }.keys
            return dueIdentifiers.compactMap { state.sleepers.removeValue(forKey: $0) }
        }
        for sleeper in dueSleepers {
            sleeper.continuation.resume()
        }
    }
}
