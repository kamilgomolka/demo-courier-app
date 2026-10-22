enum DashboardAccessibility {
    static let shiftMetrics = "dashboard.shiftMetrics"
    static let startShiftButton = "dashboard.startShiftButton"
    static let endShiftButton = "dashboard.endShiftButton"
    static let endShiftConfirmButton = "dashboard.endShiftConfirmButton"
    static let reopenShiftButton = "dashboard.reopenShiftButton"

    static func taskRow(id: String) -> String {
        "dashboard.taskRow.\(id)"
    }
}
