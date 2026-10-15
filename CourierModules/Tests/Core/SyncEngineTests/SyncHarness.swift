import Domain
import DomainTestSupport
import Foundation
import SyncEngine

@testable import LocalStorage

struct FakeSyncHarness {
    let repository = FakeSyncJobRepository()
    let conditions = FakeNetworkConditionsStore()
    let timeSource = ManualTimeSource()
    let api: MockCourierAPI
    let syncActor: SyncActor

    init(latency: TimeInterval = 0) {
        api = MockCourierAPI(conditionsStore: conditions, timeSource: timeSource, latency: { _ in latency })
        syncActor = SyncActor(
            jobRepository: repository,
            localDataResetter: repository,
            api: api,
            sessionRefresher: MockSessionRefresher(conditionsStore: conditions),
            timeSource: timeSource
        )
    }

    func start() async {
        await syncActor.start()
        _ = await eventually { repository.jobs.activeObserverCount == 1 }
    }

    func makeJob(
        taskID: TaskID = "task-1",
        status: TaskStatus = .inTransit,
        createdOffset: TimeInterval = 0,
        notBeforeOffset: TimeInterval = 0
    ) -> SyncJob {
        let now = timeSource.now()
        return SyncJob(
            kind: .updateStatus(taskID: taskID, status: status, exceptionReason: nil),
            createdAt: now.addingTimeInterval(createdOffset),
            notBefore: now.addingTimeInterval(notBeforeOffset)
        )
    }
}

struct StoreBackedHarness {
    let store: LocalStore
    let conditions = FakeNetworkConditionsStore()
    let timeSource: ManualTimeSource
    let api: MockCourierAPI
    let syncActor: SyncActor

    init(store: LocalStore, timeSource: ManualTimeSource, latency: TimeInterval = 0) {
        self.store = store
        self.timeSource = timeSource
        api = MockCourierAPI(conditionsStore: conditions, timeSource: timeSource, latency: { _ in latency })
        syncActor = SyncActor(
            jobRepository: store, localDataResetter: store,
            api: api,
            sessionRefresher: MockSessionRefresher(conditionsStore: conditions),
            timeSource: timeSource
        )
    }

    static func inMemory(latency: TimeInterval = 0, shiftStarted: Bool = true) async throws -> StoreBackedHarness {
        let timeSource = ManualTimeSource()
        let container = try CourierStorage.makeContainer(isStoredInMemoryOnly: true)
        let harness = StoreBackedHarness(
            store: LocalStore(modelContainer: container, timeSource: timeSource),
            timeSource: timeSource,
            latency: latency
        )
        try await harness.store.mergeRemoteSnapshot(sampleSnapshot())
        if shiftStarted {
            try await harness.store.startShift()
        }
        return harness
    }

    func start() async {
        await syncActor.start()
        _ = await eventually { await store.activeObserverCount >= 1 }
    }

    func pendingJobs() async -> [SyncJob] {
        var iterator = store.observeJobs().makeAsyncIterator()
        return await iterator.next() ?? []
    }
}

func sampleSnapshot(taskCount: Int = 4) -> RemoteSnapshot {
    RemoteSnapshot(
        shift: Shift(id: "shift-1", status: .scheduled),
        tasks: (1...taskCount).map {
            DeliveryTask(
                id: "task-\($0)",
                recipientName: "Recipient \($0)",
                deliveryAddress: "Address \($0)",
                packageSummary: "Package \($0)",
                payout: 10,
                sortOrder: $0,
                shiftID: "shift-1",
                assignedAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
        }
    )
}
