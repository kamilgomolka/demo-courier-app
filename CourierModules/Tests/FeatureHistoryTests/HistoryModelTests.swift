import Domain
import DomainTestSupport
import Foundation
import Testing

@testable import FeatureHistory

struct HistoryModelTests {
    private let taskRepository = FakeTaskRepository()
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()
    private var midnight: Date { calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000)) }

    private func makeModel() -> HistoryModel {
        HistoryModel(taskRepository: taskRepository, calendar: calendar)
    }

    private func completed(_ id: TaskID, hoursAfterMidnight: Double, dayOffset: Int = 0) -> DeliveryTask {
        let completedAt = midnight.addingTimeInterval(Double(dayOffset) * 86_400 + hoursAfterMidnight * 3_600)
        return .fixture(id: id, status: .delivered, completedAt: completedAt)
    }

    @Test func startsEmpty() {
        #expect(makeModel().sections.isEmpty)
    }

    @Test func groupsByDayNewestFirstAndSortsTasksWithinDay() async {
        let model = makeModel()
        taskRepository.completed.send([
            completed("a", hoursAfterMidnight: 9),
            completed("b", hoursAfterMidnight: 15),
            completed("c", hoursAfterMidnight: 11, dayOffset: -1),
            completed("d", hoursAfterMidnight: 10),
        ])
        let run = Task { await model.run() }

        #expect(await eventually { model.sections.count == 2 })
        #expect(model.sections.map(\.day) == [midnight, midnight.addingTimeInterval(-86_400)])
        #expect(model.sections[0].tasks.map(\.id) == ["b", "d", "a"])
        #expect(model.sections[1].tasks.map(\.id) == ["c"])
        run.cancel()
    }

    @Test func tasksWithoutCompletionDateAreIgnored() async {
        let model = makeModel()
        taskRepository.completed.send([.fixture(id: "a", status: .delivered), completed("b", hoursAfterMidnight: 9)])
        let run = Task { await model.run() }

        #expect(await eventually { model.sections.count == 1 })
        #expect(model.sections[0].tasks.map(\.id) == ["b"])
        run.cancel()
    }

    @Test func updatesWhenCompletedTasksChange() async {
        let model = makeModel()
        taskRepository.completed.send([completed("a", hoursAfterMidnight: 9)])
        let run = Task { await model.run() }
        #expect(await eventually { model.sections.count == 1 })

        taskRepository.completed.send([])

        #expect(await eventually { model.sections.isEmpty })
        run.cancel()
    }

    @Test func cancellingTheRunTaskEndsTheObservation() async {
        let model = makeModel()
        let run = Task { await model.run() }
        #expect(await eventually { taskRepository.completed.activeObserverCount == 1 })

        run.cancel()

        #expect(await eventually { taskRepository.completed.activeObserverCount == 0 })
    }
}

struct ExceptionReasonDisplayTextTests {
    @Test func otherShowsEnteredDetails() {
        #expect(ExceptionReason.other(details: "Gate locked").displayText == "Gate locked")
    }

    @Test func predefinedReasonsAreLocalized() {
        #expect(ExceptionReason.customerNoShow.displayText == "Customer not available")
        #expect(ExceptionReason.addressNotFound.displayText == "Address not found")
        #expect(ExceptionReason.packageDamaged.displayText == "Package damaged")
    }
}
