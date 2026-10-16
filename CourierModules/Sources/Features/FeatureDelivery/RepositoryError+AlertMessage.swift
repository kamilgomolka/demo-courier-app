import Domain
import Foundation

extension RepositoryError {
    var alertMessage: LocalizedStringResource {
        switch self {
        case .anotherTaskInTransit: .deliveryAlertAnotherTaskInTransit
        case .undoWindowClosed: .deliveryAlertUndoWindowClosed
        case .invalidTransition: .deliveryAlertInvalidTransition
        case .taskNotInActiveShift: .deliveryAlertTaskNotInActiveShift
        case .exceptionDetailsRequired: .deliveryAlertExceptionDetailsRequired
        case .taskNotFound, .shiftHasTaskInTransit, .shiftNotActive, .invalidShiftTransition, .resetReloadFailed,
            .storageFailure:
            .deliveryAlertMessage
        }
    }
}
