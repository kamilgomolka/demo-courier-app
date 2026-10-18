import Domain
import Observation

@Observable
final class ShiftCardViewModel {
    enum Phase: Equatable {
        case loading
        case failed
        case ready
    }

    private(set) var phase: Phase = .loading
    private(set) var summary: ShiftSummary?
    private(set) var isShiftActive = false
    private(set) var actionFailure: RepositoryError?
    private(set) var isPerformingAction = false

    @ObservationIgnored private let shiftRepository: any ShiftRepository
    @ObservationIgnored private let syncController: any SyncControlling

    init(shiftRepository: any ShiftRepository, syncController: any SyncControlling) {
        self.shiftRepository = shiftRepository
        self.syncController = syncController
    }

    func run() async {
        for await updatedSummary in shiftRepository.observeShiftSummary() {
            guard let updatedSummary else {
                await loadInitialData()
                continue
            }
            apply(updatedSummary)
        }
    }

    func retry() async {
        await loadInitialData()
    }

    func startShift() async {
        await perform { () async throws(RepositoryError) in try await self.shiftRepository.startShift() }
    }

    func endShift() async {
        await perform { () async throws(RepositoryError) in try await self.shiftRepository.endShift() }
    }

    func reopenShift() async {
        await perform { () async throws(RepositoryError) in try await self.shiftRepository.reopenShift() }
    }

    func dismissActionFailure() {
        actionFailure = nil
    }

    private func perform(_ action: () async throws(RepositoryError) -> Void) async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            try await action()
        } catch {
            actionFailure = error
        }
    }

    private func apply(_ updatedSummary: ShiftSummary) {
        if summary != updatedSummary {
            summary = updatedSummary
        }
        let updatedIsShiftActive = updatedSummary.status == .active
        if isShiftActive != updatedIsShiftActive {
            isShiftActive = updatedIsShiftActive
        }
        if phase != .ready {
            phase = .ready
        }
    }

    private func loadInitialData() async {
        if phase != .loading {
            phase = .loading
        }
        while !Task.isCancelled {
            do {
                try await syncController.loadInitialData()
                return
            } catch .cancelled {
                continue
            } catch {
                phase = .failed
                return
            }
        }
    }
}

#if DEBUG
    import DomainTestSupport

    extension ShiftCardViewModel {
        convenience init(previewSummary: ShiftSummary) {
            let repository = FakeShiftRepository()
            repository.summary.send(previewSummary)
            self.init(shiftRepository: repository, syncController: FakeSyncController())
            apply(previewSummary)
        }
    }
#endif
