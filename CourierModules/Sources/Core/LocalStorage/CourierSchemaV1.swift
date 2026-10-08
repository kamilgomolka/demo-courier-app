import Domain
import Foundation
import SwiftData

enum CourierSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [DeliveryTaskRecord.self, ShiftRecord.self, SyncJobRecord.self]
    }

    @Model
    final class DeliveryTaskRecord {
        @Attribute(.unique) var id: String
        var recipientName: String
        var deliveryAddress: String
        var packageSummary: String
        var payout: Decimal
        var status: TaskStatus
        var exceptionReasonData: Data?
        var sortOrder: Int
        var shiftID: String?
        var assignedAt: Date
        var completedAt: Date?

        init(
            id: String,
            recipientName: String,
            deliveryAddress: String,
            packageSummary: String,
            payout: Decimal,
            status: TaskStatus,
            exceptionReasonData: Data?,
            sortOrder: Int,
            shiftID: String?,
            assignedAt: Date,
            completedAt: Date?
        ) {
            self.id = id
            self.recipientName = recipientName
            self.deliveryAddress = deliveryAddress
            self.packageSummary = packageSummary
            self.payout = payout
            self.status = status
            self.exceptionReasonData = exceptionReasonData
            self.sortOrder = sortOrder
            self.shiftID = shiftID
            self.assignedAt = assignedAt
            self.completedAt = completedAt
        }
    }

    @Model
    final class ShiftRecord {
        @Attribute(.unique) var id: String
        var status: ShiftStatus
        var startDate: Date?
        var endDate: Date?

        init(id: String, status: ShiftStatus, startDate: Date?, endDate: Date?) {
            self.id = id
            self.status = status
            self.startDate = startDate
            self.endDate = endDate
        }
    }

    @Model
    final class SyncJobRecord {
        @Attribute(.unique) var id: UUID
        var kindData: Data
        var createdAt: Date
        var notBefore: Date
        var attemptCount: Int
        var lastFailure: String?

        init(id: UUID, kindData: Data, createdAt: Date, notBefore: Date, attemptCount: Int, lastFailure: String?) {
            self.id = id
            self.kindData = kindData
            self.createdAt = createdAt
            self.notBefore = notBefore
            self.attemptCount = attemptCount
            self.lastFailure = lastFailure
        }
    }
}

typealias DeliveryTaskRecord = CourierSchemaV1.DeliveryTaskRecord
typealias ShiftRecord = CourierSchemaV1.ShiftRecord
typealias SyncJobRecord = CourierSchemaV1.SyncJobRecord
