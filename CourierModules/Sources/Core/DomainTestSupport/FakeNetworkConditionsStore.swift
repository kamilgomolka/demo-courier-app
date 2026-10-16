#if DEBUG
    public import Domain
    import Synchronization

    public final class FakeNetworkConditionsStore: NetworkConditionsStore {
        private let conditions: Mutex<NetworkConditions>

        public init(_ conditions: NetworkConditions = NetworkConditions()) {
            self.conditions = Mutex(conditions)
        }

        public func load() -> NetworkConditions {
            conditions.withLock { $0 }
        }

        public func save(_ conditions: NetworkConditions) {
            self.conditions.withLock { $0 = conditions }
        }
    }
#endif
