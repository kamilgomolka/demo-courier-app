import DesignSystem
import Domain
import SwiftUI

struct TaskQueueView: View {
    @State private var editMode: EditMode = .inactive
    let shiftCardModel: ShiftCardModel
    let queueModel: TaskQueueModel
    let isInteractive: Bool
    let onSelectTask: (TaskID) -> Void

    var body: some View {
        List {
            Section {
                if editMode.isEditing {
                    Label(.dashboardQueueReorderMessage, systemImage: "line.3.horizontal")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(20)
                } else {
                    ShiftCardView(model: shiftCardModel)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if let taskInTransit = queueModel.taskInTransit {
                Section(String(localized: .dashboardQueueInTransitHeader)) {
                    row(for: taskInTransit)
                }
            }
            Section(String(localized: .dashboardQueueUpcomingHeader)) {
                ForEach(Array(queueModel.upcomingTasks.enumerated()), id: \.element.id) { index, task in
                    row(for: task)
                        .listRowSeparator(.hidden)
                        .overlay(alignment: .bottom) {
                            if index < queueModel.upcomingTasks.count - 1 {
                                Divider().padding(.horizontal, 4)
                            }
                        }
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
        .environment(\.editMode, $editMode)
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

#if DEBUG
    import DomainTestSupport

    private func taskQueuePreview(
        summary: ShiftSummary,
        queue: [DeliveryTask],
        isInteractive: Bool
    ) -> some View {
        let taskRepository = FakeTaskRepository()
        taskRepository.queue.send(queue)
        let shiftRepository = FakeShiftRepository()
        shiftRepository.summary.send(summary)
        let shiftCardModel = ShiftCardModel(shiftRepository: shiftRepository, syncController: FakeSyncController())
        let queueModel = TaskQueueModel(taskRepository: taskRepository)
        return NavigationStack {
            TaskQueueView(
                shiftCardModel: shiftCardModel,
                queueModel: queueModel,
                isInteractive: isInteractive,
                onSelectTask: { _ in }
            )
        }
        .task { await shiftCardModel.run() }
        .task { await queueModel.run() }
    }

    #Preview("In transit") {
        taskQueuePreview(
            summary: .fixture(status: .active, earnings: 42, completedCount: 1, hasTaskInTransit: true),
            queue: [
                .fixture(id: "in-transit", status: .inTransit),
                .fixture(id: "next", status: .new, sortOrder: 1),
            ],
            isInteractive: true
        )
    }

    #Preview("Upcoming") {
        taskQueuePreview(
            summary: .fixture(status: .active, earnings: 42, completedCount: 1),
            queue: [
                .fixture(id: "first", sortOrder: 0),
                .fixture(id: "second", sortOrder: 1),
            ],
            isInteractive: true
        )
    }

    #Preview("Empty") {
        taskQueuePreview(summary: .fixture(status: .active), queue: [], isInteractive: true)
    }

    #Preview("Shift inactive") {
        taskQueuePreview(
            summary: .fixture(status: .scheduled),
            queue: [.fixture(id: "upcoming")],
            isInteractive: false
        )
    }
#endif
