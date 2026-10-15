import Domain
import Foundation
import LocalStorage
import SyncEngine
import UIKit
import os

@MainActor
final class AppEnvironment {
    private static let uiTestingArgument = "--ui-testing"
    private static let uiTestingSuiteName = "CourierAppUITests"

    let store: LocalStore
    let syncActor: SyncActor
    let networkConditionsStore: any NetworkConditionsStore

    private init(store: LocalStore, syncActor: SyncActor, networkConditionsStore: any NetworkConditionsStore) {
        self.store = store
        self.syncActor = syncActor
        self.networkConditionsStore = networkConditionsStore
    }

    static func makeLive(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment? {
        #if DEBUG
            let isUITesting = arguments.contains(uiTestingArgument)
        #else
            let isUITesting = false
        #endif
        do {
            let container = try CourierStorage.makeContainer(isStoredInMemoryOnly: isUITesting)
            let store = LocalStore(modelContainer: container)
            let conditionsStore = UserDefaultsNetworkConditionsStore(suiteName: isUITesting ? uiTestingSuiteName : nil)
            if isUITesting {
                conditionsStore.save(NetworkConditions(latencyRange: 0.1...0.3))
            }
            let api = MockCourierAPI(conditionsStore: conditionsStore)
            let syncActor = SyncActor(
                jobRepository: store,
                localDataResetter: store,
                api: api,
                sessionRefresher: MockSessionRefresher(conditionsStore: conditionsStore)
            )
            return AppEnvironment(store: store, syncActor: syncActor, networkConditionsStore: conditionsStore)
        } catch {
            Log.navigation.error("Failed to create storage: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func start() async {
        await syncActor.start()
        await syncActor.requestSync(.launch)
    }

    func requestSync(_ trigger: SyncTrigger) {
        Task { await syncActor.requestSync(trigger) }
    }

    func extendExecutionUntilOutboxDrains() {
        let outboxDrained = Task { [store] in
            for await jobs in store.observeJobs() where !jobs.contains(where: { $0.attemptCount == 0 }) {
                return
            }
        }
        let application = UIApplication.shared
        let backgroundTaskIdentifier = application.beginBackgroundTask(withName: "outbox-drain") {
            outboxDrained.cancel()
        }
        Task {
            await outboxDrained.value
            application.endBackgroundTask(backgroundTaskIdentifier)
        }
    }
}
