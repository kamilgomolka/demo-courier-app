import Domain
import DomainTestSupport
import Foundation
import Testing

@testable import FeatureDashboard

struct TaskQueueViewModelTests {
    private let taskRepository = FakeTaskRepository()

    private func makeModel() -> TaskQueueViewModel {
        TaskQueueViewModel(taskRepository: taskRepository)
    }

    private func sendQueue(inTransit: Bool = false) {
        var queue: [DeliveryTask] = []

        if inTransit {
            queue.append(.fixture(id: "active", status: .inTransit, sortOrder: 0))
        }

        queue += [
            .fixture(id: "a", sortOrder: 1),
            .fixture(id: "b", sortOrder: 2),
            .fixture(id: "c", sortOrder: 3),
        ]
        taskRepository.queue.send(queue)
    }

    @Test func queueIsSplitIntoInTransitAndUpcomingTasks() async {
        let model = makeModel()
        sendQueue(inTransit: true)
        let run = Task { await model.run() }

        #expect(await eventually { model.upcomingTasks.count == 3 })
        #expect(model.taskInTransit?.id == "active")
        #expect(model.upcomingTasks.map(\.id) == ["a", "b", "c"])
        run.cancel()
    }

    @Test func moveReordersOptimisticallyAndPersistsTheNewOrder() async {
        let model = makeModel()
        sendQueue()
        let run = Task { await model.run() }
        #expect(await eventually { model.upcomingTasks.count == 3 })

        await model.moveUpcomingTasks(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(model.upcomingTasks.map(\.id) == ["c", "a", "b"])
        #expect(taskRepository.calls == [.reorderQueue(["c", "a", "b"])])
        run.cancel()
    }

    @Test func failedReorderRestoresPreviousOrderAndReportsFailure() async {
        let model = makeModel()
        sendQueue()
        let run = Task { await model.run() }
        #expect(await eventually { model.upcomingTasks.count == 3 })
        taskRepository.failure = .shiftNotActive

        await model.moveUpcomingTasks(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        #expect(model.upcomingTasks.map(\.id) == ["a", "b", "c"])
        #expect(model.failure == .shiftNotActive)
        run.cancel()
    }

    @Test func failedReorderPreservesNewerQueueSnapshot() async {
        let model = makeModel()
        sendQueue()
        let run = Task { await model.run() }
        #expect(await eventually { model.upcomingTasks.count == 3 })
        taskRepository.holdCalls()
        taskRepository.failure = .invalidTransition
        let move = Task { await model.moveUpcomingTasks(fromOffsets: IndexSet(integer: 0), toOffset: 3) }
        #expect(await eventually { taskRepository.calls.count == 1 })

        taskRepository.queue.send([
            .fixture(id: "a", status: .inTransit), .fixture(id: "b", sortOrder: 2), .fixture(id: "c", sortOrder: 3),
        ])
        #expect(await eventually { model.taskInTransit?.id == "a" && model.upcomingTasks.count == 2 })
        taskRepository.releaseCalls()
        await move.value

        #expect(model.upcomingTasks.map(\.id) == ["b", "c"])
        #expect(model.taskInTransit?.id == "a")
        #expect(model.failure == .invalidTransition)
        run.cancel()
    }

    @Test func moveToTheSamePositionDoesNotTouchTheRepository() async {
        let model = makeModel()
        sendQueue()
        let run = Task { await model.run() }
        #expect(await eventually { model.upcomingTasks.count == 3 })

        await model.moveUpcomingTasks(fromOffsets: IndexSet(integer: 1), toOffset: 1)

        #expect(taskRepository.calls.isEmpty)
        run.cancel()
    }

    @Test func offlineStateDoesNotBlockReorder() async {
        let model = makeModel()
        sendQueue()
        let run = Task { await model.run() }
        #expect(await eventually { model.upcomingTasks.count == 3 })

        await model.moveUpcomingTasks(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        await model.moveUpcomingTasks(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        #expect(taskRepository.calls.count == 2)
        #expect(model.failure == nil)
        run.cancel()
    }

    @Test func cancellingTheRunTaskEndsTheObservation() async {
        let model = makeModel()
        let run = Task { await model.run() }
        #expect(await eventually { taskRepository.queue.activeObserverCount == 1 })

        run.cancel()

        #expect(await eventually { taskRepository.queue.activeObserverCount == 0 })
    }
}
