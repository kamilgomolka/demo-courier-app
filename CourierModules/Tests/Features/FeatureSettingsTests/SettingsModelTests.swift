import Domain
import DomainTestSupport
import Foundation
import Testing

@testable import FeatureSettings

struct SettingsModelTests {
    private let conditionsStore = FakeNetworkConditionsStore()
    private let jobRepository = FakeSyncJobRepository()
    private let syncController = FakeSyncController()

    private func makeModel() -> SettingsModel {
        SettingsModel(
            conditionsStore: conditionsStore,
            jobRepository: jobRepository,
            syncController: syncController
        )
    }

    @Test func startsWithPersistedConditions() {
        let persisted = NetworkConditions(isOffline: true, latencyRange: 2...4, simulatedFailure: .timeout)
        conditionsStore.save(persisted)

        #expect(makeModel().conditions == persisted)
    }

    @Test func goingOfflineIsPersistedWithoutTriggeringSync() async {
        let model = makeModel()

        await model.setOffline(true)

        #expect(model.conditions.isOffline)
        #expect(conditionsStore.load().isOffline)
        #expect(syncController.triggers.isEmpty)
    }

    @Test func returningOnlineRequestsConnectivityRestoredSync() async {
        let model = makeModel()
        await model.setOffline(true)

        await model.setOffline(false)

        #expect(!conditionsStore.load().isOffline)
        #expect(syncController.triggers == [.connectivityRestored])
    }

    @Test func settingOnlineWhileOnlineDoesNotTriggerSync() async {
        let model = makeModel()

        await model.setOffline(false)

        #expect(syncController.triggers.isEmpty)
    }

    @Test func raisingLowerBoundAboveUpperBoundPushesUpperBound() {
        let model = makeModel()

        model.setLatencyLowerBound(5)

        #expect(model.conditions.latencyRange == 5...5)
        #expect(conditionsStore.load().latencyRange == 5...5)
    }

    @Test func loweringUpperBoundBelowLowerBoundPullsLowerBound() {
        let model = makeModel()

        model.setLatencyUpperBound(0.5)

        #expect(model.conditions.latencyRange == 0.5...0.5)
    }

    @Test func latencyIsClampedToBounds() {
        let model = makeModel()

        model.setLatencyUpperBound(100)
        model.setLatencyLowerBound(-3)

        #expect(model.conditions.latencyRange == 0...10)
    }

    @Test func simulatedFailureIsPersisted() {
        let model = makeModel()

        model.setSimulatedFailure(.tooManyRequests)

        #expect(conditionsStore.load().simulatedFailure == .tooManyRequests)
    }

    @Test func syncNowRequestsManualSync() async {
        await makeModel().syncNow()

        #expect(syncController.triggers == [.manual])
    }

    @Test func syncNowReloadsConditionsChangedBySessionRefresh() async {
        conditionsStore.save(NetworkConditions(simulatedFailure: .unauthorized))
        let model = makeModel()
        conditionsStore.save(NetworkConditions())

        await model.syncNow()

        #expect(model.conditions.simulatedFailure == .none)
    }

    @Test func editingConditionsDoesNotRestoreExternallyClearedFailure() {
        conditionsStore.save(NetworkConditions(latencyRange: 1...2, simulatedFailure: .unauthorized))
        let model = makeModel()
        conditionsStore.save(NetworkConditions(latencyRange: 1...2))

        model.setLatencyUpperBound(3)

        #expect(model.conditions == NetworkConditions(latencyRange: 1...3))
        #expect(conditionsStore.load() == NetworkConditions(latencyRange: 1...3))
    }

    @Test func resetDelegatesToSyncController() async {
        let model = makeModel()

        await model.resetLocalData()

        #expect(syncController.resetCallCount == 1)
        #expect(model.resetFailure == nil)
        #expect(!model.isResetting)
    }

    @Test func resetFailureIsExposedAndDismissable() async {
        let model = makeModel()
        syncController.resetFailure = .storageFailure("disk")

        await model.resetLocalData()
        #expect(model.resetFailure == .storageFailure("disk"))

        model.dismissResetFailure()
        #expect(model.resetFailure == nil)
    }

    @Test func exposesObservedJobsAndStopsWhenCancelled() async {
        let model = makeModel()
        let job = SyncJob(
            kind: .reorder(orderedTaskIDs: ["a", "b"]),
            createdAt: Date(timeIntervalSince1970: 0),
            notBefore: Date(timeIntervalSince1970: 5),
            attemptCount: 2,
            lastFailure: "Offline"
        )
        jobRepository.add(job)
        let run = Task { await model.run() }

        #expect(await eventually { model.jobs == [job] })
        run.cancel()
        #expect(await eventually { jobRepository.jobs.activeObserverCount == 0 })
    }
}
