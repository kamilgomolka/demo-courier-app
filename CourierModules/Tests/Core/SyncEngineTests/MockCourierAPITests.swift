import Domain
import DomainTestSupport
import Foundation
import Testing

@testable import SyncEngine

struct MockCourierAPITests {
    private static let failureMappings: [(SimulatedFailure, SyncError)] = [
        (.timeout, .timedOut),
        (.connectionLost, .connectionLost),
        (.serverError, .server(status: 500)),
        (.serviceUnavailable, .server(status: 503)),
        (.tooManyRequests, .server(status: 429)),
        (.unauthorized, .unauthorized),
    ]

    private func makeAPI(_ conditions: NetworkConditions) -> MockCourierAPI {
        MockCourierAPI(
            conditionsStore: FakeNetworkConditionsStore(conditions),
            timeSource: ManualTimeSource(),
            latency: { _ in 0 }
        )
    }

    private func makeJob() -> SyncJob {
        SyncJob(
            kind: .updateStatus(taskID: "task-1", status: .delivered, exceptionReason: nil),
            createdAt: Date(),
            notBefore: Date()
        )
    }

    private static func failure(of job: SyncJob, sentTo api: MockCourierAPI) async -> SyncError? {
        do {
            try await api.send(job)
            return nil
        } catch {
            return error
        }
    }

    @Test(arguments: failureMappings)
    func simulatedFailureMapsToSyncError(failure: SimulatedFailure, expected: SyncError) async {
        let api = makeAPI(NetworkConditions(latencyRange: 0...0, simulatedFailure: failure))

        await #expect(throws: expected) {
            try await api.send(makeJob())
        }
        #expect(api.requests.count == 1)
    }

    @Test func offlineFailsWithoutReachingTheServer() async {
        let api = makeAPI(NetworkConditions(isOffline: true))

        await #expect(throws: SyncError.offline) {
            try await api.send(makeJob())
        }
        #expect(api.requests.isEmpty)
    }

    @Test func duplicateIdempotencyKeysAreAccepted() async throws {
        let api = makeAPI(NetworkConditions(latencyRange: 0...0))
        let job = makeJob()

        try await api.send(job)
        try await api.send(job)

        #expect(api.requests.map(\.idempotencyKey) == [job.id, job.id])
    }

    @Test func reorderJobUsesRouteOptimizationEndpoint() async throws {
        let api = makeAPI(NetworkConditions(latencyRange: 0...0))
        let job = SyncJob(kind: .reorder(orderedTaskIDs: ["b", "a"]), createdAt: Date(), notBefore: Date())

        try await api.send(job)

        let request = try #require(api.requests.first)
        #expect(request.path == "/route-optimization")
        #expect(request.method == "PATCH")
    }

    @Test func bundledSnapshotContainsOneScheduledShiftWithTwelveTasks() async throws {
        let api = makeAPI(NetworkConditions(latencyRange: 0...0))

        let snapshot = try await api.fetchSnapshot()

        #expect(snapshot.shift.status == .scheduled)
        #expect(snapshot.tasks.count == 12)
        #expect(snapshot.tasks.allSatisfy { $0.shiftID == snapshot.shift.id && $0.status == .new })
        #expect(snapshot.tasks.map(\.sortOrder) == Array(1...12))
        #expect(snapshot.tasks.allSatisfy { $0.payout > 0 })
    }

    @Test func cancelledRequestStopsDuringLatencyWithoutReachingTheServer() async throws {
        let timeSource = ManualTimeSource()
        let api = MockCourierAPI(
            conditionsStore: FakeNetworkConditionsStore(),
            timeSource: timeSource,
            latency: { _ in 2 }
        )
        let job = makeJob()
        let task = Task { await Self.failure(of: job, sentTo: api) }
        #expect(await eventually { timeSource.pendingSleeperCount == 1 })

        task.cancel()

        #expect(await task.value == .cancelled)
        #expect(api.requests.isEmpty)
    }
}
