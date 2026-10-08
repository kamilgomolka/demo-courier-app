public import Domain
public import Foundation
import SwiftData

extension LocalStore {
    public func eligibleJobs(at date: Date) async throws(RepositoryError) -> [SyncJob] {
        try jobsSnapshot().filter { $0.notBefore <= date }
    }

    public func markSynced(jobID: UUID) async throws(RepositoryError) {
        guard let record = try fetch(SyncJobRecord.self).first(where: { $0.id == jobID }) else { return }
        try transact { modelContext.delete(record) }
    }

    public func recordFailure(jobID: UUID, failure: String) async throws(RepositoryError) {
        guard let record = try fetch(SyncJobRecord.self).first(where: { $0.id == jobID }) else { return }
        try transact {
            record.attemptCount += 1
            record.lastFailure = failure
        }
    }

    public func mergeRemoteSnapshot(_ snapshot: RemoteSnapshot) async throws(RepositoryError) {
        try transact { () throws(RepositoryError) in
            let knownShiftIDs = Set(try fetch(ShiftRecord.self).map(\.id))
            if !knownShiftIDs.contains(snapshot.shift.id) {
                modelContext.insert(ShiftRecord(snapshot.shift))
            }
            let knownTaskIDs = Set(try fetch(DeliveryTaskRecord.self).map(\.id))
            for task in snapshot.tasks where !knownTaskIDs.contains(task.id) {
                modelContext.insert(try DeliveryTaskRecord(task))
            }
        }
    }

    public func resetAllData() async throws(RepositoryError) {
        try transact { () throws(RepositoryError) in
            do {
                try modelContext.delete(model: DeliveryTaskRecord.self)
                try modelContext.delete(model: ShiftRecord.self)
                try modelContext.delete(model: SyncJobRecord.self)
            } catch {
                throw .storageFailure(String(describing: error))
            }
        }
    }
}
