enum DeliveryAccessibility {
    static let startButton = "delivery.startButton"
    static let markDeliveredButton = "delivery.markDeliveredButton"
    static let reportExceptionButton = "delivery.reportExceptionButton"
    static let undoButton = "delivery.undoButton"
    static let doneButton = "delivery.doneButton"
    static let exceptionDetailsField = "delivery.exception.detailsField"
    static let exceptionSaveButton = "delivery.exception.saveButton"

    static func exceptionOption(_ name: String) -> String {
        "delivery.exception.option.\(name)"
    }
}
