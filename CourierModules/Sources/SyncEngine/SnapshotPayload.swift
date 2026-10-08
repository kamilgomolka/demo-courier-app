import Domain
import Foundation

struct SnapshotPayload: Decodable {
    struct ShiftPayload: Decodable {
        let id: ShiftID
        let status: ShiftStatus
        let startDate: Date?
        let endDate: Date?
    }

    struct TaskPayload: Decodable {
        let id: TaskID
        let recipientName: String
        let deliveryAddress: String
        let packageSummary: String
        let payout: String
        let status: TaskStatus
        let sortOrder: Int
        let shiftID: ShiftID?
        let assignedAt: Date
    }

    let shift: ShiftPayload
    let tasks: [TaskPayload]

    static func decode(from data: Data) throws(SyncError) -> RemoteSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(SnapshotPayload.self, from: data).makeSnapshot()
        } catch {
            throw .decodingFailed
        }
    }

    private func makeSnapshot() throws(SyncError) -> RemoteSnapshot {
        let mappedTasks = try tasks.map { task throws(SyncError) in
            guard let payout = Decimal(string: task.payout, locale: Locale(identifier: "en_US_POSIX")) else {
                throw .decodingFailed
            }
            return DeliveryTask(
                id: task.id,
                recipientName: task.recipientName,
                deliveryAddress: task.deliveryAddress,
                packageSummary: task.packageSummary,
                payout: payout,
                status: task.status,
                sortOrder: task.sortOrder,
                shiftID: task.shiftID,
                assignedAt: task.assignedAt
            )
        }
        return RemoteSnapshot(
            shift: Shift(id: shift.id, status: shift.status, startDate: shift.startDate, endDate: shift.endDate),
            tasks: mappedTasks
        )
    }
}
