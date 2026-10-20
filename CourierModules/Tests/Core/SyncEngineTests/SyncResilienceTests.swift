import Domain
import DomainTestSupport
import Foundation
import SwiftData
import Testing

@testable import LocalStorage
@testable import SyncEngine

private final class OpenedContainers {
    private struct Entry {
        weak var container: ModelContainer?
    }

    private var entries: [Entry] = []

    var areAllReleased: Bool {
        entries.allSatisfy { $0.container == nil }
    }

    func record(_ container: ModelContainer) {
        entries.append(Entry(container: container))
    }
}

struct SyncResilienceTests {
    private let openedContainers = OpenedContainers()

    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "CourierResilience-\(UUID().uuidString).store")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path() + suffix))
        }
    }

    private func withStoreURL(_ body: (URL) async throws -> Void) async throws {
        let url = makeStoreURL()
        var failure: (any Error)?

        do {
            try await body(url)
        } catch {
            failure = error
        }

        _ = await eventually { openedContainers.areAllReleased }
        removeStore(at: url)

        if let failure {
            throw failure
        }
    }

    private func openHarness(at url: URL, timeSource: ManualTimeSource, latency: TimeInterval = 0) throws
        -> StoreBackedHarness
    {
        let container = try CourierStorage.makeContainer(storeURL: url)
        let store = LocalStore(modelContainer: container, timeSource: timeSource)
        openedContainers.record(container)
        return StoreBackedHarness(store: store, timeSource: timeSource, latency: latency)
    }

    @Test func expiredJobIsSentAfterRestart() async throws {
        try await withStoreURL { url in
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
    }

    @Test func unacknowledgedJobIsReplayedWithTheSameIdempotencyKey() async throws {
        try await withStoreURL { url in
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
    }

    @Test func resetDuringInFlightRequestLeavesFreshDatabaseUntouchedAndRestartsTheWorker() async throws {
        try await withStoreURL { url in
            let timeSource = ManualTimeSource()
            let harness = try openHarness(at: url, timeSource: timeSource, latency: 1)
            try await harness.store.mergeRemoteSnapshot(sampleSnapshot())
            try await harness.store.startShift()
            try await harness.store.startDelivery(id: "task-1")
            await harness.start()
            #expect(await eventually { timeSource.pendingSleeperCount == 1 })

            let reset = Task { try await harness.syncActor.resetLocalData() }
            #expect(await eventually { await harness.pendingJobs().isEmpty && timeSource.pendingSleeperCount == 1 })
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
}
