public import Domain
public import Foundation
import Synchronization
import os

public final class MockCourierAPI: CourierAPI {
    public struct Request: Equatable, Sendable {
        public let method: String
        public let path: String
        public let idempotencyKey: UUID?
        public let body: Data?
    }

    private struct StatusBody: Encodable {
        let status: TaskStatus
        let exceptionReason: ExceptionReason?
    }

    private struct RouteBody: Encodable {
        let orderedTaskIDs: [TaskID]
    }

    private let conditionsStore: any NetworkConditionsStore
    private let timeSource: any TimeSource
    private let latency: @Sendable (ClosedRange<Double>) -> TimeInterval
    private let snapshotData: Data?
    private let recordedRequests = Mutex<[Request]>([])

    public init(
        conditionsStore: any NetworkConditionsStore,
        timeSource: any TimeSource = SystemTimeSource(),
        latency: @escaping @Sendable (ClosedRange<Double>) -> TimeInterval = { Double.random(in: $0) },
        snapshotData: Data? = nil
    ) {
        self.conditionsStore = conditionsStore
        self.timeSource = timeSource
        self.latency = latency
        self.snapshotData = snapshotData
    }

    public var requests: [Request] {
        recordedRequests.withLock { $0 }
    }

    public func fetchSnapshot() async throws(SyncError) -> RemoteSnapshot {
        try await respond(method: "GET", path: "/tasks", idempotencyKey: nil, body: nil)
        let data: Data
        if let snapshotData {
            data = snapshotData
        } else {
            data = try Self.bundledSnapshotData()
        }
        return try SnapshotPayload.decode(from: data)
    }

    public func send(_ job: SyncJob) async throws(SyncError) {
        let method = "PATCH"
        let path: String
        let body: Data
        do {
            switch job.kind {
            case .updateStatus(let taskID, let status, let exceptionReason):
                path = "/tasks/\(taskID)/status"
                body = try JSONEncoder().encode(StatusBody(status: status, exceptionReason: exceptionReason))
            case .reorder(let orderedTaskIDs):
                path = "/route-optimization"
                body = try JSONEncoder().encode(RouteBody(orderedTaskIDs: orderedTaskIDs))
            }
        } catch {
            throw .decodingFailed
        }
        try await respond(method: method, path: path, idempotencyKey: job.id, body: body)
    }

    private func respond(method: String, path: String, idempotencyKey: UUID?, body: Data?) async throws(SyncError) {
        let conditions = conditionsStore.load()
        guard !conditions.isOffline else {
            Log.network.info("\(method, privacy: .public) \(path, privacy: .public) failed: offline")
            throw .offline
        }
        let delay = latency(conditions.latencyRange)
        if delay > 0 {
            do {
                try await timeSource.sleep(until: timeSource.now().addingTimeInterval(delay))
            } catch {
                throw .cancelled
            }
        }
        recordedRequests.withLock {
            $0.append(Request(method: method, path: path, idempotencyKey: idempotencyKey, body: body))
        }
        Log.network.info("\(method, privacy: .public) \(path, privacy: .public) received")
        if let failure = Self.error(for: conditions.simulatedFailure) {
            Log.network.error(
                "\(method, privacy: .public) \(path, privacy: .public) failed: \(failure.description, privacy: .public)"
            )
            throw failure
        }
    }

    private static func error(for failure: SimulatedFailure) -> SyncError? {
        switch failure {
        case .none: nil
        case .timeout: .timedOut
        case .connectionLost: .connectionLost
        case .serverError: .server(status: 500)
        case .serviceUnavailable: .server(status: 503)
        case .tooManyRequests: .server(status: 429)
        }
    }

    private static func bundledSnapshotData() throws(SyncError) -> Data {
        guard let url = Bundle.module.url(forResource: "courier-snapshot", withExtension: "json") else {
            throw .decodingFailed
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw .decodingFailed
        }
    }
}
