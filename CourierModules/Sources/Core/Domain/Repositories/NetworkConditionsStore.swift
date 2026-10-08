public protocol NetworkConditionsStore: Sendable {
    func load() -> NetworkConditions
    func save(_ conditions: NetworkConditions)
}
