import Domain
import DomainTestSupport
import Foundation
import Testing

@testable import LocalStorage

struct ReorderTests {
    @Test func reorderUpdatesQueueOrderAndCreatesDebouncedJob() async throws {
        let fixture = try await StoreFixture.make()

        try await fixture.store.reorderQueue(orderedTaskIDs: ["task-3", "task-1", "task-2", "task-4", "task-5"])

        let job = try #require(try await fixture.jobs().first)
        #expect(try await fixture.queueIDs() == ["task-3", "task-1", "task-2", "task-4", "task-5"])
        #expect(job.kind == .reorder(orderedTaskIDs: ["task-3", "task-1", "task-2", "task-4", "task-5"]))
        #expect(job.notBefore == fixture.timeSource.now().addingTimeInterval(SyncPolicy.reorderDebounce))
    }

    @Test func consecutiveReordersCoalesceIntoOneJobAndPushTheDeadline() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.reorderQueue(orderedTaskIDs: ["task-2", "task-1", "task-3", "task-4", "task-5"])
        let firstJob = try #require(try await fixture.jobs().first)
        fixture.timeSource.advance(by: 3)

        try await fixture.store.reorderQueue(orderedTaskIDs: ["task-5", "task-2", "task-1", "task-3", "task-4"])

        let jobs = try await fixture.jobs()
        let secondJob = try #require(jobs.first)
        #expect(jobs.count == 1)
        #expect(secondJob.id != firstJob.id)
        #expect(secondJob.kind == .reorder(orderedTaskIDs: ["task-5", "task-2", "task-1", "task-3", "task-4"]))
        #expect(secondJob.notBefore > firstJob.notBefore)
    }

    @Test func reorderingToTheCurrentOrderWithoutPendingJobDoesNothing() async throws {
        let fixture = try await StoreFixture.make()

        try await fixture.store.reorderQueue(orderedTaskIDs: ["task-1", "task-2", "task-3", "task-4", "task-5"])

        #expect(try await fixture.jobs().isEmpty)
    }

    @Test func startingDeliveryRemovesTaskFromPendingReorderPayload() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.reorderQueue(orderedTaskIDs: ["task-3", "task-1", "task-2", "task-4", "task-5"])

        try await fixture.store.startDelivery(id: "task-3")

        let reorderJob = try #require(
            try await fixture.jobs().first { if case .reorder = $0.kind { true } else { false } })
        #expect(reorderJob.kind == .reorder(orderedTaskIDs: ["task-1", "task-2", "task-4", "task-5"]))
    }

    @Test func reorderJobIsDroppedWhenFewerThanTwoTasksRemain() async throws {
        let fixture = try await StoreFixture.make(snapshot: StoreFixture.snapshot(taskCount: 3))
        try await fixture.store.reorderQueue(orderedTaskIDs: ["task-3", "task-2", "task-1"])

        try await fixture.store.startDelivery(id: "task-3")
        try await fixture.store.markDelivered(id: "task-3")
        try await fixture.store.startDelivery(id: "task-2")

        let hasReorderJob = try await fixture.jobs().contains { if case .reorder = $0.kind { true } else { false } }
        #expect(!hasReorderJob)
    }

    @Test func reorderRequiresActiveShift() async throws {
        let fixture = try await StoreFixture.make(startedShift: false)

        await #expect(throws: RepositoryError.shiftNotActive) {
            try await fixture.store.reorderQueue(orderedTaskIDs: ["task-2", "task-1"])
        }
    }

    @Test func reorderRejectsTasksOutsideTheActiveShift() async throws {
        var snapshot = StoreFixture.snapshot()
        snapshot.tasks.append(.fixture(id: "foreign", sortOrder: 99, shiftID: "other-shift"))
        let fixture = try await StoreFixture.make(snapshot: snapshot)

        await #expect(throws: RepositoryError.taskNotInActiveShift) {
            try await fixture.store.reorderQueue(orderedTaskIDs: ["foreign", "task-1"])
        }
    }

    @Test func reorderRejectsTasksThatAreNotNew() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")

        await #expect(throws: RepositoryError.invalidTransition) {
            try await fixture.store.reorderQueue(orderedTaskIDs: ["task-2", "task-1"])
        }
    }
}
