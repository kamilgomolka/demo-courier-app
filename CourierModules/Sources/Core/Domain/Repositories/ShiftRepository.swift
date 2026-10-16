public protocol ShiftRepository: Sendable {
    func observeShiftSummary() -> AsyncStream<ShiftSummary?>

    func startShift() async throws(RepositoryError)
    func endShift() async throws(RepositoryError)
    func reopenShift() async throws(RepositoryError)
}
