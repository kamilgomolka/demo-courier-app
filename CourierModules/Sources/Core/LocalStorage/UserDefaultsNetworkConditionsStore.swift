public import Domain
import Foundation
import os

public struct UserDefaultsNetworkConditionsStore: NetworkConditionsStore {
    private let suiteName: String?
    private let key: String

    public init(suiteName: String? = nil, keyPrefix: String = "courier.") {
        self.suiteName = suiteName
        key = keyPrefix + "networkConditions"
    }

    public func load() -> NetworkConditions {
        guard let data = userDefaults.data(forKey: key) else {
            return NetworkConditions()
        }

        do {
            return try JSONDecoder().decode(NetworkConditions.self, from: data)
        } catch {
            Log.storage.error(
                "Discarding unreadable network conditions: \(String(describing: error), privacy: .public)")
            return NetworkConditions()
        }
    }

    public func save(_ conditions: NetworkConditions) {
        do {
            userDefaults.set(try JSONEncoder().encode(conditions), forKey: key)
        } catch {
            Log.storage.error("Failed to save network conditions: \(String(describing: error), privacy: .public)")
        }
    }

    private var userDefaults: UserDefaults {
        suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }
}
