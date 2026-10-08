public import Domain
public import Foundation

extension DeliveryTask {
    public static func fixture(
        id: TaskID = "task-1",
        status: TaskStatus = .new,
        exceptionReason: ExceptionReason? = nil,
        payout: Decimal = 20,
        sortOrder: Int = 0,
        shiftID: ShiftID? = "shift-1",
        syncState: SyncState = .synced,
        assignedAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
        completedAt: Date? = nil
    ) -> DeliveryTask {
        DeliveryTask(
            id: id,
            recipientName: "Recipient \(id)",
            deliveryAddress: "Address \(id)",
            packageSummary: "Package \(id)",
            payout: payout,
            status: status,
            exceptionReason: exceptionReason,
            sortOrder: sortOrder,
            shiftID: shiftID,
            syncState: syncState,
            assignedAt: assignedAt,
            completedAt: completedAt
        )
    }
}

extension Shift {
    public static func fixture(
        id: ShiftID = "shift-1",
        status: ShiftStatus = .scheduled,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> Shift {
        Shift(id: id, status: status, startDate: startDate, endDate: endDate)
    }
}

extension ShiftSummary {
    public static func fixture(
        status: ShiftStatus = .active,
        earnings: Decimal = 0,
        completedCount: Int = 0,
        totalCount: Int = 3,
        hasTaskInTransit: Bool = false
    ) -> ShiftSummary {
        ShiftSummary(
            status: status,
            earnings: earnings,
            completedCount: completedCount,
            totalCount: totalCount,
            hasTaskInTransit: hasTaskInTransit
        )
    }
}

extension RemoteSnapshot {
    public static func fixture(taskCount: Int = 3) -> RemoteSnapshot {
        RemoteSnapshot(
            shift: .fixture(),
            tasks: (0..<taskCount).map { .fixture(id: "task-\($0 + 1)", sortOrder: $0) }
        )
    }
}
