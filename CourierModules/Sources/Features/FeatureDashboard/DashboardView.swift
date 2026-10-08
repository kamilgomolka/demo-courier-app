import DesignSystem
public import Domain
public import SwiftUI

public struct DashboardView: View {
    @State private var shiftCardModel: ShiftCardModel
    @State private var queueModel: TaskQueueModel
    private let syncController: any SyncControlling
    private let onSelectTask: (TaskID) -> Void

    public init(
        taskRepository: any TaskRepository,
        shiftRepository: any ShiftRepository,
        syncController: any SyncControlling,
        onSelectTask: @escaping (TaskID) -> Void
    ) {
        _shiftCardModel = State(
            initialValue: ShiftCardModel(shiftRepository: shiftRepository, syncController: syncController)
        )
        _queueModel = State(initialValue: TaskQueueModel(taskRepository: taskRepository))
        self.syncController = syncController
        self.onSelectTask = onSelectTask
    }

    public var body: some View {
        content
            .navigationTitle(Text(.dashboardNavigationTitle))
            .task { await shiftCardModel.run() }
            .task { await queueModel.run() }
            .task { await syncController.requestSync(.screenAppeared) }
            .alert(
                Text(.dashboardAlertTitle),
                isPresented: Binding(
                    get: { shiftCardModel.actionFailure != nil || queueModel.failure != nil },
                    set: { isPresented in
                        guard !isPresented else { return }
                        shiftCardModel.dismissActionFailure()
                        queueModel.dismissFailure()
                    }
                )
            ) {
                Button(String(localized: .dashboardAlertDismissButton)) {}
            } message: {
                Text(.dashboardAlertMessage)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch shiftCardModel.phase {
        case .loading:
            VStack(spacing: 16) {
                ProgressView()
                Text(.dashboardLoadingTitle)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            EmptyStateView(
                systemImage: "wifi.exclamationmark",
                title: .dashboardErrorTitle,
                message: .dashboardErrorMessage,
                action: EmptyStateView.Action(.dashboardErrorRetryButton) {
                    Task { await shiftCardModel.retry() }
                }
            )
        case .ready:
            TaskQueueView(
                shiftCardModel: shiftCardModel,
                queueModel: queueModel,
                isInteractive: shiftCardModel.isShiftActive,
                onSelectTask: onSelectTask
            )
        }
    }
}
