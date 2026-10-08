import Domain
import DomainTestSupport
import Foundation
import SwiftData
import Testing

@testable import LocalStorage

struct StoreFixture {
    let store: LocalStore
    let timeSource: ManualTimeSource

    static func make(
        startedShift: Bool = true,
        snapshot: RemoteSnapshot = StoreFixture.snapshot(),
        timeSource: ManualTimeSource = ManualTimeSource()
    ) async throws -> StoreFixture {
        let container = try CourierStorage.makeContainer(isStoredInMemoryOnly: true)
        let store = LocalStore(modelContainer: container, timeSource: timeSource)
        try await store.mergeRemoteSnapshot(snapshot)
        if startedShift {
            try await store.startShift()
        }
        return StoreFixture(store: store, timeSource: timeSource)
    }

    static func snapshot(taskCount: Int = 5) -> RemoteSnapshot {
        RemoteSnapshot(
            shift: .fixture(status: .scheduled),
            tasks: (1...taskCount).map { .fixture(id: "task-\($0)", sortOrder: $0) }
        )
    }

    func task(_ id: TaskID) async throws -> DeliveryTask {
        let found = await firstValue(of: store.observeTask(id: id))
        return try #require(found.flatMap { $0 })
    }

    func shiftSummary() async throws -> ShiftSummary {
        let emission = try #require(await firstValue(of: store.observeShiftSummary()))
        return try #require(emission)
    }

    func jobs() async throws -> [SyncJob] {
        try #require(await firstValue(of: store.observeJobs()))
    }

    func queueIDs() async throws -> [TaskID] {
        try #require(await firstValue(of: store.observeQueue())).map(\.id)
    }
}

func firstValue<Value: Sendable>(of stream: AsyncStream<Value>) async -> Value? {
    var iterator = stream.makeAsyncIterator()
    return await iterator.next()
}
