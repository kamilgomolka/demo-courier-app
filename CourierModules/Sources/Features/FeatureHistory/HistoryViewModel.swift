import Domain
import Foundation
import Observation

struct HistorySection: Equatable, Identifiable {
    let day: Date
    let tasks: [DeliveryTask]

    var id: Date { day }
}

@Observable
final class HistoryViewModel {
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
        let completedTasks = tasks.compactMap { task in
            task.completedAt.map { (task: task, completedAt: $0) }
        }

        let tasksByDay = Dictionary(grouping: completedTasks) { calendar.startOfDay(for: $0.completedAt) }

        return
            tasksByDay
            .map { day, entries in
                HistorySection(day: day, tasks: entries.sorted { $0.completedAt > $1.completedAt }.map(\.task))
            }
            .sorted { $0.day > $1.day }
    }
}
