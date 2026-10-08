import Foundation
import Synchronization

public final class StreamBroadcaster<Value: Sendable>: Sendable {
    private struct State {
        var current: Value
        var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
    }

    private let state: Mutex<State>

    public init(_ initial: Value) {
        state = Mutex(State(current: initial))
    }

    public var current: Value {
        state.withLock { $0.current }
    }

    public var activeObserverCount: Int {
        state.withLock { $0.continuations.count }
    }

    public func send(_ value: Value) {
        let continuations = state.withLock { state -> [AsyncStream<Value>.Continuation] in
            state.current = value
            return Array(state.continuations.values)
        }
        for continuation in continuations {
            continuation.yield(value)
        }
    }

    public func update(_ transform: (inout Value) -> Void) {
        var value = current
        transform(&value)
        send(value)
    }

    public func stream() -> AsyncStream<Value> {
        let (stream, continuation) = AsyncStream.makeStream(of: Value.self, bufferingPolicy: .bufferingNewest(1))
        let observerID = UUID()
        let initial = state.withLock { state -> Value in
            state.continuations[observerID] = continuation
            return state.current
        }
        continuation.yield(initial)
        continuation.onTermination = { [weak self] _ in
            self?.state.withLock { _ = $0.continuations.removeValue(forKey: observerID) }
        }
        return stream
    }
}
