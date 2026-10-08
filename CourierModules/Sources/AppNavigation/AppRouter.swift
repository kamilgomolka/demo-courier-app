import Domain
import Observation
import SwiftUI

enum AppTab: Hashable {
    case dashboard
    case history
    case settings
}

enum DashboardRoute: Hashable {
    case taskDetails(TaskID)
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard
    var dashboardPath: [DashboardRoute] = []
    var historyPath = NavigationPath()
    var settingsPath = NavigationPath()

    func showTaskDetails(id: TaskID) {
        dashboardPath.append(.taskDetails(id))
    }

    func closeTaskDetails() {
        guard !dashboardPath.isEmpty else { return }
        dashboardPath.removeLast()
    }
}
