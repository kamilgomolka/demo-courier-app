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
                            HistoryRowView(
                                task: task,
                                isFirst: index == 0,
                                isLast: index == section.tasks.count - 1
                            )
                            .accessibilityIdentifier(HistoryAccessibility.row(id: task.id))
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    } header: {
                        Text(section.day, format: .dateTime.day().month().year())
                    }
                }
            }
        }
        .navigationTitle(Text(.historyNavigationTitle))
        .task { await model.run() }
        .scrollContentBackground(.hidden)
        .background(Palette.backgroundPrimary)
    }
}

private struct HistoryRowView: View {
    let task: DeliveryTask
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Color.clear.frame(width: 16)
            VStack(alignment: .leading, spacing: 8) {
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
                if let completedAt = task.completedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(completedAt, format: .dateTime.hour().minute())
                    }
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 6)
                }
                if task.syncState == .pending {
                    StatusBadge(
                        .historyBadgePendingSync, systemImage: "arrow.triangle.2.circlepath", tint: Palette.warning
                    )
                    .symbolEffect(.rotate, options: .repeating)
                }
            }
        }
        .padding(.vertical, 16)
        .background(alignment: .leading) {
            GeometryReader { geometry in
                Path { path in
                    if !isFirst {
                        path.move(to: CGPoint(x: 8, y: 0))
                        path.addLine(to: CGPoint(x: 8, y: 28))
                    }
                    if !isLast {
                        path.move(to: CGPoint(x: 8, y: 28))
                        path.addLine(to: CGPoint(x: 8, y: geometry.size.height))
                    }
                }
                .stroke(Palette.textSecondary.opacity(0.32), lineWidth: 2)
                Circle()
                    .fill(task.status == .exception ? Palette.danger : Palette.success)
                    .frame(width: 12, height: 12)
                    .position(x: 8, y: 28)
            }
        }
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

#if DEBUG
    import DomainTestSupport

    private func historyPreview(_ tasks: [DeliveryTask]) -> some View {
        let repository = FakeTaskRepository()
        repository.completed.send(tasks)
        return NavigationStack {
            HistoryView(taskRepository: repository)
        }
    }

    #Preview("Completed") {
        historyPreview([
            .fixture(
                id: "delivered",
                status: .delivered,
                completedAt: Date(timeIntervalSince1970: 1_800_000_000)
            ),
            .fixture(
                id: "exception",
                status: .exception,
                exceptionReason: .addressNotFound,
                syncState: .pending,
                completedAt: Date(timeIntervalSince1970: 1_799_913_600)
            ),
        ])
    }

    #Preview("Empty") {
        historyPreview([])
    }
#endif
