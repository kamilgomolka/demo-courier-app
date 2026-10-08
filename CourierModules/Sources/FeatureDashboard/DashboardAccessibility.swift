enum DashboardAccessibility {
    static let startShiftButton = "dashboard.startShiftButton"
    static let endShiftButton = "dashboard.endShiftButton"

    static func taskRow(id: String) -> String {
        "dashboard.taskRow.\(id)"
    }
}
