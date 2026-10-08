import Domain
import Observation
import SwiftUI

@Observable
final class TaskQueueModel {
    private(set) var taskInTransit: DeliveryTask?
    private(set) var upcomingTasks: [DeliveryTask] = []
    private(set) var failure: RepositoryError?

    @ObservationIgnored private let taskRepository: any TaskRepository

    init(taskRepository: any TaskRepository) {
        self.taskRepository = taskRepository
    }

    func run() async {
        for await queue in taskRepository.observeQueue() {
            apply(queue)
        }
    }

    func moveUpcomingTasks(fromOffsets source: IndexSet, toOffset destination: Int) async {
        let previousOrder = upcomingTasks
        var reordered = previousOrder
        reordered.move(fromOffsets: source, toOffset: destination)
        guard reordered.map(\.id) != previousOrder.map(\.id) else { return }
        upcomingTasks = reordered
        do {
            try await taskRepository.reorderQueue(orderedTaskIDs: reordered.map(\.id))
        } catch {
            upcomingTasks = previousOrder
            failure = error
        }
    }

    func dismissFailure() {
        failure = nil
    }

    private func apply(_ queue: [DeliveryTask]) {
        let updatedTaskInTransit = queue.first { $0.status == .inTransit }
        let updatedUpcomingTasks = queue.filter { $0.status == .new }
        if taskInTransit != updatedTaskInTransit {
            taskInTransit = updatedTaskInTransit
        }
        if upcomingTasks != updatedUpcomingTasks {
            upcomingTasks = updatedUpcomingTasks
        }
    }
}
