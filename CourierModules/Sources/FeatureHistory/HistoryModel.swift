import Domain
import Foundation
import Observation

struct HistorySection: Equatable, Identifiable {
    let day: Date
    let tasks: [DeliveryTask]

    var id: Date { day }
}

@Observable
final class HistoryModel {
    private(set) var sections: [HistorySection] = []

    @ObservationIgnored private let taskRepository: any TaskRepository
    @ObservationIgnored private let calendar: Calendar

    init(taskRepository: any TaskRepository, calendar: Calendar = .current) {
        self.taskRepository = taskRepository
        self.calendar = calendar
    }

    func run() async {
        for await completedTasks in taskRepository.observeCompleted() {
            let updatedSections = groupedByDay(completedTasks)
            if sections != updatedSections {
                sections = updatedSections
            }
        }
    }

    private func groupedByDay(_ tasks: [DeliveryTask]) -> [HistorySection] {
        let completedTasks = tasks.filter { $0.completedAt != nil }
        let tasksByDay = Dictionary(grouping: completedTasks) { task in
            calendar.startOfDay(for: task.completedAt ?? task.assignedAt)
        }
        return
            tasksByDay
            .map { day, tasks in
                HistorySection(
                    day: day,
                    tasks: tasks.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                )
            }
            .sorted { $0.day > $1.day }
    }
}
