import DesignSystem
public import Domain
public import SwiftUI

public struct TaskDetailsView: View {
    @State private var model: TaskDetailsViewModel
    @State private var isExceptionSheetPresented = false

    public init(
        taskID: TaskID,
        taskRepository: any TaskRepository,
        onDeliveryMarked: @escaping (DeliveryTask) -> Void = { _ in },
        onFinish: @escaping () -> Void
    ) {
        _model = State(
            initialValue: TaskDetailsViewModel(
                taskID: taskID,
                taskRepository: taskRepository,
                onDeliveryMarked: onDeliveryMarked,
                onFinish: onFinish
            )
        )
    }

    public var body: some View {
        content
            .background(Palette.backgroundPrimary)
            .navigationTitle(Text(.deliveryDetailsNavigationTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.close()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text(.deliveryDetailsCloseButton))
                }
            }
            .task { await model.run() }
            .sensoryFeedback(.success, trigger: model.task?.status) { previous, current in
                previous == .inTransit && current == .delivered
            }
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
                Text(model.failure?.alertMessage ?? .deliveryAlertMessage)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let task = model.task {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(.deliveryDetailsRecipientLabel, systemImage: "person.crop.circle")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.accent)
                        Text(task.recipientName)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                            .minimumScaleFactor(0.75)
                    }

                    details(of: task)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actions(for: task)
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
            }
        } else {
            ProgressView()
        }
    }

    private func details(of task: DeliveryTask) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Label(.deliveryDetailsAddressLabel, systemImage: "mappin.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                Text(task.deliveryAddress)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
            }

            Divider()

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(.deliveryDetailsPackageLabel, systemImage: "shippingbox")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Text(task.packageSummary)
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(.deliveryDetailsPayoutLabel)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Text(task.payout, format: .currency(code: "GBP"))
                        .font(Typography.amount.monospacedDigit())
                        .foregroundStyle(Palette.textPrimary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 22))
    }

    @ViewBuilder
    private func actions(for task: DeliveryTask) -> some View {
        VStack(spacing: 12) {
            switch task.status {
            case .new:
                Text(.deliveryDetailsStartPrompt)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)

                PrimaryButton(.deliveryDetailsStartButton, systemImage: "bicycle") {
                    Task { await model.startDelivery() }
                }
                .disabled(model.isPerformingAction)
                .accessibilityIdentifier(DeliveryAccessibility.startButton)
            case .inTransit:
                Text(.deliveryDetailsCompletionPrompt)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)

                PrimaryButton(.deliveryDetailsMarkDeliveredButton, systemImage: "checkmark") {
                    Task { await model.markDelivered() }
                }
                .disabled(model.isPerformingAction)
                .accessibilityIdentifier(DeliveryAccessibility.markDeliveredButton)

                Button {
                    isExceptionSheetPresented = true
                } label: {
                    Label(.deliveryDetailsReportExceptionButton, systemImage: "exclamationmark.bubble")
                        .font(Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(Palette.danger)
                        .background(
                            LinearGradient(
                                colors: [
                                    Palette.danger.opacity(0.08),
                                    Palette.danger.mix(with: .black, by: 0.35).opacity(0.08),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(DeliveryAccessibility.reportExceptionButton)
            case .delivered, .exception:
                PrimaryButton(.deliveryDetailsDoneButton, systemImage: "checkmark") {
                    Task { await model.completeDelivery() }
                }
                .disabled(model.isPerformingAction)
                .accessibilityIdentifier(DeliveryAccessibility.doneButton)
            }
        }
    }
}

#if DEBUG
    import DomainTestSupport

    private func taskDetailsPreview(_ task: DeliveryTask) -> some View {
        let repository = FakeTaskRepository()
        repository.send(task, for: task.id)

        return NavigationStack {
            TaskDetailsView(taskID: task.id, taskRepository: repository, onFinish: {})
        }
    }

    #Preview("New") {
        taskDetailsPreview(.fixture(status: .new))
    }

    #Preview("In transit") {
        taskDetailsPreview(.fixture(status: .inTransit))
    }

    #Preview("Delivered") {
        taskDetailsPreview(.fixture(status: .delivered))
    }
#endif
