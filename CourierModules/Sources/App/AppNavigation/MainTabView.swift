import DesignSystem
import Domain
import FeatureDashboard
import FeatureDelivery
import FeatureHistory
import FeatureSettings
import LocalStorage
import SwiftUI

struct MainTabView: View {
    let environment: AppEnvironment
    @Bindable var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab(.navigationTabDashboard, systemImage: "shippingbox", value: AppTab.dashboard) {
                NavigationStack {
                    DashboardView(
                        taskRepository: environment.store,
                        shiftRepository: environment.store,
                        syncController: environment.syncActor,
                        onSelectTask: { router.showTaskDetails(id: $0) }
                    )
                }
            }
            Tab(.navigationTabHistory, systemImage: "clock", value: AppTab.history) {
                NavigationStack {
                    HistoryView(taskRepository: environment.store)
                }
            }
            Tab(.navigationTabSettings, systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    SettingsView(
                        conditionsStore: environment.networkConditionsStore,
                        jobRepository: environment.store,
                        syncController: environment.syncActor
                    )
                }
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .tint(Palette.accent)
        .fullScreenCover(item: $router.presentedTask) { presentation in
            NavigationStack {
                TaskDetailsView(
                    taskID: presentation.id,
                    taskRepository: environment.store,
                    onDeliveryMarked: { router.offerUndo(for: $0) },
                    onFinish: { router.closeTaskDetails() }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if let pendingUndo = router.pendingDeliveryUndo {
                DeliveryUndoToast(pendingUndo: pendingUndo) {
                    Task { await undoDelivery(id: pendingUndo.task.id) }
                }
                .padding(.bottom, 72)
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: router.pendingDeliveryUndo?.id)
        .task(id: router.pendingDeliveryUndo?.id) {
            guard let pendingUndo = router.pendingDeliveryUndo else { return }
            do {
                try await SystemTimeSource().sleep(until: pendingUndo.deadline)
                await finishDelivery(id: pendingUndo.task.id)
            } catch is CancellationError {
                return
            } catch {
                router.recordUndoFailure(error)
            }
        }
        .alert(
            Text(.navigationUndoFailureTitle),
            isPresented: Binding(
                get: { router.undoFailure != nil },
                set: { if !$0 { router.dismissUndoFailure() } }
            )
        ) {
            Button(String(localized: .navigationRetry)) {
                guard let pendingUndo = router.pendingDeliveryUndo else { return }
                router.dismissUndoFailure()
                Task { await finishDelivery(id: pendingUndo.task.id) }
            }
            Button(String(localized: .navigationDismiss), role: .cancel) { router.dismissUndoFailure() }
        }
    }

    private func undoDelivery(id: TaskID) async {
        do {
            try await environment.store.undoDelivery(id: id)
            router.clearUndo(for: id)
        } catch {
            router.recordUndoFailure(error)
        }
    }

    private func finishDelivery(id: TaskID) async {
        do {
            try await environment.store.commitDelivery(id: id)
            router.clearUndo(for: id)
        } catch {
            router.recordUndoFailure(error)
        }
    }
}
