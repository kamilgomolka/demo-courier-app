public import Foundation

public struct ShiftSummary: Equatable, Sendable {
    public var status: ShiftStatus
    public var earnings: Decimal
    public var completedCount: Int
    public var totalCount: Int
    public var hasTaskInTransit: Bool

    public init(status: ShiftStatus, earnings: Decimal, completedCount: Int, totalCount: Int, hasTaskInTransit: Bool) {
        self.status = status
        self.earnings = earnings
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.hasTaskInTransit = hasTaskInTransit
    }

    public init(shift: Shift, tasks: [DeliveryTask]) {
        let shiftTasks = tasks.filter { $0.shiftID == shift.id }
        self.init(
            status: shift.status,
            earnings: shiftTasks.filter { $0.status == .delivered }.reduce(0) { $0 + $1.payout },
            completedCount: shiftTasks.filter { $0.status == .delivered || $0.status == .exception }.count,
            totalCount: shiftTasks.count,
            hasTaskInTransit: shiftTasks.contains { $0.status == .inTransit }
        )
    }

    public var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}
