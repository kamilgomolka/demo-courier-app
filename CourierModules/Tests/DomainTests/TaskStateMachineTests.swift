import Domain
import DomainTestSupport
import Foundation
import Testing

struct TaskStateMachineTests {
    private static let date = Date(timeIntervalSince1970: 1_800_000_100)

    private static let events: [(name: String, event: TaskEvent)] = [
        ("startDelivery", .startDelivery),
        ("markDelivered", .markDelivered(at: date)),
        ("undoDelivery", .undoDelivery),
        ("reportException", .reportException(.customerNoShow, at: date)),
    ]

    private static let allowedTransitions: [String: [TaskStatus: TaskStatus]] = [
        "startDelivery": [.new: .inTransit],
        "markDelivered": [.inTransit: .delivered],
        "undoDelivery": [.delivered: .inTransit],
        "reportException": [.inTransit: .exception],
    ]

    @Test(arguments: TaskStatus.allCases, events)
    func transitionTable(status: TaskStatus, scenario: (name: String, event: TaskEvent)) throws {
        let task = DeliveryTask.fixture(status: status)
        let expected = Self.allowedTransitions[scenario.name]?[status]

        if let expected {
            let result = try TaskStateMachine.apply(scenario.event, to: task)
            #expect(result.status == expected)
        } else {
            #expect(throws: RepositoryError.invalidTransition) {
                try TaskStateMachine.apply(scenario.event, to: task)
            }
        }
    }

    @Test func markDeliveredStoresCompletionDate() throws {
        let result = try TaskStateMachine.apply(.markDelivered(at: Self.date), to: .fixture(status: .inTransit))
        #expect(result.completedAt == Self.date)
    }

    @Test func undoClearsCompletionDate() throws {
        let delivered = DeliveryTask.fixture(status: .delivered, completedAt: Self.date)
        let result = try TaskStateMachine.apply(.undoDelivery, to: delivered)
        #expect(result.completedAt == nil)
    }

    @Test func exceptionStoresReasonAndCompletionDate() throws {
        let result = try TaskStateMachine.apply(
            .reportException(.packageDamaged, at: Self.date),
            to: .fixture(status: .inTransit)
        )
        #expect(result.exceptionReason == .packageDamaged)
        #expect(result.completedAt == Self.date)
    }

    @Test(arguments: ["", "   ", "\n"])
    func otherReasonRequiresDetails(details: String) {
        #expect(throws: RepositoryError.exceptionDetailsRequired) {
            try TaskStateMachine.apply(
                .reportException(.other(details: details), at: Self.date),
                to: .fixture(status: .inTransit)
            )
        }
    }

    @Test func otherReasonWithDetailsIsAccepted() throws {
        let result = try TaskStateMachine.apply(
            .reportException(.other(details: "Gate locked"), at: Self.date),
            to: .fixture(status: .inTransit)
        )
        #expect(result.exceptionReason == .other(details: "Gate locked"))
    }
}
