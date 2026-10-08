import Domain
import DomainTestSupport
import Testing

@testable import FeatureDashboard

struct ShiftCardModelTests {
    private let shiftRepository = FakeShiftRepository()
    private let syncController = FakeSyncController()

    private func makeModel() -> ShiftCardModel {
        ShiftCardModel(shiftRepository: shiftRepository, syncController: syncController)
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

    @Test func startAndEndShiftDelegateToRepository() async {
        let model = makeModel()

        await model.startShift()
        await model.endShift()

        #expect(shiftRepository.calls == [.startShift, .endShift])
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
}
