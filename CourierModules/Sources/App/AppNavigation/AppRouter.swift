import Domain
import Foundation
import Observation

struct PendingDeliveryUndo: Identifiable, Equatable {
    let task: DeliveryTask
    let deadline: Date

    var id: TaskID { task.id }
}

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
    private(set) var pendingDeliveryUndo: PendingDeliveryUndo?
    private(set) var undoFailure: RepositoryError?

    func showTaskDetails(id: TaskID) {
        dashboardPath.append(.taskDetails(id))
    }

    func closeTaskDetails() {
        guard !dashboardPath.isEmpty else { return }
        dashboardPath.removeLast()
    }

    func offerUndo(for task: DeliveryTask) {
        guard let completedAt = task.completedAt else { return }
        pendingDeliveryUndo = PendingDeliveryUndo(
            task: task,
            deadline: completedAt.addingTimeInterval(SyncPolicy.undoWindow)
        )
    }

    func clearUndo(for id: TaskID) {
        guard pendingDeliveryUndo?.id == id else { return }
        pendingDeliveryUndo = nil
        undoFailure = nil
    }

    func recordUndoFailure(_ error: any Error) {
        undoFailure = error as? RepositoryError ?? .storageFailure(String(describing: error))
    }

    func dismissUndoFailure() {
        undoFailure = nil
    }
}
