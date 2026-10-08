public import Foundation

public enum TaskEvent: Sendable {
    case startDelivery
    case markDelivered(at: Date)
    case undoDelivery
    case reportException(ExceptionReason, at: Date)
}

public enum TaskStateMachine {
    public static func apply(_ event: TaskEvent, to task: DeliveryTask) throws(RepositoryError) -> DeliveryTask {
        var updated = task
        switch (event, task.status) {
        case (.startDelivery, .new):
            updated.status = .inTransit
        case (.markDelivered(let date), .inTransit):
            updated.status = .delivered
            updated.completedAt = date
        case (.undoDelivery, .delivered):
            updated.status = .inTransit
            updated.completedAt = nil
        case (.reportException(let reason, let date), .inTransit):
            if case .other(let details) = reason,
                details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                throw .exceptionDetailsRequired
            }
            updated.status = .exception
            updated.exceptionReason = reason
            updated.completedAt = date
        default:
            throw .invalidTransition
        }
        return updated
    }
}
