public import Domain
public import Foundation
import Synchronization

public final class FakeSyncJobRepository: SyncJobRepository, LocalDataResetting {
    public let jobs = StreamBroadcaster<[SyncJob]>([])

    private struct State {
        var mergedSnapshots: [RemoteSnapshot] = []
        var resetCount = 0
    }

    private let state = Mutex(State())

    public init() {}

    public var mergedSnapshots: [RemoteSnapshot] {
        state.withLock { $0.mergedSnapshots }
    }

    public var resetCount: Int {
        state.withLock { $0.resetCount }
    }

    public func add(_ job: SyncJob) {
        jobs.update { $0.append(job) }
    }

    public func replace(_ job: SyncJob) {
        jobs.update { jobs in
            if let index = jobs.firstIndex(where: { $0.id == job.id }) {
                jobs[index] = job
            }
        }
    }

    public func remove(jobID: UUID) {
        jobs.update { $0.removeAll { $0.id == jobID } }
    }

    public func observeJobs() -> AsyncStream<[SyncJob]> {
        jobs.stream()
    }

    public func eligibleJobs(at date: Date) async throws(RepositoryError) -> [SyncJob] {
        jobs.current.filter { $0.notBefore <= date }.sorted { $0.createdAt < $1.createdAt }
    }

    public func markSynced(jobID: UUID) async throws(RepositoryError) {
        remove(jobID: jobID)
    }

    public func resolveConflict(jobID: UUID, serverSnapshot: RemoteSnapshot) async throws(RepositoryError) {
        state.withLock { $0.mergedSnapshots.append(serverSnapshot) }
        remove(jobID: jobID)
    }

    public func recordFailure(jobID: UUID, failure: String) async throws(RepositoryError) {
        jobs.update { jobs in
            guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
            jobs[index].attemptCount += 1
            jobs[index].lastFailure = failure
        }
    }

    public func mergeRemoteSnapshot(_ snapshot: RemoteSnapshot) async throws(RepositoryError) {
        state.withLock { $0.mergedSnapshots.append(snapshot) }
    }

    public func resetAllData() async throws(RepositoryError) {
        state.withLock { $0.resetCount += 1 }
        jobs.send([])
    }
}
