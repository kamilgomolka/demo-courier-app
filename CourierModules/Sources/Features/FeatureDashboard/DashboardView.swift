import DesignSystem
public import Domain
public import SwiftUI

public struct DashboardView: View {
    @State private var shiftCardModel: ShiftCardViewModel
    @State private var queueModel: TaskQueueViewModel
    private let syncController: any SyncControlling
    private let onSelectTask: (TaskID) -> Void

    public init(
        taskRepository: any TaskRepository,
        shiftRepository: any ShiftRepository,
        syncController: any SyncControlling,
        onSelectTask: @escaping (TaskID) -> Void
    ) {
        _shiftCardModel = State(
            initialValue: ShiftCardViewModel(shiftRepository: shiftRepository, syncController: syncController)
        )
        _queueModel = State(initialValue: TaskQueueViewModel(taskRepository: taskRepository))
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
                Text((shiftCardModel.actionFailure ?? queueModel.failure)?.alertMessage ?? .dashboardAlertMessage)
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

#if DEBUG
    import DomainTestSupport

    private func dashboardPreview(
        summary: ShiftSummary?,
        queue: [DeliveryTask] = [],
        loadFailure: SyncError? = nil
    ) -> some View {
        let taskRepository = FakeTaskRepository()
        taskRepository.queue.send(queue)
        let shiftRepository = FakeShiftRepository()
        shiftRepository.summary.send(summary)
        let syncController = FakeSyncController()
        syncController.loadFailure = loadFailure

        return NavigationStack {
            DashboardView(
                taskRepository: taskRepository,
                shiftRepository: shiftRepository,
                syncController: syncController,
                onSelectTask: { _ in }
            )
        }
    }

    #Preview("Ready") {
        dashboardPreview(
            summary: .fixture(status: .active, earnings: 42, completedCount: 1),
            queue: [.fixture(id: "next")]
        )
    }

    #Preview("Loading") {
        dashboardPreview(summary: nil)
    }

    #Preview("Failed") {
        dashboardPreview(summary: nil, loadFailure: .offline)
    }
#endif
