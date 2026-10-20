import Domain
import DomainTestSupport
import Foundation
import Testing

@testable import LocalStorage

struct DiskPersistenceTests {
    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "CourierPersistence-\(UUID().uuidString).store")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path() + suffix))
        }
    }

    private func withStoreURL(_ body: (URL) async throws -> Void) async throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        try await body(url)
    }

    private func openStore(at url: URL, timeSource: ManualTimeSource) throws -> LocalStore {
        LocalStore(modelContainer: try CourierStorage.makeContainer(storeURL: url), timeSource: timeSource)
    }

    @Test func jobSurvivesStoreRecreation() async throws {
        try await withStoreURL { url in
            let timeSource = ManualTimeSource()

            do {
                let store = try openStore(at: url, timeSource: timeSource)
                try await store.mergeRemoteSnapshot(StoreFixture.snapshot())
                try await store.startShift()
                try await store.startDelivery(id: "task-1")
            }

            let reopened = try openStore(at: url, timeSource: timeSource)

            let jobs = try #require(await firstValue(of: reopened.observeJobs()))
            let task = try #require(await firstValue(of: reopened.observeTask(id: "task-1")) ?? nil)
            #expect(jobs.count == 1)
            #expect(task.status == .inTransit)
            #expect(task.syncState == .pending)
        }
    }

    @Test func restartInsideUndoWindowKeepsJobHeldAndUndoWorks() async throws {
        try await withStoreURL { url in
            let timeSource = ManualTimeSource()

            do {
                let store = try openStore(at: url, timeSource: timeSource)
                try await store.mergeRemoteSnapshot(StoreFixture.snapshot())
                try await store.startShift()
                try await store.startDelivery(id: "task-1")
                try await store.markDelivered(id: "task-1")
            }

            timeSource.advance(by: 2)

            let reopened = try openStore(at: url, timeSource: timeSource)

            let eligibleBeforeExpiry = try await reopened.eligibleJobs(at: timeSource.now())
            #expect(eligibleBeforeExpiry.count == 1)
            #expect(
                eligibleBeforeExpiry.first?.kind
                    == .updateStatus(taskID: "task-1", status: .inTransit, exceptionReason: nil))

            try await reopened.undoDelivery(id: "task-1")

            let task = try #require(await firstValue(of: reopened.observeTask(id: "task-1")) ?? nil)
            #expect(task.status == .inTransit)
        }
    }

    @Test func restartAfterWindowExpiryMakesJobEligible() async throws {
        try await withStoreURL { url in
            let timeSource = ManualTimeSource()

            do {
                let store = try openStore(at: url, timeSource: timeSource)
                try await store.mergeRemoteSnapshot(StoreFixture.snapshot())
                try await store.startShift()
                try await store.startDelivery(id: "task-1")
                try await store.markDelivered(id: "task-1")
            }

            timeSource.advance(by: SyncPolicy.undoWindow + 1)

            let reopened = try openStore(at: url, timeSource: timeSource)

            let eligible = try await reopened.eligibleJobs(at: timeSource.now())
            #expect(eligible.count == 2)

            await #expect(throws: RepositoryError.undoWindowClosed) {
                try await reopened.undoDelivery(id: "task-1")
            }
        }
    }
}
