import Domain
import DomainTestSupport
import Foundation
import Testing

struct ShiftSummaryTests {
    @Test func earningsSumOnlyDeliveredTasks() {
        let tasks = [
            DeliveryTask.fixture(id: "a", status: .delivered, payout: 10),
            .fixture(id: "b", status: .delivered, payout: 15.5),
            .fixture(id: "c", status: .exception, payout: 99),
            .fixture(id: "d", status: .new, payout: 7),
        ]

        let summary = ShiftSummary(shift: .fixture(status: .active), tasks: tasks)

        #expect(summary.earnings == 25.5)
    }

    @Test func progressCountsDeliveredAndExceptionTasks() {
        let tasks = [
            DeliveryTask.fixture(id: "a", status: .delivered),
            .fixture(id: "b", status: .exception),
            .fixture(id: "c", status: .inTransit),
            .fixture(id: "d", status: .new),
        ]

        let summary = ShiftSummary(shift: .fixture(status: .active), tasks: tasks)

        #expect(summary.completedCount == 2)
        #expect(summary.totalCount == 4)
        #expect(summary.progress == 0.5)
        #expect(summary.hasTaskInTransit)
    }

    @Test func tasksOfOtherShiftsAreIgnored() {
        let tasks = [
            DeliveryTask.fixture(id: "a", status: .delivered, payout: 10, shiftID: "shift-1"),
            .fixture(id: "b", status: .delivered, payout: 10, shiftID: "shift-2"),
            .fixture(id: "c", status: .new, shiftID: nil),
        ]

        let summary = ShiftSummary(shift: .fixture(id: "shift-1"), tasks: tasks)

        #expect(summary.totalCount == 1)
        #expect(summary.earnings == 10)
    }

    @Test func emptyShiftHasZeroProgress() {
        let summary = ShiftSummary(shift: .fixture(), tasks: [])

        #expect(summary.totalCount == 0)
        #expect(summary.progress == 0)
        #expect(!summary.hasTaskInTransit)
    }
}
