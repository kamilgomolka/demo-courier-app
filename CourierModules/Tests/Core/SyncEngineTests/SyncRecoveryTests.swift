import Domain
import DomainTestSupport
import Foundation
import Synchronization
import Testing

@testable import SyncEngine

struct SyncRecoveryTests {
    private final class NewerServerAPI: CourierAPI {
        let sendCount = Mutex(0)
        let snapshot = RemoteSnapshot.fixture()

        func fetchSnapshot() async throws(SyncError) -> RemoteSnapshot {
            snapshot
        }

        func send(_ job: SyncJob) async throws(SyncError) {
            sendCount.withLock { $0 += 1 }
            throw .conflict(serverUpdatedAt: job.createdAt.addingTimeInterval(1))
        }
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
