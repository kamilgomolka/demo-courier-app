import DesignSystem
import Domain
import SwiftUI

struct TaskQueueView: View {
    let shiftCardModel: ShiftCardModel
    let queueModel: TaskQueueModel
    let isInteractive: Bool
    let taskNamespace: Namespace.ID
    let onSelectTask: (TaskID) -> Void

    var body: some View {
        List {
            Section {
                ShiftCardView(model: shiftCardModel)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if let taskInTransit = queueModel.taskInTransit {
                Section(String(localized: .dashboardQueueInTransitHeader)) {
                    row(for: taskInTransit)
                }
            }
            Section(String(localized: .dashboardQueueUpcomingHeader)) {
                ForEach(queueModel.upcomingTasks) { task in
                    row(for: task)
                }
                .onMove { source, destination in
                    Task { await queueModel.moveUpcomingTasks(fromOffsets: source, toOffset: destination) }
                }
                .moveDisabled(!isInteractive)
            }
            if queueModel.taskInTransit == nil && queueModel.upcomingTasks.isEmpty {
                EmptyStateView(
                    systemImage: "shippingbox",
                    title: .dashboardQueueEmptyTitle,
                    message: .dashboardQueueEmptyMessage
                )
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.backgroundPrimary)
        .toolbar {
            if isInteractive && !queueModel.upcomingTasks.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func row(for task: DeliveryTask) -> some View {
        Button {
            onSelectTask(task.id)
        } label: {
            TaskRowView(task: task)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .opacity(isInteractive ? 1 : 0.5)
        .accessibilityIdentifier(DashboardAccessibility.taskRow(id: task.id))
        .matchedTransitionSource(id: task.id, in: taskNamespace)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if task.status == .new {
                Button {
                    Task { await queueModel.startDelivery(id: task.id) }
                } label: {
                    Label(.dashboardQueueStartDeliveryAction, systemImage: "bicycle")
                }
                .tint(Palette.accent)
                .disabled(!isInteractive)
            }
        }
    }
}
