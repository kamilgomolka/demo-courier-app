import Domain
import DomainTestSupport
import Foundation
import Synchronization
import Testing

@testable import SyncEngine

struct SyncSchedulingTests {
    @Test func replacingUnsentReorderDuringDrainDoesNotSendTheRemovedJob() async throws {
        let repository = FakeSyncJobRepository()
        let conditions = FakeNetworkConditionsStore()
        let timeSource = ManualTimeSource()
        let latencyCalls = Mutex(0)

        let api = MockCourierAPI(
            conditionsStore: conditions,
            timeSource: timeSource,
            latency: { _ in
                latencyCalls.withLock { count in
                    defer { count += 1 }
                    return count == 0 ? 1 : 0
                }
            }
        )

        let syncActor = SyncActor(
            jobRepository: repository, localDataResetter: repository, api: api,
            sessionRefresher: MockSessionRefresher(conditionsStore: conditions), timeSource: timeSource
        )
        let now = timeSource.now()
        let first = SyncJob(
            kind: .updateStatus(taskID: "a", status: .inTransit, exceptionReason: nil),
            createdAt: now.addingTimeInterval(-1), notBefore: now
        )
        let obsolete = SyncJob(kind: .reorder(orderedTaskIDs: ["b", "c"]), createdAt: now, notBefore: now)
        repository.add(first)
        repository.add(obsolete)
        let drain = Task { await syncActor.requestSync(.manual) }
        #expect(await eventually { timeSource.pendingSleeperCount == 1 })

        repository.remove(jobID: obsolete.id)
        let replacement = SyncJob(
            kind: .reorder(orderedTaskIDs: ["c", "b"]), createdAt: now,
            notBefore: now.addingTimeInterval(SyncPolicy.reorderDebounce)
        )
        repository.add(replacement)
        timeSource.advance(by: 1)
        await drain.value

        #expect(api.requests.map(\.idempotencyKey) == [first.id])
        #expect(repository.jobs.current == [replacement])
    }

    @Test func noRequestBeforeNotBeforeAndExactlyOneAfter() async throws {
        let harness = FakeSyncHarness()
        harness.repository.add(harness.makeJob(notBeforeOffset: 5))
        await harness.start()
        #expect(await eventually { harness.timeSource.pendingSleeperCount == 1 })

        harness.timeSource.advance(by: 4.9)
        #expect(harness.api.requests.isEmpty)

        harness.timeSource.advance(by: 0.2)
        #expect(await eventually { harness.api.requests.count == 1 })
        #expect(await eventually { harness.repository.jobs.current.isEmpty })
        await harness.syncActor.stop()
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
        await harness.syncActor.stop()
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
        let replacementDeadline = harness.timeSource.now().addingTimeInterval(5)
        #expect(await eventually { harness.timeSource.pendingDeadlines == [replacementDeadline] })

        harness.timeSource.advance(by: 4)
        #expect(harness.api.requests.isEmpty)

        harness.timeSource.advance(by: 1.1)
        #expect(await eventually { harness.api.requests.count == 1 })
        await harness.syncActor.stop()
    }

    @Test func replacingJobWhileWakeFiresLeavesExactlyOneSleeperAndNoneAfterStop() async throws {
        let harness = FakeSyncHarness()
        let original = harness.makeJob(taskID: "a", notBeforeOffset: 5)
        harness.repository.add(original)
        await harness.start()
        #expect(await eventually { harness.timeSource.pendingSleeperCount == 1 })

        harness.timeSource.advance(by: 5)
        harness.repository.add(harness.makeJob(taskID: "b", notBeforeOffset: 5))

        #expect(await eventually { harness.api.requests.count == 1 })
        #expect(await eventually { harness.timeSource.pendingSleeperCount == 1 })

        await harness.syncActor.stop()

        #expect(harness.timeSource.pendingSleeperCount == 0)
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
        #expect(await eventually { harness.repository.jobs.current.first?.attemptCount == 1 })
        #expect(harness.api.requests.count == 1)
        #expect(harness.repository.jobs.current.first?.attemptCount == 1)
        #expect(harness.repository.jobs.current.first?.lastFailure == "Server error 500")

        await harness.syncActor.requestSync(.manual)

        #expect(harness.api.requests.count == 2)
        #expect(harness.repository.jobs.current.first?.attemptCount == 2)
        await harness.syncActor.stop()
        #expect(harness.api.requests.count == 2)
    }

    @Test func failedJobsAreNotRetriedByQueueChangesOrWakeTimers() async throws {
        let harness = FakeSyncHarness()
        harness.conditions.save(NetworkConditions(latencyRange: 0...0, simulatedFailure: .serverError))
        harness.repository.add(harness.makeJob(taskID: "failing"))
        await harness.start()
        #expect(await eventually { harness.api.requests.count == 1 })

        #expect(await eventually { harness.repository.jobs.current.first?.attemptCount == 1 })
        harness.repository.add(harness.makeJob(taskID: "held", notBeforeOffset: 60))
        #expect(await eventually { harness.timeSource.pendingSleeperCount == 1 })

        #expect(harness.api.requests.count == 1)
        harness.conditions.save(NetworkConditions(latencyRange: 0...0))
        harness.timeSource.advance(by: 60)
        #expect(await eventually { harness.repository.jobs.current.count == 1 })
        #expect(harness.api.requests.map(\.path) == ["/tasks/failing/status", "/tasks/held/status"])
        #expect(harness.repository.jobs.current.first?.attemptCount == 1)
        await harness.syncActor.stop()
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
