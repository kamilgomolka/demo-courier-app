import Domain
import DomainTestSupport
import Foundation
import Testing

@testable import SyncEngine

struct SyncSchedulingTests {
    @Test func noRequestBeforeNotBeforeAndExactlyOneAfter() async throws {
        let harness = FakeSyncHarness()
        harness.repository.add(harness.makeJob(notBeforeOffset: 5))
        await harness.start()
        #expect(await eventually { harness.timeSource.pendingSleeperCount == 1 })

        harness.timeSource.advance(by: 4.9)
        try await Task.sleep(for: .milliseconds(50))
        #expect(harness.api.requests.isEmpty)

        harness.timeSource.advance(by: 0.2)
        #expect(await eventually { harness.api.requests.count == 1 })
        #expect(await eventually { harness.repository.jobs.current.isEmpty })
        try await Task.sleep(for: .milliseconds(50))
        #expect(harness.api.requests.count == 1)
    }

    @Test func removingHeldJobCancelsTheWakeUp() async throws {
        let harness = FakeSyncHarness()
        let job = harness.makeJob(notBeforeOffset: 5)
        harness.repository.add(job)
        await harness.start()
        #expect(await eventually { harness.timeSource.pendingSleeperCount == 1 })

        harness.repository.remove(jobID: job.id)

        #expect(await eventually { harness.timeSource.pendingSleeperCount == 0 })
        harness.timeSource.advance(by: 10)
        try await Task.sleep(for: .milliseconds(50))
        #expect(harness.api.requests.isEmpty)
    }

    @Test func replacingJobMovesTheDeadline() async throws {
        let harness = FakeSyncHarness()
        let original = harness.makeJob(notBeforeOffset: 5)
        harness.repository.add(original)
        await harness.start()
        #expect(await eventually { harness.timeSource.pendingSleeperCount == 1 })
        harness.timeSource.advance(by: 3)

        harness.repository.remove(jobID: original.id)
        harness.repository.add(harness.makeJob(notBeforeOffset: 5))
        #expect(await eventually { harness.timeSource.pendingSleeperCount == 1 })

        harness.timeSource.advance(by: 4)
        try await Task.sleep(for: .milliseconds(50))
        #expect(harness.api.requests.isEmpty)

        harness.timeSource.advance(by: 1.1)
        #expect(await eventually { harness.api.requests.count == 1 })
    }

    @Test func eligibleJobsAreSentInCreationOrderEachExactlyOnce() async throws {
        let harness = FakeSyncHarness()
        let newest = harness.makeJob(taskID: "c", createdOffset: -1)
        let oldest = harness.makeJob(taskID: "a", createdOffset: -3)
        let middle = harness.makeJob(taskID: "b", createdOffset: -2)
        [newest, oldest, middle].forEach(harness.repository.add)

        await harness.start()

        #expect(await eventually { harness.api.requests.count == 3 })
        #expect(harness.api.requests.map(\.idempotencyKey) == [oldest.id, middle.id, newest.id])
        await harness.syncActor.requestSync(.manual)
        #expect(harness.api.requests.count == 3)
    }

    @Test func idempotencyKeyIsTheJobIdentifier() async throws {
        let harness = FakeSyncHarness()
        let job = harness.makeJob(taskID: "task-9", status: .exception)
        harness.repository.add(job)

        await harness.start()

        #expect(await eventually { harness.api.requests.count == 1 })
        let request = try #require(harness.api.requests.first)
        #expect(request.method == "PATCH")
        #expect(request.path == "/tasks/task-9/status")
        #expect(request.idempotencyKey == job.id)
    }

    @Test func persistentServerErrorProducesOneAttemptPerTrigger() async throws {
        let harness = FakeSyncHarness()
        harness.conditions.save(NetworkConditions(latencyRange: 0...0, simulatedFailure: .serverError))
        harness.repository.add(harness.makeJob())
        await harness.start()
        #expect(await eventually { harness.api.requests.count == 1 })
        try await Task.sleep(for: .milliseconds(100))
        #expect(harness.api.requests.count == 1)
        #expect(harness.repository.jobs.current.first?.attemptCount == 1)
        #expect(harness.repository.jobs.current.first?.lastFailure == "Server error 500")

        await harness.syncActor.requestSync(.manual)

        #expect(harness.api.requests.count == 2)
        #expect(harness.repository.jobs.current.first?.attemptCount == 2)
        try await Task.sleep(for: .milliseconds(100))
        #expect(harness.api.requests.count == 2)
    }

