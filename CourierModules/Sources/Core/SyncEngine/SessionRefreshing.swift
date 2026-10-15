public import Domain

public protocol SessionRefreshing: Sendable {
    func refresh() async throws(SyncError)
}
