public import Domain
import Foundation

extension LocalStore {
    public func startShift() async throws(RepositoryError) {
        try transact { () throws(RepositoryError) in
            guard let shift = try fetch(ShiftRecord.self).first, shift.status == .scheduled else {
                throw .invalidShiftTransition
            }
            shift.status = .active
            shift.startDate = timeSource.now()
        }
    }

    public func endShift() async throws(RepositoryError) {
        try transact { () throws(RepositoryError) in
            guard let shift = try fetch(ShiftRecord.self).first, shift.status == .active else {
                throw .invalidShiftTransition
            }
            let hasTaskInTransit = try fetch(DeliveryTaskRecord.self).contains {
                $0.shiftID == shift.id && $0.status == .inTransit
            }
            guard !hasTaskInTransit else { throw .shiftHasTaskInTransit }
            shift.status = .finished
            shift.endDate = timeSource.now()
        }
    }
}
