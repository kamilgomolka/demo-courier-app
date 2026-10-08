import Domain
import DomainTestSupport
import Foundation
import Synchronization
import Testing

@testable import LocalStorage

struct ObservationTests {
    @Test func queueEmitsInitialSnapshotInQueueOrder() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-3")

        let queue = try #require(await firstValue(of: fixture.store.observeQueue()))

        #expect(queue.map(\.id) == ["task-3", "task-1", "task-2", "task-4", "task-5"])
    }

    @Test func completedTasksAreOrderedByCompletionDescending() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.markDelivered(id: "task-1")
        fixture.timeSource.advance(by: 10)
        try await fixture.store.startDelivery(id: "task-2")
        try await fixture.store.reportException(id: "task-2", reason: .addressNotFound)

        let completed = try #require(await firstValue(of: fixture.store.observeCompleted()))

        #expect(completed.map(\.id) == ["task-2", "task-1"])
    }

    @Test func streamDoesNotEmitWhenSnapshotIsUnchanged() async throws {
        let fixture = try await StoreFixture.make(startedShift: false)
        let received = Mutex<[[TaskID]]>([])
        let consumer = Task {
            for await queue in fixture.store.observeQueue() {
                received.withLock { $0.append(queue.map(\.id)) }
            }
        }
        #expect(await eventually { received.withLock { $0.count } == 1 })

        try await fixture.store.startShift()
        try await fixture.store.commitDelivery(id: "task-1")
        try await fixture.store.startDelivery(id: "task-2")

        #expect(await eventually { received.withLock { $0.count } == 2 })
        consumer.cancel()
        #expect(received.withLock { $0.last } == ["task-2", "task-1", "task-3", "task-4", "task-5"])
    }

    @Test func cancellingConsumerRemovesObserver() async throws {
        let fixture = try await StoreFixture.make()
        let consumer = Task {
            for await _ in fixture.store.observeQueue() {}
        }
        #expect(await eventually { await fixture.store.activeObserverCount == 1 })

        consumer.cancel()

        #expect(await eventually { await fixture.store.activeObserverCount == 0 })
    }

    @Test func observersAreRemovedAfterConsumersFinishAcrossAllStreams() async throws {
        let fixture = try await StoreFixture.make()
        let consumers = [
            Task { for await _ in fixture.store.observeQueue() {} },
            Task { for await _ in fixture.store.observeCompleted() {} },
            Task { for await _ in fixture.store.observeTask(id: "task-1") {} },
            Task { for await _ in fixture.store.observeShiftSummary() {} },
            Task { for await _ in fixture.store.observeJobs() {} },
        ]
        #expect(await eventually { await fixture.store.activeObserverCount == 5 })

        consumers.forEach { $0.cancel() }

        #expect(await eventually { await fixture.store.activeObserverCount == 0 })
    }

    @Test func shiftSummaryTracksEarningsAndProgress() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.markDelivered(id: "task-1")
        try await fixture.store.startDelivery(id: "task-2")
        try await fixture.store.reportException(id: "task-2", reason: .packageDamaged)
        try await fixture.store.startDelivery(id: "task-3")

        let summary = try await fixture.shiftSummary()

        #expect(summary.status == .active)
        #expect(summary.earnings == 20)
        #expect(summary.completedCount == 2)
        #expect(summary.totalCount == 5)
        #expect(summary.hasTaskInTransit)
    }

    @Test func shiftSummaryIsNilForEmptyDatabase() async throws {
        let container = try CourierStorage.makeContainer(isStoredInMemoryOnly: true)
        let store = LocalStore(modelContainer: container)

        let summary = await firstValue(of: store.observeShiftSummary())

        #expect(summary == .some(nil))
    }

    @Test func shiftLifecycleFollowsAllowedTransitionsOnly() async throws {
        let fixture = try await StoreFixture.make(startedShift: false)

        await #expect(throws: RepositoryError.invalidShiftTransition) {
            try await fixture.store.endShift()
        }
        try await fixture.store.startShift()
        await #expect(throws: RepositoryError.invalidShiftTransition) {
            try await fixture.store.startShift()
        }
        try await fixture.store.endShift()
        await #expect(throws: RepositoryError.invalidShiftTransition) {
            try await fixture.store.startShift()
        }
        let summary = try await fixture.shiftSummary()
        #expect(summary.status == .finished)
    }

    @Test func endShiftIsBlockedWhileTaskIsInTransit() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")

        await #expect(throws: RepositoryError.shiftHasTaskInTransit) {
            try await fixture.store.endShift()
        }
    }

    @Test func remoteMergeInsertsOnlyUnknownRecords() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        var snapshot = StoreFixture.snapshot(taskCount: 6)
        snapshot.shift.status = .scheduled

        try await fixture.store.mergeRemoteSnapshot(snapshot)

        let task = try await fixture.task("task-1")
        let queue = try await fixture.queueIDs()
        let summary = try await fixture.shiftSummary()
        #expect(task.status == .inTransit)
        #expect(queue.count == 6)
        #expect(summary.status == .active)
    }

    @Test func resetRemovesEverything() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")

        try await fixture.store.resetAllData()

        #expect(try await fixture.queueIDs().isEmpty)
        #expect(try await fixture.jobs().isEmpty)
        #expect(await firstValue(of: fixture.store.observeShiftSummary()) == .some(nil))
    }
}
