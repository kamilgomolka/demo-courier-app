import Domain
import DomainTestSupport
import Foundation
import Testing

@testable import LocalStorage

struct TaskTransitionTests {
    @Test func finishedShiftCanReopenWithoutChangingCompletedTasks() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.markDelivered(id: "task-1")
        try await fixture.store.endShift()

        try await fixture.store.reopenShift()

        #expect(try await fixture.shiftSummary().status == .active)
        #expect(try await fixture.task("task-1").status == .delivered)
        #expect(try await fixture.jobs().count == 2)
    }

    @Test func shiftCannotReopenBeforeItEnds() async throws {
        let fixture = try await StoreFixture.make()

        await #expect(throws: RepositoryError.invalidShiftTransition) {
            try await fixture.store.reopenShift()
        }
    }

    @Test func startDeliveryChangesStatusAndCreatesJobInOneTransaction() async throws {
        let fixture = try await StoreFixture.make()

        try await fixture.store.startDelivery(id: "task-1")

        let task = try await fixture.task("task-1")
        let jobs = try await fixture.jobs()
        #expect(task.status == .inTransit)
        #expect(task.syncState == .pending)
        #expect(jobs.count == 1)
        #expect(jobs.first?.kind == .updateStatus(taskID: "task-1", status: .inTransit, exceptionReason: nil))
        #expect(jobs.first?.notBefore == fixture.timeSource.now())
    }

    @Test func secondTaskInTransitIsRejected() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")

        await #expect(throws: RepositoryError.anotherTaskInTransit) {
            try await fixture.store.startDelivery(id: "task-2")
        }

        let task = try await fixture.task("task-2")
        #expect(task.status == .new)
        #expect(try await fixture.jobs().count == 1)
    }

    @Test func startDeliveryRequiresActiveShift() async throws {
        let fixture = try await StoreFixture.make(startedShift: false)

        await #expect(throws: RepositoryError.shiftNotActive) {
            try await fixture.store.startDelivery(id: "task-1")
        }

        #expect(try await fixture.jobs().isEmpty)
    }

    @Test func startDeliveryRequiresTaskFromActiveShift() async throws {
        var snapshot = StoreFixture.snapshot()
        snapshot.tasks.append(.fixture(id: "foreign", sortOrder: 99, shiftID: "other-shift"))
        let fixture = try await StoreFixture.make(snapshot: snapshot)

        await #expect(throws: RepositoryError.taskNotInActiveShift) {
            try await fixture.store.startDelivery(id: "foreign")
        }
    }

    @Test func unknownTaskIsReported() async throws {
        let fixture = try await StoreFixture.make()

        await #expect(throws: RepositoryError.taskNotFound) {
            try await fixture.store.startDelivery(id: "missing")
        }
    }

    @Test func startingAnAlreadyStartedTaskIsInvalid() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")

        await #expect(throws: RepositoryError.invalidTransition) {
            try await fixture.store.startDelivery(id: "task-1")
        }
    }

    @Test func markDeliveredHoldsJobForUndoWindow() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")

        try await fixture.store.markDelivered(id: "task-1")

        let task = try await fixture.task("task-1")
        let deliveredJob = try #require(try await fixture.jobs().last)
        #expect(task.status == .delivered)
        #expect(task.completedAt == fixture.timeSource.now())
        #expect(deliveredJob.kind == .updateStatus(taskID: "task-1", status: .delivered, exceptionReason: nil))
        #expect(deliveredJob.notBefore == fixture.timeSource.now().addingTimeInterval(SyncPolicy.undoWindow))
    }

    @Test func undoWithinWindowRestoresTaskAndRemovesJob() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.markDelivered(id: "task-1")
        fixture.timeSource.advance(by: 2)

        try await fixture.store.undoDelivery(id: "task-1")

        let task = try await fixture.task("task-1")
        #expect(task.status == .inTransit)
        #expect(task.completedAt == nil)
        #expect(try await fixture.jobs().count == 1)
    }

    @Test func undoAfterWindowExpiryIsRejected() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.markDelivered(id: "task-1")
        fixture.timeSource.advance(by: SyncPolicy.undoWindow + 0.1)

        await #expect(throws: RepositoryError.undoWindowClosed) {
            try await fixture.store.undoDelivery(id: "task-1")
        }

        #expect(try await fixture.task("task-1").status == .delivered)
    }

    @Test func undoAfterCommitIsRejected() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.markDelivered(id: "task-1")
        try await fixture.store.commitDelivery(id: "task-1")

        await #expect(throws: RepositoryError.undoWindowClosed) {
            try await fixture.store.undoDelivery(id: "task-1")
        }
    }

    @Test func undoIsRejectedWhenAnotherTaskWasStartedMeanwhile() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.markDelivered(id: "task-1")
        try await fixture.store.startDelivery(id: "task-2")

        await #expect(throws: RepositoryError.anotherTaskInTransit) {
            try await fixture.store.undoDelivery(id: "task-1")
        }

        #expect(try await fixture.task("task-1").status == .delivered)
    }

    @Test func undoIsRejectedAfterShiftEnds() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.markDelivered(id: "task-1")
        try await fixture.store.endShift()

        await #expect(throws: RepositoryError.shiftNotActive) {
            try await fixture.store.undoDelivery(id: "task-1")
        }

        #expect(try await fixture.task("task-1").status == .delivered)
    }

    @Test func commitMakesJobEligibleImmediately() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.markDelivered(id: "task-1")

        try await fixture.store.commitDelivery(id: "task-1")

        let eligible = try await fixture.store.eligibleJobs(at: fixture.timeSource.now())
        #expect(
            eligible.contains { $0.kind == .updateStatus(taskID: "task-1", status: .delivered, exceptionReason: nil) })
    }

    @Test func commitIsNoOpOutsideUndoWindow() async throws {
        let fixture = try await StoreFixture.make()
        let jobsBefore = try await fixture.jobs()

        try await fixture.store.commitDelivery(id: "task-1")
        try await fixture.store.commitDelivery(id: "missing")
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.commitDelivery(id: "task-1")

        #expect(try await fixture.jobs().count == jobsBefore.count + 1)
        #expect(try await fixture.task("task-1").status == .inTransit)
    }

    @Test func commitTwiceIsIdempotent() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.markDelivered(id: "task-1")

        try await fixture.store.commitDelivery(id: "task-1")
        let jobsAfterFirstCommit = try await fixture.jobs()
        try await fixture.store.commitDelivery(id: "task-1")

        #expect(try await fixture.jobs() == jobsAfterFirstCommit)
    }

    @Test func exceptionBypassesUndoWindowAndCarriesReason() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")

        try await fixture.store.reportException(id: "task-1", reason: .other(details: "  Gate locked \n"))

        let task = try await fixture.task("task-1")
        let job = try #require(try await fixture.jobs().last)
        #expect(task.status == .exception)
        #expect(task.exceptionReason == .other(details: "Gate locked"))
        #expect(job.notBefore == fixture.timeSource.now())
        #expect(
            job.kind
                == .updateStatus(taskID: "task-1", status: .exception, exceptionReason: .other(details: "Gate locked")))
    }

    @Test func exceptionOtherWithoutDetailsIsRejectedAtomically() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")

        await #expect(throws: RepositoryError.exceptionDetailsRequired) {
            try await fixture.store.reportException(id: "task-1", reason: .other(details: "   "))
        }

        #expect(try await fixture.task("task-1").status == .inTransit)
        #expect(try await fixture.jobs().count == 1)
    }

    @Test func syncStateBecomesSyncedAfterJobIsAcknowledged() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        let job = try #require(try await fixture.jobs().first)

        try await fixture.store.markSynced(jobID: job.id)

        #expect(try await fixture.task("task-1").syncState == .synced)
        #expect(try await fixture.jobs().isEmpty)
    }

    @Test func markSyncedForUnknownJobIsNoOp() async throws {
        let fixture = try await StoreFixture.make()

        try await fixture.store.markSynced(jobID: UUID())
    }

    @Test func resolvingStatusConflictAppliesServerWinnerAndRemovesJob() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        let job = try #require(try await fixture.jobs().first)

        try await fixture.store.resolveConflict(jobID: job.id, serverSnapshot: StoreFixture.snapshot())

        #expect(try await fixture.task("task-1").status == .new)
        #expect(try await fixture.task("task-1").syncState == .synced)
        #expect(try await fixture.jobs().isEmpty)
    }

    @Test func resolvingStatusConflictCannotCreateASecondTaskInTransit() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        let startJob = try #require(try await fixture.jobs().first)
        try await fixture.store.markSynced(jobID: startJob.id)
        fixture.timeSource.advance(by: 1)
        try await fixture.store.markDelivered(id: "task-1")
        let deliveredJob = try #require(try await fixture.jobs().first)
        fixture.timeSource.advance(by: 1)
        try await fixture.store.startDelivery(id: "task-2")
        let jobsBeforeConflict = try await fixture.jobs()
        var snapshot = StoreFixture.snapshot()
        snapshot.tasks[0].status = .inTransit

        await #expect(throws: RepositoryError.anotherTaskInTransit) {
            try await fixture.store.resolveConflict(jobID: deliveredJob.id, serverSnapshot: snapshot)
        }

        #expect(try await fixture.task("task-1").status == .delivered)
        #expect(try await fixture.task("task-2").status == .inTransit)
        #expect(try await fixture.jobs() == jobsBeforeConflict)
    }

    @Test func resolvingStatusConflictRequiresActiveShiftForInTransit() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        let startJob = try #require(try await fixture.jobs().first)
        try await fixture.store.markSynced(jobID: startJob.id)
        try await fixture.store.markDelivered(id: "task-1")
        let deliveredJob = try #require(try await fixture.jobs().first)
        try await fixture.store.endShift()
        var snapshot = StoreFixture.snapshot()
        snapshot.tasks[0].status = .inTransit

        await #expect(throws: RepositoryError.shiftNotActive) {
            try await fixture.store.resolveConflict(jobID: deliveredJob.id, serverSnapshot: snapshot)
        }

        #expect(try await fixture.task("task-1").status == .delivered)
        #expect(try await fixture.jobs() == [deliveredJob])
    }

    @Test func resolvingReorderConflictAppliesServerOrderAndRemovesJob() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.reorderQueue(orderedTaskIDs: ["task-2", "task-1", "task-3", "task-4", "task-5"])
        let job = try #require(try await fixture.jobs().first)

        try await fixture.store.resolveConflict(jobID: job.id, serverSnapshot: StoreFixture.snapshot())

        #expect(try await fixture.queueIDs() == ["task-1", "task-2", "task-3", "task-4", "task-5"])
        #expect(try await fixture.jobs().isEmpty)
    }

    @Test func resolvingConflictPreservesNewerPendingLocalWrite() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.markDelivered(id: "task-1")
        let firstJob = try #require(try await fixture.jobs().first)

        try await fixture.store.resolveConflict(jobID: firstJob.id, serverSnapshot: StoreFixture.snapshot())

        #expect(try await fixture.task("task-1").status == .delivered)
        #expect(try await fixture.task("task-1").syncState == .pending)
        #expect(try await fixture.jobs().count == 1)
    }

    @Test func recordFailureStoresDiagnosticsWithoutChangingTaskState() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        let job = try #require(try await fixture.jobs().first)

        try await fixture.store.recordFailure(jobID: job.id, failure: "Server error 500")

        let updated = try #require(try await fixture.jobs().first)
        #expect(updated.attemptCount == 1)
        #expect(updated.lastFailure == "Server error 500")
        #expect(try await fixture.task("task-1").syncState == .pending)
    }

    @Test func undecodableJobIsSkippedWithoutBreakingQueries() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.insertUndecodableJob()

        #expect(try await fixture.jobs().count == 1)
        #expect(try await fixture.task("task-1").syncState == .pending)
        #expect(try await fixture.store.eligibleJobs(at: fixture.timeSource.now()).count == 1)
    }

    @Test func eligibleJobsAreOrderedByCreationAndFilteredByNotBefore() async throws {
        let fixture = try await StoreFixture.make()
        try await fixture.store.startDelivery(id: "task-1")
        try await fixture.store.markDelivered(id: "task-1")
        try await fixture.store.startDelivery(id: "task-2")

        let eligibleNow = try await fixture.store.eligibleJobs(at: fixture.timeSource.now())
        let eligibleLater = try await fixture.store.eligibleJobs(at: fixture.timeSource.now().addingTimeInterval(10))

        #expect(eligibleNow.count == 2)
        #expect(eligibleLater.count == 3)
        #expect(eligibleLater.map(\.createdAt) == eligibleLater.map(\.createdAt).sorted())
    }
}
