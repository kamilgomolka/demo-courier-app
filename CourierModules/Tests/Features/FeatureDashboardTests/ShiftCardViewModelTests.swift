import Domain
import DomainTestSupport
import Testing

@testable import FeatureDashboard

struct ShiftCardViewModelTests {
    private let shiftRepository = FakeShiftRepository()
    private let syncController = FakeSyncController()

    private func makeModel() -> ShiftCardViewModel {
        ShiftCardViewModel(shiftRepository: shiftRepository, syncController: syncController)
    }

    @Test func startsInLoadingPhase() {
        #expect(makeModel().phase == .loading)
    }

    @Test func emptyDatabaseTriggersInitialLoad() async {
        let model = makeModel()
        shiftRepository.summary.send(nil)

        let run = Task { await model.run() }
        #expect(await eventually { syncController.loadCallCount == 1 })
        run.cancel()

        #expect(model.phase == .loading)
    }

    @Test func loadFailureShowsFailedPhaseAndRetryRecovers() async {
        let model = makeModel()
        syncController.loadFailure = .offline
        shiftRepository.summary.send(nil)
        let run = Task { await model.run() }
        #expect(await eventually { model.phase == .failed })

        syncController.loadFailure = nil
        await model.retry()
        shiftRepository.summary.send(.fixture(status: .scheduled))

        #expect(await eventually { model.phase == .ready })
        #expect(syncController.loadCallCount == 2)
        run.cancel()
    }

    @Test func summaryMakesModelReadyAndTracksActiveShift() async {
        let model = makeModel()
        shiftRepository.summary.send(.fixture(status: .active))
        let run = Task { await model.run() }

        #expect(await eventually { model.phase == .ready })
        #expect(model.isShiftActive)

        shiftRepository.summary.send(.fixture(status: .finished))
        #expect(await eventually { !model.isShiftActive })
        run.cancel()
    }

    @Test func shiftActionsDelegateToRepository() async {
        let model = makeModel()

        await model.startShift()
        await model.endShift()
        await model.reopenShift()

        #expect(shiftRepository.calls == [.startShift, .endShift, .reopenShift])
        #expect(model.actionFailure == nil)
    }

    @Test func repositoryFailureIsExposedUntilDismissed() async {
        let model = makeModel()
        shiftRepository.failure = .shiftHasTaskInTransit

        await model.endShift()
        #expect(model.actionFailure == .shiftHasTaskInTransit)

        model.dismissActionFailure()
        #expect(model.actionFailure == nil)
    }

    @Test func cancellingTheRunTaskEndsTheObservation() async {
        let model = makeModel()
        shiftRepository.summary.send(.fixture())
        let run = Task { await model.run() }
        #expect(await eventually { shiftRepository.summary.activeObserverCount == 1 })

        run.cancel()

        #expect(await eventually { shiftRepository.summary.activeObserverCount == 0 })
    }

    @Test func concurrentActionIsIgnoredWithoutFailure() async {
        let model = makeModel()
        shiftRepository.holdCalls()
        let first = Task { await model.startShift() }
        #expect(await eventually { shiftRepository.calls.count == 1 })
        #expect(model.isPerformingAction)

        await model.startShift()
        await model.endShift()

        #expect(shiftRepository.calls == [.startShift])
        #expect(model.actionFailure == nil)

        shiftRepository.releaseCalls()
        await first.value
        #expect(!model.isPerformingAction)
    }

    @Test func alertMessagesAreSpecificForKnownErrorsAndGenericOtherwise() {
        #expect(RepositoryError.shiftHasTaskInTransit.alertMessage == .dashboardAlertShiftHasTaskInTransit)
        #expect(RepositoryError.shiftNotActive.alertMessage == .dashboardAlertShiftNotActive)
        #expect(RepositoryError.taskNotInActiveShift.alertMessage == .dashboardAlertTaskNotInActiveShift)
        #expect(RepositoryError.storageFailure("disk").alertMessage == .dashboardAlertMessage)
    }
}
