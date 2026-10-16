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
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        startButton.tap()

        let markDeliveredButton = app.buttons["delivery.markDeliveredButton"]
        XCTAssertTrue(markDeliveredButton.waitForExistence(timeout: 5.0))
        markDeliveredButton.tap()

        let undoButton = app.buttons["delivery.undoToast.undoButton"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 5.0))
        undoButton.tap()

        XCTAssertTrue(firstRow.waitForExistence(timeout: 5.0))
        firstRow.tap()
        XCTAssertTrue(app.buttons["delivery.markDeliveredButton"].waitForExistence(timeout: 5.0))
    }

    func testDeliveryReturnsToDashboard() throws {
        app.buttons["dashboard.startShiftButton"].tap()
        app.buttons["dashboard.taskRow.task-01"].tap()
        app.buttons["delivery.startButton"].tap()
        app.buttons["delivery.markDeliveredButton"].tap()

        XCTAssertTrue(app.buttons["dashboard.endShiftButton"].waitForExistence(timeout: 5.0))
        XCTAssertFalse(app.buttons["dashboard.taskRow.task-01"].exists)
    }

    func testCompletedDeliveryAppearsInHistory() throws {
        app.buttons["dashboard.startShiftButton"].tap()
        app.buttons["dashboard.taskRow.task-01"].tap()
        app.buttons["delivery.startButton"].tap()
        app.buttons["delivery.markDeliveredButton"].tap()

        app.tabBars.buttons["Activity"].tap()

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

        XCTAssertTrue(app.buttons["settings.simulatedFailurePicker"].waitForExistence(timeout: 5.0))
        XCTAssertTrue(app.buttons["settings.syncNowButton"].exists)
        XCTAssertFalse(app.buttons["settings.syncNowButton"].isEnabled)
    }

    func testOfflineDeliverySurvivesRelaunchAndSyncsWhenOnline() throws {
        app.terminate()
        app.launchEnvironment["COURIER_UI_TEST_SESSION"] = UUID().uuidString
        app.launch()

        XCTAssertTrue(app.buttons["dashboard.startShiftButton"].waitForExistence(timeout: 10.0))
        app.buttons["dashboard.startShiftButton"].tap()
        app.tabBars.buttons["Settings"].tap()

        let simulationPicker = app.buttons["settings.simulatedFailurePicker"]
        simulationPicker.tap()
        app.buttons["Offline"].tap()
        XCTAssertTrue(simulationPicker.label.contains("Offline"), simulationPicker.debugDescription)

        app.tabBars.buttons["Today"].tap()
        app.buttons["dashboard.taskRow.task-01"].tap()
        app.buttons["delivery.startButton"].tap()
        app.buttons["delivery.markDeliveredButton"].tap()
        app.tabBars.buttons["Activity"].tap()

        let historyRow = app.descendants(matching: .any)["history.row.task-01"]
        XCTAssertTrue(historyRow.waitForExistence(timeout: 5.0))
        XCTAssertTrue(app.staticTexts["Waiting to sync"].waitForExistence(timeout: 5.0))
        app.tabBars.buttons["Settings"].tap()

        let pendingJob = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "settings.job.")
        ).firstMatch
        XCTAssertTrue(pendingJob.waitForExistence(timeout: 5.0))
        let pendingJobIdentifier = pendingJob.identifier

        app.terminate()
        app.launch()

        XCTAssertTrue(app.buttons["dashboard.endShiftButton"].waitForExistence(timeout: 10.0))
        XCTAssertFalse(app.buttons["dashboard.taskRow.task-01"].exists)
        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(historyRow.waitForExistence(timeout: 5.0))
        XCTAssertTrue(app.staticTexts["Delivered"].exists)
        XCTAssertTrue(app.staticTexts["Waiting to sync"].exists)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(simulationPicker.label.contains("Offline"), simulationPicker.debugDescription)
        XCTAssertTrue(app.descendants(matching: .any)[pendingJobIdentifier].waitForExistence(timeout: 5.0))

        simulationPicker.tap()
        app.buttons["None"].tap()

        XCTAssertTrue(app.staticTexts["All caught up"].waitForExistence(timeout: 15.0))
        XCTAssertFalse(pendingJob.exists)
        XCTAssertFalse(app.buttons["settings.syncNowButton"].isEnabled)
        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(historyRow.waitForExistence(timeout: 5.0))
        XCTAssertTrue(app.staticTexts["Delivered"].exists)
        XCTAssertFalse(app.staticTexts["Waiting to sync"].exists)
    }

    func testShiftCanEndAndReopenAfterConfirmation() throws {
        app.buttons["dashboard.startShiftButton"].tap()
        app.buttons["dashboard.endShiftButton"].tap()

        XCTAssertTrue(app.buttons["dashboard.endShiftConfirmButton"].waitForExistence(timeout: 5.0))
        app.buttons["dashboard.endShiftConfirmButton"].firstMatch.tap()
        XCTAssertTrue(app.buttons["dashboard.reopenShiftButton"].waitForExistence(timeout: 5.0))

        app.buttons["dashboard.reopenShiftButton"].tap()
        XCTAssertTrue(app.buttons["dashboard.endShiftButton"].waitForExistence(timeout: 5.0))
    }

    func testEditingStopsReplacesShiftCardWithReorderInstructions() throws {
        app.buttons["dashboard.startShiftButton"].tap()
        XCTAssertTrue(app.buttons["dashboard.endShiftButton"].waitForExistence(timeout: 5.0))

        app.buttons["Edit"].tap()
        XCTAssertFalse(app.buttons["dashboard.endShiftButton"].exists)
        XCTAssertTrue(app.staticTexts["Drag the handles to change the order of your next stops."].exists)

        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["dashboard.endShiftButton"].exists)
    }
}
