import Domain
import DomainTestSupport
import Foundation
import Testing

@testable import FeatureDelivery

private final class FinishRecorder {
    private(set) var count = 0

    func record() {
        count += 1
    }
}

struct TaskDetailsModelTests {
    private let taskRepository = FakeTaskRepository()
    private let timeSource = ManualTimeSource()
    private let finishRecorder = FinishRecorder()

    private func makeModel() -> TaskDetailsModel {
        TaskDetailsModel(
            taskID: "task-1",
            taskRepository: taskRepository,
            timeSource: timeSource,
            onFinish: { finishRecorder.record() }
        )
    }

    private func runModel(_ model: TaskDetailsModel, showing task: DeliveryTask) async -> Task<Void, Never> {
        taskRepository.send(task, for: "task-1")
        let run = Task { await model.run() }
        _ = await eventually { model.task == task }
        return run
    }

    @Test func exposesObservedTask() async {
        let model = makeModel()
        let run = await runModel(model, showing: .fixture(status: .inTransit))

        #expect(model.task?.status == .inTransit)
        run.cancel()
    }

    @Test func stopsObservingWhenRunIsCancelled() async {
        let model = makeModel()
        let run = await runModel(model, showing: .fixture())

        run.cancel()

        #expect(await eventually { taskRepository.activeTaskObserverCount(for: "task-1") == 0 })
    }

    @Test func actionsDelegateToRepositoryWithoutFinishing() async {
        let model = makeModel()

        await model.startDelivery()
        await model.markDelivered()
        await model.undoDelivery()

        #expect(taskRepository.calls == [.startDelivery("task-1"), .markDelivered("task-1"), .undoDelivery("task-1")])
        #expect(finishRecorder.count == 0)
    }

    @Test func repositoryFailureIsExposedAndDismissable() async {
        let model = makeModel()
        taskRepository.failure = .anotherTaskInTransit

        await model.startDelivery()
        #expect(model.failure == .anotherTaskInTransit)

        model.dismissFailure()
        #expect(model.failure == nil)
    }

    @Test func completingDeliveryCommitsAndFinishesOnce() async {
        let model = makeModel()

        await model.completeDelivery()
        await model.completeDelivery()

        #expect(taskRepository.calls == [.commitDelivery("task-1"), .commitDelivery("task-1")])
        #expect(finishRecorder.count == 1)
    }

    @Test func failedCommitDoesNotFinish() async {
        let model = makeModel()
        taskRepository.failure = .storageFailure("disk")

        await model.completeDelivery()

        #expect(finishRecorder.count == 0)
        #expect(model.failure == .storageFailure("disk"))
    }

    @Test func fallbackCommitsOnlyDeliveredTask() async {
        let model = makeModel()
        let run = await runModel(model, showing: .fixture(status: .inTransit))

        await model.commitDeliveryIfNeeded()
        #expect(taskRepository.calls.isEmpty)

        taskRepository.send(.fixture(status: .delivered, completedAt: timeSource.now()), for: "task-1")
        _ = await eventually { model.task?.status == .delivered }
        await model.commitDeliveryIfNeeded()
        #expect(taskRepository.calls == [.commitDelivery("task-1")])
        #expect(finishRecorder.count == 0)
        run.cancel()
    }

    @Test func undoDeadlineIsCompletionPlusUndoWindow() async {
        let model = makeModel()
        let completedAt = timeSource.now()
        let run = await runModel(model, showing: .fixture(status: .delivered, completedAt: completedAt))

        #expect(model.undoDeadline == completedAt.addingTimeInterval(SyncPolicy.undoWindow))
        run.cancel()
    }

    @Test func expiredUndoWindowCommitsAndFinishes() async {
        let model = makeModel()
        let run = await runModel(model, showing: .fixture(status: .delivered, completedAt: timeSource.now()))

        let expiry = Task { await model.finishWhenUndoWindowExpires() }
        _ = await eventually { timeSource.pendingSleeperCount == 1 }
        timeSource.advance(by: SyncPolicy.undoWindow)
        await expiry.value

        #expect(taskRepository.calls == [.commitDelivery("task-1")])
        #expect(finishRecorder.count == 1)
        run.cancel()
    }

    @Test func cancelledExpiryDoesNothing() async {
        let model = makeModel()
        let run = await runModel(model, showing: .fixture(status: .delivered, completedAt: timeSource.now()))

        let expiry = Task { await model.finishWhenUndoWindowExpires() }
        _ = await eventually { timeSource.pendingSleeperCount == 1 }
        expiry.cancel()
        await expiry.value

        #expect(taskRepository.calls.isEmpty)
        #expect(finishRecorder.count == 0)
        run.cancel()
    }

    @Test func expiryIsIgnoredWhenTaskIsNotDelivered() async {
        let model = makeModel()
        let run = await runModel(model, showing: .fixture(status: .inTransit))

        await model.finishWhenUndoWindowExpires()

        #expect(taskRepository.calls.isEmpty)
        #expect(finishRecorder.count == 0)
        run.cancel()
    }

    @Test func reportedExceptionFinishes() async {
        let model = makeModel()

        await model.reportException(.other(details: "Gate locked"))

        #expect(taskRepository.calls == [.reportException("task-1", .other(details: "Gate locked"))])
        #expect(finishRecorder.count == 1)
    }

    @Test func failedExceptionReportDoesNotFinish() async {
        let model = makeModel()
        taskRepository.failure = .exceptionDetailsRequired

        await model.reportException(.customerNoShow)

        #expect(finishRecorder.count == 0)
        #expect(model.failure == .exceptionDetailsRequired)
    }

    @Test func concurrentActionIsIgnoredWithoutFailure() async {
        let model = makeModel()
        taskRepository.holdCalls()
        let first = Task { await model.startDelivery() }
        #expect(await eventually { taskRepository.calls.count == 1 })
        #expect(model.isPerformingAction)

        await model.startDelivery()
        await model.completeDelivery()

        #expect(taskRepository.calls == [.startDelivery("task-1")])
        #expect(model.failure == nil)
        #expect(finishRecorder.count == 0)

        taskRepository.releaseCalls()
        await first.value
        #expect(!model.isPerformingAction)
    }

    @Test func vanishingTaskFinishesOnlyAfterItWasLoaded() async {
        let model = makeModel()
        let run = Task { await model.run() }
        _ = await eventually { taskRepository.activeTaskObserverCount(for: "task-1") == 1 }
        #expect(finishRecorder.count == 0)

        taskRepository.send(.fixture(), for: "task-1")
        _ = await eventually { model.task != nil }
        taskRepository.send(nil, for: "task-1")
        _ = await eventually { finishRecorder.count == 1 }
        taskRepository.send(.fixture(), for: "task-1")
        taskRepository.send(nil, for: "task-1")
        try? await Task.sleep(for: .milliseconds(50))

        #expect(finishRecorder.count == 1)
        run.cancel()
    }

    @Test func alertMessagesAreSpecificForKnownErrorsAndGenericOtherwise() {
        #expect(RepositoryError.anotherTaskInTransit.alertMessage == .deliveryAlertAnotherTaskInTransit)
        #expect(RepositoryError.undoWindowClosed.alertMessage == .deliveryAlertUndoWindowClosed)
        #expect(RepositoryError.exceptionDetailsRequired.alertMessage == .deliveryAlertExceptionDetailsRequired)
        #expect(RepositoryError.storageFailure("disk").alertMessage == .deliveryAlertMessage)
    }
}
