import Domain
import Foundation

extension RepositoryError {
    var alertMessage: LocalizedStringResource {
        switch self {
        case .shiftHasTaskInTransit: .dashboardAlertShiftHasTaskInTransit
        case .shiftNotActive: .dashboardAlertShiftNotActive
        case .taskNotInActiveShift: .dashboardAlertTaskNotInActiveShift
        case .invalidTransition, .anotherTaskInTransit, .taskNotFound, .undoWindowClosed,
            .exceptionDetailsRequired, .invalidShiftTransition, .storageFailure:
            .dashboardAlertMessage
        }
    }
}
