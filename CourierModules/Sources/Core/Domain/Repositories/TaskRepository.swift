public protocol TaskRepository: Sendable {
    func observeQueue() -> AsyncStream<[DeliveryTask]>
    func observeTask(id: TaskID) -> AsyncStream<DeliveryTask?>
    func observeCompleted() -> AsyncStream<[DeliveryTask]>

    func startDelivery(id: TaskID) async throws(RepositoryError)
    func markDelivered(id: TaskID) async throws(RepositoryError)
    func undoDelivery(id: TaskID) async throws(RepositoryError)
    func commitDelivery(id: TaskID) async throws(RepositoryError)
    func reportException(id: TaskID, reason: ExceptionReason) async throws(RepositoryError)
    func reorderQueue(orderedTaskIDs: [TaskID]) async throws(RepositoryError)
}
