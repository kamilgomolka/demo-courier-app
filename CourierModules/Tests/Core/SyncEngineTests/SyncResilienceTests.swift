import Domain
import DomainTestSupport
import Foundation
import Testing

@testable import LocalStorage
@testable import SyncEngine

struct SyncResilienceTests {
    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "CourierResilience-\(UUID().uuidString).store")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path() + suffix))
        }
    }

    private func openHarness(at url: URL, timeSource: ManualTimeSource, latency: TimeInterval = 0) throws
        -> StoreBackedHarness
    {
        let container = try CourierStorage.makeContainer(storeURL: url)
        return StoreBackedHarness(
            store: LocalStore(modelContainer: container, timeSource: timeSource),
            timeSource: timeSource,
            latency: latency
        )
    }

    @Test func expiredJobIsSentAfterRestart() async throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let timeSource = ManualTimeSource()
        do {
            let firstRun = try openHarness(at: url, timeSource: timeSource)
            try await firstRun.store.mergeRemoteSnapshot(sampleSnapshot())
            try await firstRun.store.startShift()
            try await firstRun.store.startDelivery(id: "task-1")
            try await firstRun.store.markDelivered(id: "task-1")
        }
        timeSource.advance(by: SyncPolicy.undoWindow + 1)

        let secondRun = try openHarness(at: url, timeSource: timeSource)
        await secondRun.start()
        await secondRun.syncActor.requestSync(.launch)

        #expect(await eventually { await secondRun.pendingJobs().isEmpty })
        #expect(secondRun.api.requests.count == 2)
        await secondRun.syncActor.stop()
    }

    @Test func unacknowledgedJobIsReplayedWithTheSameIdempotencyKey() async throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let timeSource = ManualTimeSource()
        let firstRun = try openHarness(at: url, timeSource: timeSource)
        try await firstRun.store.mergeRemoteSnapshot(sampleSnapshot())
        try await firstRun.store.startShift()
        try await firstRun.store.startDelivery(id: "task-1")
        let job = try #require(await firstRun.pendingJobs().first)
        try await firstRun.api.send(job)

        let secondRun = try openHarness(at: url, timeSource: timeSource)
        await secondRun.start()
        await secondRun.syncActor.requestSync(.launch)

        #expect(await eventually { await secondRun.pendingJobs().isEmpty })
        #expect(firstRun.api.requests.first?.idempotencyKey == job.id)
        #expect(secondRun.api.requests.first?.idempotencyKey == job.id)
        await secondRun.syncActor.stop()
    }

    @Test func resetDuringInFlightRequestLeavesFreshDatabaseUntouchedAndRestartsTheWorker() async throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let timeSource = ManualTimeSource()
        let harness = try openHarness(at: url, timeSource: timeSource, latency: 1)
        try await harness.store.mergeRemoteSnapshot(sampleSnapshot())
        try await harness.store.startShift()
        try await harness.store.startDelivery(id: "task-1")
        await harness.start()
        #expect(await eventually { timeSource.pendingSleeperCount == 1 })

        let reset = Task { try await harness.syncActor.resetLocalData() }
        #expect(await eventually { timeSource.pendingSleeperCount == 1 })
        try await Task.sleep(for: .milliseconds(100))
        timeSource.advance(by: 1)
        try await reset.value

        #expect(harness.api.requests.filter { $0.method == "PATCH" }.isEmpty)
        var iterator = harness.store.observeQueue().makeAsyncIterator()
        let queue = try #require(await iterator.next())
        #expect(queue.count == 12)
        #expect(queue.allSatisfy { $0.status == .new && $0.syncState == .synced })
        #expect(await harness.pendingJobs().isEmpty)

        try await harness.store.startShift()
        try await harness.store.startDelivery(id: "task-01")
        #expect(await eventually { timeSource.pendingSleeperCount == 1 })
        timeSource.advance(by: 1)
        #expect(await eventually { harness.api.requests.filter { $0.method == "PATCH" }.count == 1 })
        await harness.syncActor.stop()
    }
}
