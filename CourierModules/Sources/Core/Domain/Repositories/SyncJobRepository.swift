public import Foundation

public protocol SyncJobRepository: Sendable {
    func observeJobs() -> AsyncStream<[SyncJob]>
    func eligibleJobs(at date: Date) async throws(RepositoryError) -> [SyncJob]
    func markSynced(jobID: UUID) async throws(RepositoryError)
    func resolveConflict(jobID: UUID, serverSnapshot: RemoteSnapshot) async throws(RepositoryError)
    func recordFailure(jobID: UUID, failure: String) async throws(RepositoryError)
    func mergeRemoteSnapshot(_ snapshot: RemoteSnapshot) async throws(RepositoryError)
}
