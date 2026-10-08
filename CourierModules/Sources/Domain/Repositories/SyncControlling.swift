public protocol SyncControlling: Sendable {
    func requestSync(_ trigger: SyncTrigger) async
    func loadInitialData() async throws(SyncError)
    func resetLocalData() async throws(RepositoryError)
}
