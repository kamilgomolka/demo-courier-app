import Domain
import Foundation
import Testing

@testable import LocalStorage

struct NetworkConditionsStoreTests {
    @Test func returnsDefaultsWhenNothingWasSaved() {
        let suiteName = "NetworkConditionsStoreTests.defaults.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsNetworkConditionsStore(suiteName: suiteName)

        #expect(store.load() == NetworkConditions())
    }

    @Test func persistsSavedConditions() {
        let suiteName = "NetworkConditionsStoreTests.roundTrip.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let conditions = NetworkConditions(
            isOffline: true, latencyRange: 0.5...4, simulatedFailure: .serviceUnavailable)

        UserDefaultsNetworkConditionsStore(suiteName: suiteName).save(conditions)

        #expect(UserDefaultsNetworkConditionsStore(suiteName: suiteName).load() == conditions)
    }
}
