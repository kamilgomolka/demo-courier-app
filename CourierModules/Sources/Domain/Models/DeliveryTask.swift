public import Foundation

public struct DeliveryTask: Equatable, Identifiable, Sendable {
    public var id: TaskID
    public var recipientName: String
    public var deliveryAddress: String
    public var packageSummary: String
    public var payout: Decimal
    public var status: TaskStatus
    public var exceptionReason: ExceptionReason?
    public var sortOrder: Int
    public var shiftID: ShiftID?
    public var syncState: SyncState
    public var assignedAt: Date
    public var completedAt: Date?

    public init(
        id: TaskID,
        recipientName: String,
        deliveryAddress: String,
        packageSummary: String,
        payout: Decimal,
        status: TaskStatus = .new,
        exceptionReason: ExceptionReason? = nil,
        sortOrder: Int,
        shiftID: ShiftID? = nil,
        syncState: SyncState = .synced,
        assignedAt: Date,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.recipientName = recipientName
        self.deliveryAddress = deliveryAddress
        self.packageSummary = packageSummary
        self.payout = payout
        self.status = status
        self.exceptionReason = exceptionReason
        self.sortOrder = sortOrder
        self.shiftID = shiftID
        self.syncState = syncState
        self.assignedAt = assignedAt
        self.completedAt = completedAt
    }
}
