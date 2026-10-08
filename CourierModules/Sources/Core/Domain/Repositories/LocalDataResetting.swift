public protocol LocalDataResetting: Sendable {
    func resetAllData() async throws(RepositoryError)
}
