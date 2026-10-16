import Domain
import DomainTestSupport
import Foundation
import LocalStorage
import Synchronization
import Testing

@testable import SyncEngine

struct SyncRecoveryTests {
    private final class NewerServerAPI: CourierAPI {
        let sendCount = Mutex(0)
        let snapshot: RemoteSnapshot

        init(snapshot: RemoteSnapshot = .fixture()) {
            self.snapshot = snapshot
        }

        func fetchSnapshot() async throws(SyncError) -> RemoteSnapshot {
            snapshot
        }

        func send(_ job: SyncJob) async throws(SyncError) {
            sendCount.withLock { $0 += 1 }
            throw .conflict(serverUpdatedAt: job.createdAt.addingTimeInterval(1))
        }
    }

    @Test func rejectedServerWinnerKeepsTheJobWithFailureDiagnostics() async throws {
        let harness = try await StoreBackedHarness.inMemory()
        try await harness.store.startDelivery(id: "task-1")
        let startJob = try #require(await harness.pendingJobs().first)
        try await harness.store.markSynced(jobID: startJob.id)
        harness.timeSource.advance(by: 1)
        try await harness.store.markDelivered(id: "task-1")
        let deliveredJob = try #require(await harness.pendingJobs().first)
        harness.timeSource.advance(by: SyncPolicy.undoWindow)
        try await harness.store.startDelivery(id: "task-2")
        var snapshot = sampleSnapshot()
        snapshot.tasks[0].status = .inTransit
        let api = NewerServerAPI(snapshot: snapshot)
        let syncActor = SyncActor(
            jobRepository: harness.store, localDataResetter: harness.store, api: api,
            sessionRefresher: MockSessionRefresher(conditionsStore: harness.conditions), timeSource: harness.timeSource
        )

        await syncActor.requestSync(.manual)

        let retainedJob = try #require(await harness.pendingJobs().first { $0.id == deliveredJob.id })
        #expect(retainedJob.attemptCount == 1)
        #expect(retainedJob.lastFailure == "anotherTaskInTransit")
        #expect(api.sendCount.withLock { $0 } == 1)
    }

    @Test func unauthorizedRefreshesSessionAndRetriesWithoutCountingAnAttempt() async throws {
        let harness = FakeSyncHarness()
        harness.conditions.save(NetworkConditions(latencyRange: 0...0, simulatedFailure: .unauthorized))
        harness.repository.add(harness.makeJob())

        await harness.start()

        #expect(await eventually { harness.repository.jobs.current.isEmpty })
        #expect(harness.api.requests.count == 2)
        #expect(harness.conditions.load().simulatedFailure == .none)
    }

    @Test func unauthorizedInitialLoadRefreshesSessionAndRetries() async throws {
        let harness = FakeSyncHarness()
        harness.conditions.save(NetworkConditions(latencyRange: 0...0, simulatedFailure: .unauthorized))

        try await harness.syncActor.loadInitialData()

        #expect(harness.api.requests.count == 2)
        #expect(harness.conditions.load().simulatedFailure == .none)
        #expect(harness.repository.mergedSnapshots.count == 1)
    }

    @Test func unauthorizedAfterRefreshRecordsFailure() async throws {
        let harness = FakeSyncHarness()
        harness.conditions.save(NetworkConditions(latencyRange: 0...0, simulatedFailure: .unauthorized))
        let sessionRefresher = MockSessionRefresher(conditionsStore: FakeNetworkConditionsStore())
        let actor = SyncActor(
            jobRepository: harness.repository,
            localDataResetter: harness.repository,
            api: harness.api,
            sessionRefresher: sessionRefresher,
            timeSource: harness.timeSource
        )
        harness.repository.add(harness.makeJob())

        await actor.start()

        #expect(await eventually { harness.repository.jobs.current.first?.attemptCount == 1 })
        #expect(harness.repository.jobs.current.first?.lastFailure == "Unauthorized (401)")
        await actor.stop()
    }

    @Test func conflictWithOlderServerVersionResendsLocalWrite() async throws {
        let harness = FakeSyncHarness()
        harness.conditions.save(NetworkConditions(latencyRange: 0...0, simulatedFailure: .conflict))
        harness.repository.add(harness.makeJob())

        await harness.start()

        #expect(await eventually { harness.repository.jobs.current.isEmpty })
        #expect(harness.api.requests.count == 2)
    }

    @Test func conflictWithNewerServerVersionDiscardsLocalWrite() async throws {
        let harness = FakeSyncHarness()
        let api = NewerServerAPI()
        let actor = SyncActor(
            jobRepository: harness.repository,
            localDataResetter: harness.repository,
            api: api,
            sessionRefresher: MockSessionRefresher(conditionsStore: harness.conditions),
            timeSource: harness.timeSource
        )
        harness.repository.add(harness.makeJob())

        await actor.start()

        #expect(await eventually { harness.repository.jobs.current.isEmpty })
        #expect(api.sendCount.withLock { $0 } == 1)
        #expect(harness.repository.mergedSnapshots == [api.snapshot])
        await actor.stop()
    }
}
