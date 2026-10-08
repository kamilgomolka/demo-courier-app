import DesignSystem
public import Domain
public import SwiftUI

public struct TaskDetailsView: View {
    @State private var model: TaskDetailsModel
    @State private var isExceptionSheetPresented = false

    public init(taskID: TaskID, taskRepository: any TaskRepository, onFinish: @escaping () -> Void) {
        _model = State(
            initialValue: TaskDetailsModel(taskID: taskID, taskRepository: taskRepository, onFinish: onFinish)
        )
    }

    public var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.run() }
            .task(id: model.undoDeadline) { await model.finishWhenUndoWindowExpires() }
            .onDisappear { Task { await model.commitDeliveryIfNeeded() } }
            .sheet(isPresented: $isExceptionSheetPresented) {
                ExceptionReportSheet(
                    onSave: { reason in
                        isExceptionSheetPresented = false
                        Task { await model.reportException(reason) }
                    },
                    onCancel: { isExceptionSheetPresented = false }
                )
                .presentationDetents([.medium, .large])
            }
            .alert(
                Text(.deliveryAlertTitle),
                isPresented: Binding(
                    get: { model.failure != nil },
                    set: { isPresented in
                        if !isPresented {
                            model.dismissFailure()
                        }
                    }
                )
            ) {
                Button(String(localized: .deliveryAlertDismissButton)) {}
            } message: {
                Text(.deliveryAlertMessage)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let task = model.task {
            VStack(alignment: .leading, spacing: 24) {
                details(of: task)
                actions(for: task)
                Spacer()
            }
            .padding()
            .navigationTitle(task.recipientName)
        } else {
            ProgressView()
        }
    }

    private func details(of task: DeliveryTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.deliveryAddress)
                .font(Typography.title)
                .foregroundStyle(Palette.textPrimary)
            Text(task.packageSummary)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
            Text(task.payout, format: .currency(code: "GBP"))
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func actions(for task: DeliveryTask) -> some View {
        switch task.status {
        case .new:
            PrimaryButton(.deliveryDetailsStartButton) {
                Task { await model.startDelivery() }
            }
            .accessibilityIdentifier(DeliveryAccessibility.startButton)
        case .inTransit:
            PrimaryButton(.deliveryDetailsMarkDeliveredButton, role: .success) {
                Task { await model.markDelivered() }
            }
            .accessibilityIdentifier(DeliveryAccessibility.markDeliveredButton)
            PrimaryButton(.deliveryDetailsReportExceptionButton, role: .destructive) {
                isExceptionSheetPresented = true
            }
            .accessibilityIdentifier(DeliveryAccessibility.reportExceptionButton)
        case .delivered:
            deliveredActions(completedAt: task.completedAt)
        case .exception:
            EmptyView()
        }
    }

    @ViewBuilder
    private func deliveredActions(completedAt: Date?) -> some View {
        if let completedAt, let undoDeadline = model.undoDeadline {
            VStack(alignment: .leading, spacing: 8) {
                Text(.deliveryDetailsDeliveredTitle)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.success)
                ProgressView(timerInterval: completedAt...undoDeadline, countsDown: true) {
                    Text(.deliveryDetailsUndoCountdownLabel)
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(Palette.accent)
            }
            Button(String(localized: .deliveryDetailsUndoButton)) {
                Task { await model.undoDelivery() }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier(DeliveryAccessibility.undoButton)
        }
        PrimaryButton(.deliveryDetailsDoneButton) {
            Task { await model.completeDelivery() }
        }
        .accessibilityIdentifier(DeliveryAccessibility.doneButton)
    }
}
