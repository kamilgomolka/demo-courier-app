public import Domain
import Foundation
import SwiftData

extension LocalStore {
    public func startDelivery(id: TaskID) async throws(RepositoryError) {
        try transact { () throws(RepositoryError) in
            let record = try taskRecord(id: id)
            let shift = try activeShiftRecord()
            guard record.shiftID == shift.id else { throw .taskNotInActiveShift }
            let updated = try TaskStateMachine.apply(.startDelivery, to: try domainTask(record))
            try requireNoOtherTaskInTransit(besides: id)
            try record.apply(updated)
            try enqueue(
                .updateStatus(taskID: id, status: .inTransit, exceptionReason: nil), notBefore: timeSource.now())
            try removeFromPendingReorder(taskID: id)
        }
    }

    public func markDelivered(id: TaskID) async throws(RepositoryError) {
        try transact { () throws(RepositoryError) in
            let record = try taskRecord(id: id)
            let now = timeSource.now()
            let updated = try TaskStateMachine.apply(.markDelivered(at: now), to: try domainTask(record))
            try record.apply(updated)
            try enqueue(
                .updateStatus(taskID: id, status: .delivered, exceptionReason: nil),
                notBefore: now.addingTimeInterval(SyncPolicy.undoWindow)
            )
        }
    }

    public func undoDelivery(id: TaskID) async throws(RepositoryError) {
        try transact { () throws(RepositoryError) in
            let record = try taskRecord(id: id)
            let updated = try TaskStateMachine.apply(.undoDelivery, to: try domainTask(record))
            let shift = try activeShiftRecord()
            guard record.shiftID == shift.id else { throw .taskNotInActiveShift }
            guard let holdingJob = try pendingDeliveryJob(taskID: id), holdingJob.job.notBefore > timeSource.now()
            else {
                throw .undoWindowClosed
            }
            try requireNoOtherTaskInTransit(besides: id)
            try record.apply(updated)
            modelContext.delete(holdingJob.record)
        }
    }

    public func commitDelivery(id: TaskID) async throws(RepositoryError) {
        let now = timeSource.now()
        guard
            let record = try fetch(DeliveryTaskRecord.self).first(where: { $0.id == id }),
            record.status == .delivered,
            let holdingJob = try pendingDeliveryJob(taskID: id),
            holdingJob.job.notBefore > now
        else {
            return
        }
        try transact { holdingJob.record.notBefore = now }
    }

    public func reportException(id: TaskID, reason: ExceptionReason) async throws(RepositoryError) {
        try transact { () throws(RepositoryError) in
            let record = try taskRecord(id: id)
            let now = timeSource.now()
            let normalizedReason = Self.normalized(reason)
            let updated = try TaskStateMachine.apply(
                .reportException(normalizedReason, at: now), to: try domainTask(record))
            try record.apply(updated)
            try enqueue(
                .updateStatus(taskID: id, status: .exception, exceptionReason: normalizedReason),
                notBefore: now
            )
        }
    }

    public func reorderQueue(orderedTaskIDs: [TaskID]) async throws(RepositoryError) {
        try transact { () throws(RepositoryError) in
            let shift = try activeShiftRecord()
            guard Set(orderedTaskIDs).count == orderedTaskIDs.count else { throw .invalidTransition }
            let records = try orderedTaskIDs.map { id throws(RepositoryError) in
                try taskRecord(id: id)
            }
            for record in records {
                guard record.shiftID == shift.id else { throw .taskNotInActiveShift }
                guard record.status == .new else { throw .invalidTransition }
            }
            let existingReorderJobs = try jobRecords { job in
                if case .reorder = job.kind { return true }
                return false
            }
            let currentOrder = records.sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
            guard currentOrder != orderedTaskIDs || !existingReorderJobs.isEmpty else { return }

            let availablePositions = records.map(\.sortOrder).sorted()
            for (record, position) in zip(records, availablePositions) {
                record.sortOrder = position
            }
            for existing in existingReorderJobs {
                modelContext.delete(existing.record)
            }
            try enqueue(
                .reorder(orderedTaskIDs: orderedTaskIDs),
                notBefore: timeSource.now().addingTimeInterval(SyncPolicy.reorderDebounce)
            )
        }
    }
}

extension LocalStore {
    private static func normalized(_ reason: ExceptionReason) -> ExceptionReason {
        guard case .other(let details) = reason else { return reason }
        return .other(details: details.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func requireNoOtherTaskInTransit(besides id: TaskID) throws(RepositoryError) {
        let otherInTransit = try fetch(DeliveryTaskRecord.self).contains { $0.status == .inTransit && $0.id != id }
        if otherInTransit {
            throw .anotherTaskInTransit
        }
    }

    private func pendingDeliveryJob(taskID: TaskID) throws(RepositoryError) -> (record: SyncJobRecord, job: SyncJob)? {
        try jobRecords { job in
            if case .updateStatus(taskID, .delivered, _) = job.kind { return true }
            return false
        }.last
    }

    private func enqueue(_ kind: SyncJobKind, notBefore: Date) throws(RepositoryError) {
        let job = SyncJob(kind: kind, createdAt: timeSource.now(), notBefore: notBefore)
        modelContext.insert(try SyncJobRecord(job))
    }

    private func removeFromPendingReorder(taskID: TaskID) throws(RepositoryError) {
        let reorderJobs = try jobRecords { job in
            if case .reorder(let orderedTaskIDs) = job.kind { return orderedTaskIDs.contains(taskID) }
            return false
        }
        for existing in reorderJobs {
            guard case .reorder(let orderedTaskIDs) = existing.job.kind else { continue }
            modelContext.delete(existing.record)
            let remaining = orderedTaskIDs.filter { $0 != taskID }
            guard remaining.count >= 2 else { continue }
            var replacement = existing.job
            replacement.id = UUID()
            replacement.kind = .reorder(orderedTaskIDs: remaining)
            modelContext.insert(try SyncJobRecord(replacement))
        }
    }
}
