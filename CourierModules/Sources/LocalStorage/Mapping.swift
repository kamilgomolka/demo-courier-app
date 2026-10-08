import Domain
import Foundation

extension DeliveryTaskRecord {
    func makeDomain(syncState: SyncState) throws(RepositoryError) -> DeliveryTask {
        let decodedReason = try exceptionReasonData.map { data throws(RepositoryError) in
            try Self.decode(ExceptionReason.self, from: data)
        }
        return DeliveryTask(
            id: id,
            recipientName: recipientName,
            deliveryAddress: deliveryAddress,
            packageSummary: packageSummary,
            payout: payout,
            status: status,
            exceptionReason: decodedReason,
            sortOrder: sortOrder,
            shiftID: shiftID,
            syncState: syncState,
            assignedAt: assignedAt,
            completedAt: completedAt
        )
    }

    convenience init(_ task: DeliveryTask) throws(RepositoryError) {
        let encodedReason = try task.exceptionReason.map { reason throws(RepositoryError) in
            try Self.encode(reason)
        }
        self.init(
            id: task.id,
            recipientName: task.recipientName,
            deliveryAddress: task.deliveryAddress,
            packageSummary: task.packageSummary,
            payout: task.payout,
            status: task.status,
            exceptionReasonData: encodedReason,
            sortOrder: task.sortOrder,
            shiftID: task.shiftID,
            assignedAt: task.assignedAt,
            completedAt: task.completedAt
        )
    }

    func apply(_ task: DeliveryTask) throws(RepositoryError) {
        exceptionReasonData = try task.exceptionReason.map { reason throws(RepositoryError) in
            try Self.encode(reason)
        }
        status = task.status
        completedAt = task.completedAt
    }

    private static func encode<Value: Encodable>(_ value: Value) throws(RepositoryError) -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw .storageFailure(String(describing: error))
        }
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws(RepositoryError) -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw .storageFailure(String(describing: error))
        }
    }
}

extension ShiftRecord {
    var domain: Shift {
        Shift(id: id, status: status, startDate: startDate, endDate: endDate)
    }

    convenience init(_ shift: Shift) {
        self.init(id: shift.id, status: shift.status, startDate: shift.startDate, endDate: shift.endDate)
    }
}

extension SyncJobRecord {
    func makeDomain() throws(RepositoryError) -> SyncJob {
        do {
            return SyncJob(
                id: id,
                kind: try JSONDecoder().decode(SyncJobKind.self, from: kindData),
                createdAt: createdAt,
                notBefore: notBefore,
                attemptCount: attemptCount,
                lastFailure: lastFailure
            )
        } catch {
            throw .storageFailure(String(describing: error))
        }
    }

    convenience init(_ job: SyncJob) throws(RepositoryError) {
        do {
            self.init(
                id: job.id,
                kindData: try JSONEncoder().encode(job.kind),
                createdAt: job.createdAt,
                notBefore: job.notBefore,
                attemptCount: job.attemptCount,
                lastFailure: job.lastFailure
            )
        } catch {
            throw .storageFailure(String(describing: error))
        }
    }
}
