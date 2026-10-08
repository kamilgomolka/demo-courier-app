public import Domain

public protocol CourierAPI: Sendable {
    func fetchSnapshot() async throws(SyncError) -> RemoteSnapshot
    func send(_ job: SyncJob) async throws(SyncError)
}
