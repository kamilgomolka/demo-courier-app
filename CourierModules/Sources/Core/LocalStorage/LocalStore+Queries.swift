public import Domain
import Foundation
import os

extension LocalStore {
    func allTasks() throws(RepositoryError) -> [DeliveryTask] {
        let pendingTaskIDs = try pendingStatusTaskIDs()
        return try fetch(DeliveryTaskRecord.self).map { record throws(RepositoryError) in
            try record.makeDomain(syncState: pendingTaskIDs.contains(record.id) ? .pending : .synced)
        }
    }

    func queueSnapshot() throws(RepositoryError) -> [DeliveryTask] {
        try allTasks()
            .filter { $0.status == .inTransit || $0.status == .new }
            .sorted { lhs, rhs in
                if (lhs.status == .inTransit) != (rhs.status == .inTransit) {
                    return lhs.status == .inTransit
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    func completedSnapshot() throws(RepositoryError) -> [DeliveryTask] {
        try allTasks()
            .filter { $0.status == .delivered || $0.status == .exception }
            .sorted { ($0.completedAt ?? $0.assignedAt) > ($1.completedAt ?? $1.assignedAt) }
    }

    func taskSnapshot(id: TaskID) throws(RepositoryError) -> DeliveryTask? {
        try allTasks().first { $0.id == id }
    }

    func shiftSummarySnapshot() throws(RepositoryError) -> ShiftSummary? {
        guard let shiftRecord = try fetch(ShiftRecord.self).first else { return nil }
        return ShiftSummary(shift: shiftRecord.domain, tasks: try allTasks())
    }

    func jobsSnapshot() throws(RepositoryError) -> [SyncJob] {
        try decodableJobRecords().map(\.job)
    }

    func pendingStatusTaskIDs() throws(RepositoryError) -> Set<TaskID> {
        var taskIDs: Set<TaskID> = []
        for job in try jobsSnapshot() {
            if case .updateStatus(let taskID, _, _) = job.kind {
                taskIDs.insert(taskID)
            }
        }
        return taskIDs
    }

    func taskRecord(id: TaskID) throws(RepositoryError) -> DeliveryTaskRecord {
        guard let record = try fetch(DeliveryTaskRecord.self).first(where: { $0.id == id }) else {
            throw .taskNotFound
        }
        return record
    }

    func domainTask(_ record: DeliveryTaskRecord) throws(RepositoryError) -> DeliveryTask {
        try record.makeDomain(syncState: .synced)
    }

    func activeShiftRecord() throws(RepositoryError) -> ShiftRecord {
        guard let record = try fetch(ShiftRecord.self).first(where: { $0.status == .active }) else {
            throw .shiftNotActive
        }
        return record
    }

    func jobRecords(matching predicate: (SyncJob) -> Bool) throws(RepositoryError) -> [(
        record: SyncJobRecord, job: SyncJob
    )] {
        try decodableJobRecords().filter { predicate($0.job) }
    }

    private func decodableJobRecords() throws(RepositoryError) -> [(record: SyncJobRecord, job: SyncJob)] {
        var decodable: [(record: SyncJobRecord, job: SyncJob)] = []
        for record in try fetch(SyncJobRecord.self) {
            do {
                decodable.append((record: record, job: try record.makeDomain()))
            } catch {
                Log.storage.error(
                    "Skipping undecodable sync job \(record.id, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        }
        return decodable.sorted { $0.job.createdAt < $1.job.createdAt }
    }
}

extension LocalStore: TaskRepository, ShiftRepository, SyncJobRepository, LocalDataResetting {
    public nonisolated func observeQueue() -> AsyncStream<[DeliveryTask]> {
        observe { store throws(RepositoryError) in
            try store.queueSnapshot()
        }
    }

    public nonisolated func observeTask(id: TaskID) -> AsyncStream<DeliveryTask?> {
        observe { store throws(RepositoryError) in
            try store.taskSnapshot(id: id)
        }
    }

    public nonisolated func observeCompleted() -> AsyncStream<[DeliveryTask]> {
        observe { store throws(RepositoryError) in
            try store.completedSnapshot()
        }
    }

    public nonisolated func observeShiftSummary() -> AsyncStream<ShiftSummary?> {
        observe { store throws(RepositoryError) in
            try store.shiftSummarySnapshot()
        }
    }

    public nonisolated func observeJobs() -> AsyncStream<[SyncJob]> {
        observe { store throws(RepositoryError) in
            try store.jobsSnapshot()
        }
    }
}
