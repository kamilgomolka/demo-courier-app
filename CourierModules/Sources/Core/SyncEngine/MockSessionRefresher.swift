public import Domain

public struct MockSessionRefresher: SessionRefreshing {
    private let conditionsStore: any NetworkConditionsStore

    public init(conditionsStore: any NetworkConditionsStore) {
        self.conditionsStore = conditionsStore
    }

    public func refresh() async throws(SyncError) {
        var conditions = conditionsStore.load()
        guard !conditions.isOffline else { throw .offline }
        guard conditions.simulatedFailure == .unauthorized else { return }
        conditions.simulatedFailure = .none
        conditionsStore.save(conditions)
    }
}
