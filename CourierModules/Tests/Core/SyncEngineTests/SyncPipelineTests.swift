import Domain
import DomainTestSupport
import Foundation
import Testing

@testable import LocalStorage
@testable import SyncEngine

struct SyncPipelineTests {
    @Test func inTransitUpdateIsSentImmediatelyAndAcknowledged() async throws {
        let harness = try await StoreBackedHarness.inMemory()
        await harness.start()

        try await harness.store.startDelivery(id: "task-1")

        #expect(await eventually { harness.api.requests.count == 1 })
        #expect(await eventually { await harness.pendingJobs().isEmpty })
    }

    @Test func deliveredUpdateWaitsForUndoWindowThenSyncs() async throws {
        let harness = try await StoreBackedHarness.inMemory()
        await harness.start()
        try await harness.store.startDelivery(id: "task-1")
        #expect(await eventually { await harness.pendingJobs().isEmpty })

        try await harness.store.markDelivered(id: "task-1")
        try await Task.sleep(for: .milliseconds(50))
        #expect(harness.api.requests.count == 1)

        harness.timeSource.advance(by: SyncPolicy.undoWindow)

        #expect(await eventually { harness.api.requests.count == 2 })
        #expect(await eventually { await harness.pendingJobs().isEmpty })
    }

    @Test func undoWithinWindowSendsNothing() async throws {
        let harness = try await StoreBackedHarness.inMemory()
        await harness.start()
        try await harness.store.startDelivery(id: "task-1")
        #expect(await eventually { await harness.pendingJobs().isEmpty })
        try await harness.store.markDelivered(id: "task-1")
        harness.timeSource.advance(by: 2)

        try await harness.store.undoDelivery(id: "task-1")
        harness.timeSource.advance(by: 20)
        try await Task.sleep(for: .milliseconds(100))

        #expect(harness.api.requests.count == 1)
    }

    @Test func commitSendsTheDeliveredUpdateWithoutWaiting() async throws {
        let harness = try await StoreBackedHarness.inMemory()
        await harness.start()
        try await harness.store.startDelivery(id: "task-1")
        #expect(await eventually { await harness.pendingJobs().isEmpty })
        try await harness.store.markDelivered(id: "task-1")

        try await harness.store.commitDelivery(id: "task-1")

        #expect(await eventually { harness.api.requests.count == 2 })
    }

    @Test func reorderIsSentOnceAfterTheDebounceEvenWhenMovedRepeatedly() async throws {
        let harness = try await StoreBackedHarness.inMemory()
        await harness.start()

        try await harness.store.reorderQueue(orderedTaskIDs: ["task-2", "task-1", "task-3", "task-4"])
        harness.timeSource.advance(by: 3)
        try await harness.store.reorderQueue(orderedTaskIDs: ["task-4", "task-2", "task-1", "task-3"])
        harness.timeSource.advance(by: 3)
        try await Task.sleep(for: .milliseconds(50))
        #expect(harness.api.requests.isEmpty)

        harness.timeSource.advance(by: 2.1)

        #expect(await eventually { harness.api.requests.count == 1 })
        #expect(harness.api.requests.first?.path == "/route-optimization")
    }

    @Test func offlineChangesSyncAfterConnectivityReturns() async throws {
        let harness = try await StoreBackedHarness.inMemory()
        harness.conditions.save(NetworkConditions(isOffline: true))
        await harness.start()
        try await harness.store.startDelivery(id: "task-1")
        try await Task.sleep(for: .milliseconds(50))
        #expect(await harness.pendingJobs().count == 1)

        harness.conditions.save(NetworkConditions(latencyRange: 0...0))
        await harness.syncActor.requestSync(.connectivityRestored)

        #expect(await harness.pendingJobs().isEmpty)
        #expect(harness.api.requests.count == 1)
    }

    @Test func initialLoadInsertsBundledDataAndIsIdempotent() async throws {
        let container = try CourierStorage.makeContainer(isStoredInMemoryOnly: true)
        let timeSource = ManualTimeSource()
        let harness = StoreBackedHarness(
            store: LocalStore(modelContainer: container, timeSource: timeSource),
            timeSource: timeSource
        )

        try await harness.syncActor.loadInitialData()
        try await harness.syncActor.loadInitialData()

        var iterator = harness.store.observeQueue().makeAsyncIterator()
        let queue = try #require(await iterator.next())
        #expect(queue.count == 12)
    }

    @Test func overlappingInitialLoadsShareOneRequest() async throws {
        let container = try CourierStorage.makeContainer(isStoredInMemoryOnly: true)
        let timeSource = ManualTimeSource()
        let harness = StoreBackedHarness(
            store: LocalStore(modelContainer: container, timeSource: timeSource),
            timeSource: timeSource,
            latency: 1
        )

        async let first: Void = harness.syncActor.loadInitialData()
        async let second: Void = harness.syncActor.loadInitialData()
        #expect(await eventually { timeSource.pendingSleeperCount == 1 })
        try await Task.sleep(for: .milliseconds(50))
        timeSource.advance(by: 1)
        _ = try await (first, second)

        #expect(harness.api.requests.count == 1)
    }

    @Test func initialLoadFailureIsReportedAndLeavesTheStoreEmpty() async throws {
        let container = try CourierStorage.makeContainer(isStoredInMemoryOnly: true)
        let timeSource = ManualTimeSource()
        let harness = StoreBackedHarness(
            store: LocalStore(modelContainer: container, timeSource: timeSource),
            timeSource: timeSource
        )
        harness.conditions.save(NetworkConditions(isOffline: true))

        await #expect(throws: SyncError.offline) {
            try await harness.syncActor.loadInitialData()
        }

        var iterator = harness.store.observeShiftSummary().makeAsyncIterator()
        #expect(await iterator.next() == .some(nil))
    }
}