    @Test func failedJobsAreNotRetriedByUnrelatedQueueChanges() async throws {
        let harness = FakeSyncHarness()
        harness.conditions.save(NetworkConditions(latencyRange: 0...0, simulatedFailure: .serverError))
        harness.repository.add(harness.makeJob(taskID: "failing"))
        await harness.start()
        #expect(await eventually { harness.api.requests.count == 1 })

        #expect(await eventually { harness.repository.jobs.current.first?.attemptCount == 1 })
        harness.repository.add(harness.makeJob(taskID: "held", notBeforeOffset: 60))
        try await Task.sleep(for: .milliseconds(100))

        #expect(harness.api.requests.count == 1)
    }

    @Test func failedJobDoesNotBlockOtherTasksButBlocksItsOwnTask() async throws {
        let harness = FakeSyncHarness()
        harness.conditions.save(NetworkConditions(latencyRange: 0...0, simulatedFailure: .serverError))
        harness.repository.add(harness.makeJob(taskID: "a", createdOffset: -3))
        await harness.start()
        #expect(await eventually { harness.repository.jobs.current.first?.attemptCount == 1 })

        harness.conditions.save(NetworkConditions(latencyRange: 0...0))
        harness.repository.add(harness.makeJob(taskID: "b", createdOffset: -2))
        harness.repository.add(harness.makeJob(taskID: "a", status: .delivered, createdOffset: -1))

        #expect(await eventually { harness.repository.jobs.current.count == 2 })
        try await Task.sleep(for: .milliseconds(100))
        #expect(harness.api.requests.map(\.path) == ["/tasks/a/status", "/tasks/b/status"])
        #expect(harness.repository.jobs.current.allSatisfy { $0.kind.taskID == "a" })

        await harness.syncActor.requestSync(.manual)

        #expect(harness.repository.jobs.current.isEmpty)
        #expect(harness.api.requests.map(\.path).suffix(2) == ["/tasks/a/status", "/tasks/a/status"])
    }

    @Test func offlineStopsTheCycleAndKeepsJobsUntouched() async throws {
        let harness = FakeSyncHarness()
        harness.conditions.save(NetworkConditions(isOffline: true))
        harness.repository.add(harness.makeJob(taskID: "a", createdOffset: -2))
        harness.repository.add(harness.makeJob(taskID: "b", createdOffset: -1))
        await harness.start()
        await harness.syncActor.requestSync(.manual)

        #expect(harness.api.requests.isEmpty)
        #expect(harness.repository.jobs.current.count == 2)
        #expect(harness.repository.jobs.current.allSatisfy { $0.attemptCount == 0 })

        harness.conditions.save(NetworkConditions())
        await harness.syncActor.requestSync(.connectivityRestored)

        #expect(harness.api.requests.count == 2)
        #expect(harness.repository.jobs.current.isEmpty)
    }

    @Test func cancelledRequestDoesNotRecordAFailure() async throws {
        let harness = FakeSyncHarness(latency: 1)
        harness.repository.add(harness.makeJob())
        await harness.start()
        #expect(await eventually { harness.timeSource.pendingSleeperCount == 1 })

        let reset = Task { try await harness.syncActor.resetLocalData() }
        #expect(await eventually { harness.repository.resetCount == 1 })
        #expect(await eventually { harness.timeSource.pendingSleeperCount == 1 })
        try await Task.sleep(for: .milliseconds(50))
        harness.timeSource.advance(by: 1)
        try await reset.value

        #expect(harness.api.requests.filter { $0.method == "PATCH" }.isEmpty)
        #expect(harness.repository.resetCount == 1)
    }

    @Test func concurrentTriggersAreCoalescedIntoSequentialCycles() async throws {
        let harness = FakeSyncHarness(latency: 1)
        harness.repository.add(harness.makeJob())
        await harness.start()
        #expect(await eventually { harness.timeSource.pendingSleeperCount == 1 })

        async let first: Void = harness.syncActor.requestSync(.manual)
        async let second: Void = harness.syncActor.requestSync(.foreground)
        harness.timeSource.advance(by: 1)
        _ = await (first, second)

        #expect(harness.api.requests.count == 1)
        #expect(harness.repository.jobs.current.isEmpty)
    }
}
