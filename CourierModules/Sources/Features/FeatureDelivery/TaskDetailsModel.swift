import Domain
import Foundation
import Observation

@Observable
final class TaskDetailsModel {
    private(set) var task: DeliveryTask?
    private(set) var failure: RepositoryError?
    private(set) var isPerformingAction = false

    @ObservationIgnored private let taskID: TaskID
    @ObservationIgnored private let taskRepository: any TaskRepository
    @ObservationIgnored private let timeSource: any TimeSource
    @ObservationIgnored private let onFinish: () -> Void
    @ObservationIgnored private let onDeliveryMarked: (DeliveryTask) -> Void
    @ObservationIgnored private var isFinished = false
    @ObservationIgnored private var hasLoadedTask = false

    init(
        taskID: TaskID,
        taskRepository: any TaskRepository,
        timeSource: any TimeSource = SystemTimeSource(),
        onDeliveryMarked: @escaping (DeliveryTask) -> Void = { _ in },
        onFinish: @escaping () -> Void
    ) {
        self.taskID = taskID
        self.taskRepository = taskRepository
        self.timeSource = timeSource
        self.onDeliveryMarked = onDeliveryMarked
        self.onFinish = onFinish
    }

    var undoDeadline: Date? {
        guard task?.status == .delivered, let completedAt = task?.completedAt else { return nil }
        return completedAt.addingTimeInterval(SyncPolicy.undoWindow)
    }

    func run() async {
        for await updatedTask in taskRepository.observeTask(id: taskID) {
            let previousStatus = task?.status
            if task != updatedTask {
                task = updatedTask
            }
            if previousStatus == .inTransit, let updatedTask, updatedTask.status == .delivered {
                onDeliveryMarked(updatedTask)
                finish()
            }
            if updatedTask != nil {
                hasLoadedTask = true
            } else if hasLoadedTask {
                finish()
            }
        }
    }

    func startDelivery() async {
        await perform { () async throws(RepositoryError) in try await self.taskRepository.startDelivery(id: self.taskID)
        }
    }

    func markDelivered() async {
        await perform { () async throws(RepositoryError) in try await self.taskRepository.markDelivered(id: self.taskID)
        }
    }

    func undoDelivery() async {
        await perform { () async throws(RepositoryError) in try await self.taskRepository.undoDelivery(id: self.taskID)
        }
    }

    func reportException(_ reason: ExceptionReason) async {
        let isReported = await perform { () async throws(RepositoryError) in
            try await self.taskRepository.reportException(id: self.taskID, reason: reason)
        }
        if isReported {
            finish()
        }
    }

    func completeDelivery() async {
        if await commitDelivery() {
            finish()
        }
    }

    func commitDeliveryIfNeeded() async {
        guard task?.status == .delivered else { return }
        await commitDelivery()
    }

    func finishWhenUndoWindowExpires() async {
        guard let undoDeadline else { return }
        do {
            try await timeSource.sleep(until: undoDeadline)
        } catch {
            return
        }
        await completeDelivery()
    }

    func dismissFailure() {
        failure = nil
    }

    @discardableResult
    private func commitDelivery() async -> Bool {
        await perform { () async throws(RepositoryError) in
            try await self.taskRepository.commitDelivery(id: self.taskID)
        }
    }

    @discardableResult
    private func perform(_ action: () async throws(RepositoryError) -> Void) async -> Bool {
        guard !isPerformingAction else { return false }
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            try await action()
            return true
        } catch {
            failure = error
            return false
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        onFinish()
    }
}
