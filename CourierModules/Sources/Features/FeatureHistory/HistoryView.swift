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
                        ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                            HistoryRowView(task: task, isLast: index == section.tasks.count - 1)
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
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(task.status == .exception ? Palette.danger : Palette.success)
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(Palette.textSecondary.opacity(isLast ? 0.18 : 0.42))
                    .frame(width: 2)
            }
            .frame(width: 12, height: 62, alignment: .top)
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
                        .symbolEffect(.rotate, options: .repeating)
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch task.status {
        case .exception:
            StatusBadge(.historyBadgeException, systemImage: "exclamationmark.triangle.fill", tint: Palette.danger)
        case .new, .inTransit:
            StatusBadge(.historyBadgeDelivered, systemImage: "checkmark.circle.fill", tint: Palette.success)
        case .delivered:
            StatusBadge(.historyBadgeDelivered, systemImage: "checkmark.circle.fill", tint: Palette.success)
        }
    }

    private var subtitle: String {
        task.exceptionReason?.displayText ?? task.deliveryAddress
    }
}
