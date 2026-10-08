import Domain
import Foundation
import Testing

struct SyncJobKindTests {
    private static let kinds: [SyncJobKind] = [
        .updateStatus(taskID: "task-1", status: .inTransit, exceptionReason: nil),
        .updateStatus(taskID: "task-2", status: .exception, exceptionReason: .other(details: "Locked gate")),
        .updateStatus(taskID: "task-3", status: .exception, exceptionReason: .addressNotFound),
        .reorder(orderedTaskIDs: ["a", "b", "c"]),
    ]

    @Test(arguments: kinds)
    func roundTripsThroughJSON(kind: SyncJobKind) throws {
        let data = try JSONEncoder().encode(kind)
        let decoded = try JSONDecoder().decode(SyncJobKind.self, from: data)
        #expect(decoded == kind)
    }

    @Test func networkConditionsRoundTripThroughJSON() throws {
        let conditions = NetworkConditions(isOffline: true, latencyRange: 0.5...2, simulatedFailure: .tooManyRequests)
        let data = try JSONEncoder().encode(conditions)
        let decoded = try JSONDecoder().decode(NetworkConditions.self, from: data)
        #expect(decoded == conditions)
    }
}
