import Domain
import DomainTestSupport
import Foundation
import Synchronization
import Testing

@testable import LocalStorage

private final class ThreadRecordingTimeSource: TimeSource {
    let callsOnMainThread = Mutex<[Bool]>([])
    private let timeSource = ManualTimeSource()

    func now() -> Date {
        callsOnMainThread.withLock { $0.append(Thread.isMainThread) }
        return timeSource.now()
    }

    func sleep(until deadline: Date) async throws {
        try await timeSource.sleep(until: deadline)
    }
}

struct StoreExecutionTests {
    @MainActor @Test func storeCreatedFromMainActorExecutesMutationsOffMainThread() async throws {
        let timeSource = ThreadRecordingTimeSource()
        let store = try await CourierStorage.makeStore(isStoredInMemoryOnly: true, timeSource: timeSource)
        try await store.mergeRemoteSnapshot(StoreFixture.snapshot())

        try await store.startShift()

        #expect(timeSource.callsOnMainThread.withLock { $0 } == [false])
    }
}
