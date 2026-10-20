import Domain
import Observation

@Observable
final class TaskDetailsViewModel {
    private(set) var task: DeliveryTask?
    private(set) var failure: RepositoryError?
    private(set) var isPerformingAction = false

    @ObservationIgnored private let taskID: TaskID
    @ObservationIgnored private let taskRepository: any TaskRepository
    @ObservationIgnored private let onFinish: () -> Void
    @ObservationIgnored private let onDeliveryMarked: (DeliveryTask) -> Void
    @ObservationIgnored private var isFinished = false
    @ObservationIgnored private var hasLoadedTask = false

    init(
        taskID: TaskID,
        taskRepository: any TaskRepository,
        onDeliveryMarked: @escaping (DeliveryTask) -> Void = { _ in },
        onFinish: @escaping () -> Void
    ) {
        self.taskID = taskID
        self.taskRepository = taskRepository
        self.onDeliveryMarked = onDeliveryMarked
        self.onFinish = onFinish
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
        await perform { () async throws(RepositoryError) in
            try await self.taskRepository.startDelivery(id: self.taskID)
        }
    }

    func markDelivered() async {
        await perform { () async throws(RepositoryError) in
            try await self.taskRepository.markDelivered(id: self.taskID)
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
        let isCommitted = await perform { () async throws(RepositoryError) in
            try await self.taskRepository.commitDelivery(id: self.taskID)
        }
        if isCommitted {
            finish()
        }
    }

    func dismissFailure() {
        failure = nil
    }

    func close() {
        finish()
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
