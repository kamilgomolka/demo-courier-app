import DesignSystem
public import Domain
public import SwiftUI

public struct HistoryView: View {
    @State private var model: HistoryModel

    public init(taskRepository: any TaskRepository) {
        _model = State(initialValue: HistoryModel(taskRepository: taskRepository))
    }

    public var body: some View {
        Group {
            if model.sections.isEmpty {
                EmptyStateView(
                    systemImage: "clock",
                    title: .historyEmptyTitle,
                    message: .historyEmptyMessage
                )
            } else {
                List(model.sections) { section in
                    Section {
                        ForEach(section.tasks) { task in
                            HistoryRowView(task: task)
                                .accessibilityIdentifier(HistoryAccessibility.row(id: task.id))
                        }
                    } header: {
                        Text(section.day, format: .dateTime.day().month().year())
                    }
                }
            }
        }
        .navigationTitle(Text(.historyNavigationTitle))
        .task { await model.run() }
    }
}

private struct HistoryRowView: View {
    let task: DeliveryTask

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(task.recipientName)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                statusBadge
            }
            Text(subtitle)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
            if task.syncState == .pending {
                StatusBadge(.historyBadgePendingSync, systemImage: "arrow.triangle.2.circlepath", tint: Palette.warning)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch task.status {
        case .exception:
            StatusBadge(.historyBadgeException, systemImage: "exclamationmark.triangle.fill", tint: Palette.danger)
        default:
            StatusBadge(.historyBadgeDelivered, systemImage: "checkmark.circle.fill", tint: Palette.success)
        }
    }

    private var subtitle: String {
        task.exceptionReason?.displayText ?? task.deliveryAddress
    }
}
