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

    static func makeLive(arguments: [String] = ProcessInfo.processInfo.arguments) async -> AppEnvironment? {
        #if DEBUG
            let isUITesting = arguments.contains(uiTestingArgument)
            let testSessionID =
                isUITesting
                ? ProcessInfo.processInfo.environment["COURIER_UI_TEST_SESSION"].flatMap { UUID(uuidString: $0) } : nil
            let suiteName = testSessionID.map { "\(uiTestingSuiteName).\($0.uuidString)" } ?? uiTestingSuiteName
            let conditionsStore = UserDefaultsNetworkConditionsStore(suiteName: isUITesting ? suiteName : nil)
            if isUITesting {
                var conditions = testSessionID == nil ? NetworkConditions() : conditionsStore.load()
                conditions.latencyRange = 0.1...0.3
                conditionsStore.save(conditions)
            }
        #else
            let conditionsStore = UserDefaultsNetworkConditionsStore()
        #endif
        do {
            let store: LocalStore
            #if DEBUG
                if let testSessionID {
                    let storeURL = URL.cachesDirectory.appending(
                        path: "\(uiTestingSuiteName)-\(testSessionID.uuidString).store"
                    )
                    store = try await CourierStorage.makeStore(storeURL: storeURL)
                } else {
                    store = try await CourierStorage.makeStore(isStoredInMemoryOnly: isUITesting)
                }
            #else
                store = try await CourierStorage.makeStore(isStoredInMemoryOnly: false)
            #endif
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
