import Domain
import Observation

@Observable
final class SettingsModel {
    static let latencyBounds: ClosedRange<Double> = 0...10

    private(set) var conditions: NetworkConditions
    private(set) var jobs: [SyncJob] = []
    private(set) var isResetting = false
    private(set) var resetFailure: RepositoryError?

    @ObservationIgnored private let conditionsStore: any NetworkConditionsStore
    @ObservationIgnored private let jobRepository: any SyncJobRepository
    @ObservationIgnored private let syncController: any SyncControlling

    init(
        conditionsStore: any NetworkConditionsStore,
        jobRepository: any SyncJobRepository,
        syncController: any SyncControlling
    ) {
        self.conditionsStore = conditionsStore
        self.jobRepository = jobRepository
        self.syncController = syncController
        conditions = conditionsStore.load()
    }

    func run() async {
        for await updatedJobs in jobRepository.observeJobs() {
            if jobs != updatedJobs {
                jobs = updatedJobs
            }
        }
    }

    func setOffline(_ isOffline: Bool) async {
        let wasOffline = conditions.isOffline
        update { $0.isOffline = isOffline }
        if wasOffline && !isOffline {
            await syncController.requestSync(.connectivityRestored)
        }
    }

    func setLatencyLowerBound(_ seconds: Double) {
        let lowerBound = seconds.clamped(to: Self.latencyBounds)
        update { $0.latencyRange = lowerBound...max(lowerBound, $0.latencyRange.upperBound) }
    }

    func setLatencyUpperBound(_ seconds: Double) {
        let upperBound = seconds.clamped(to: Self.latencyBounds)
        update { $0.latencyRange = min(upperBound, $0.latencyRange.lowerBound)...upperBound }
    }

    func setSimulatedFailure(_ failure: SimulatedFailure) {
        update { $0.simulatedFailure = failure }
    }

    func syncNow() async {
        await syncController.requestSync(.manual)
    }

    func resetLocalData() async {
        isResetting = true
        defer { isResetting = false }
        do {
            try await syncController.resetLocalData()
        } catch {
            resetFailure = error
        }
    }

    func dismissResetFailure() {
        resetFailure = nil
    }

    private func update(_ change: (inout NetworkConditions) -> Void) {
        var updatedConditions = conditions
        change(&updatedConditions)
        guard updatedConditions != conditions else { return }
        conditions = updatedConditions
        conditionsStore.save(updatedConditions)
    }
}

extension Double {
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
