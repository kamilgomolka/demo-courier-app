import FeatureDashboard
import FeatureDelivery
import FeatureHistory
import FeatureSettings
import SwiftUI

struct MainTabView: View {
    let environment: AppEnvironment
    @Bindable var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab(.navigationTabDashboard, systemImage: "shippingbox", value: AppTab.dashboard) {
                NavigationStack(path: $router.dashboardPath) {
                    DashboardView(
                        taskRepository: environment.store,
                        shiftRepository: environment.store,
                        syncController: environment.syncActor,
                        onSelectTask: { router.showTaskDetails(id: $0) }
                    )
                    .navigationDestination(for: DashboardRoute.self) { route in
                        switch route {
                        case .taskDetails(let taskID):
                            TaskDetailsView(
                                taskID: taskID,
                                taskRepository: environment.store,
                                onFinish: { router.closeTaskDetails() }
                            )
                        }
                    }
                }
            }
            Tab(.navigationTabHistory, systemImage: "clock", value: AppTab.history) {
                NavigationStack(path: $router.historyPath) {
                    HistoryView(taskRepository: environment.store)
                }
            }
            Tab(.navigationTabSettings, systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack(path: $router.settingsPath) {
                    SettingsView(
                        conditionsStore: environment.networkConditionsStore,
                        jobRepository: environment.store,
                        syncController: environment.syncActor
                    )
                }
            }
        }
    }
}
