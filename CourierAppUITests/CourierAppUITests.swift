import XCTest

@MainActor
final class CourierAppUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    func testLaunchLoadsTheShiftAndShowsThreeTabs() throws {
        XCTAssertTrue(app.buttons["dashboard.startShiftButton"].waitForExistence(timeout: 10.0))
        XCTAssertEqual(app.tabBars.buttons.count, 3)
    }

    func testDeliveryFlowStartsDeliversAndUndoes() throws {
        app.buttons["dashboard.startShiftButton"].tap()

        let firstRow = app.buttons["dashboard.taskRow.task-01"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10.0))
        firstRow.tap()

        let startButton = app.buttons["delivery.startButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5.0))
        startButton.tap()

        let markDeliveredButton = app.buttons["delivery.markDeliveredButton"]
        XCTAssertTrue(markDeliveredButton.waitForExistence(timeout: 5.0))
        markDeliveredButton.tap()

        let undoButton = app.buttons["delivery.undoButton"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 5.0))
        undoButton.tap()

        XCTAssertTrue(app.buttons["delivery.markDeliveredButton"].waitForExistence(timeout: 5.0))
    }

    func testDoneCommitsDeliveryAndReturnsToDashboard() throws {
        app.buttons["dashboard.startShiftButton"].tap()
        app.buttons["dashboard.taskRow.task-01"].tap()
        app.buttons["delivery.startButton"].tap()
        app.buttons["delivery.markDeliveredButton"].tap()
        app.buttons["delivery.doneButton"].tap()

        XCTAssertTrue(app.buttons["dashboard.endShiftButton"].waitForExistence(timeout: 5.0))
        XCTAssertFalse(app.buttons["dashboard.taskRow.task-01"].exists)
    }

    func testCompletedDeliveryAppearsInHistory() throws {
        app.buttons["dashboard.startShiftButton"].tap()
        app.buttons["dashboard.taskRow.task-01"].tap()
        app.buttons["delivery.startButton"].tap()
        app.buttons["delivery.markDeliveredButton"].tap()
        app.buttons["delivery.doneButton"].tap()

        app.tabBars.buttons["History"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["history.row.task-01"].waitForExistence(timeout: 5.0))
    }

    func testExceptionWithOtherRequiresDetailsAndReturnsToDashboard() throws {
        app.buttons["dashboard.startShiftButton"].tap()
        app.buttons["dashboard.taskRow.task-01"].tap()
        app.buttons["delivery.startButton"].tap()
        app.buttons["delivery.reportExceptionButton"].tap()

        app.buttons["delivery.exception.option.other"].tap()
        let saveButton = app.buttons["delivery.exception.saveButton"]
        XCTAssertFalse(saveButton.isEnabled)

        let detailsField = app.textFields["delivery.exception.detailsField"]
        detailsField.tap()
        detailsField.typeText("Gate locked")
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.buttons["dashboard.endShiftButton"].waitForExistence(timeout: 5.0))
    }

    func testSettingsShowsSimulationControls() throws {
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.switches["settings.offlineToggle"].waitForExistence(timeout: 5.0))
        XCTAssertTrue(app.buttons["settings.syncNowButton"].exists)
    }
}
