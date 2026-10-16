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

    public func resolveConflict(jobID: UUID, serverSnapshot: RemoteSnapshot) async throws(RepositoryError) {
        guard let jobRecord = try fetch(SyncJobRecord.self).first(where: { $0.id == jobID }) else { return }
        let job = try jobRecord.makeDomain()
        let hasNewerLocalWrite = try jobsSnapshot().contains { candidate in
            guard candidate.id != job.id, candidate.createdAt >= job.createdAt else { return false }
            return switch (job.kind, candidate.kind) {
            case (.updateStatus(let taskID, _, _), .updateStatus(let candidateTaskID, _, _)):
                taskID == candidateTaskID
            case (.reorder, .reorder):
                true
            default:
                false
            }
        }
        try transact { () throws(RepositoryError) in
            if !hasNewerLocalWrite {
                switch job.kind {
                case .updateStatus(let taskID, _, _):
                    guard let serverTask = serverSnapshot.tasks.first(where: { $0.id == taskID }) else {
                        throw .taskNotFound
                    }
                    let record = try taskRecord(id: taskID)
                    if serverTask.status == .inTransit {
                        let shift = try activeShiftRecord()
                        guard record.shiftID == shift.id else { throw .taskNotInActiveShift }
                        try requireNoOtherTaskInTransit(besides: taskID)
                    }
                    try record.apply(serverTask)
                case .reorder(let orderedTaskIDs):
                    let updates = try orderedTaskIDs.map { taskID throws(RepositoryError) in
                        guard let serverTask = serverSnapshot.tasks.first(where: { $0.id == taskID }) else {
                            throw .taskNotFound
                        }
                        return (record: try taskRecord(id: taskID), sortOrder: serverTask.sortOrder)
                    }
                    for update in updates {
                        update.record.sortOrder = update.sortOrder
                    }
                }
            }
            modelContext.delete(jobRecord)
        }
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
