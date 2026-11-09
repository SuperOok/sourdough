import XCTest

/// One starter: state, feeding, storage, deleting. Starts from the demo
/// starters: a rye starter in the fridge that is still rising and a wheat
/// starter at room temperature that is long overdue.
@MainActor
final class StarterDetailTests: SourdoughUITestCase {
    private func open(_ name: String) {
        launch(seedStarters: true)
        openStarters()
        element(app.buttons, "starter-row-\(name)").tap()
        _ = element(app.buttons, "detail-feed")
    }

    func testTheDetailShowsStateDatesAndStorage() {
        open("Roggensauerteig")
        assertText("detail-state", "Reift")
        XCTAssertEqual(text("detail-hint").label, "Der Starter geht noch auf.")
        // Angesetzt vor 10 Tagen.
        XCTAssertTrue(text("detail-age").label.hasPrefix("10 Tage"), text("detail-age").label)
        XCTAssertNotEqual(text("detail-feedby").label, "—")
        XCTAssertNotEqual(text("detail-window").label, "—")
        XCTAssertEqual(element(app.textFields, "detail-fridge-temp").value as? String, "5")
        XCTAssertFalse(app.staticTexts["detail-fridge-error"].exists)
        XCTAssertTrue(text("feeding-0").label.hasSuffix("20 g Starter + 50 g Mehl + 50 g Wasser"))
    }

    func testAnOverdueStarterAtRoomTemperature() {
        open("Weizensauerteig")
        assertText("detail-state", "Lange nicht gefüttert")
        XCTAssertEqual(text("detail-hint").label, "Erst auffrischen, dann verwenden.")
        XCTAssertFalse(app.textFields["detail-fridge-temp"].exists)
    }

    func testFeedingStartsTheCycleAgain() {
        open("Weizensauerteig")
        tapButton("detail-feed")
        // The sheet starts with the amounts of the last feeding.
        XCTAssertEqual(element(app.textFields, "feed-starter").value as? String, "20")
        XCTAssertEqual(element(app.textFields, "feed-flour").value as? String, "50")
        XCTAssertEqual(element(app.textFields, "feed-water").value as? String, "50")
        replaceText("feed-flour", with: "40")
        tapButton("feed-save")
        assertText("detail-state", "Reift")
        XCTAssertTrue(text("feeding-0").label.hasSuffix("20 g Starter + 40 g Mehl + 50 g Wasser"))
        XCTAssertTrue(text("feeding-1").label.hasSuffix("20 g Starter + 50 g Mehl + 50 g Wasser"))
    }

    func testCancellingAFeedingChangesNothing() {
        open("Weizensauerteig")
        tapButton("detail-feed")
        tapButton("feed-cancel")
        assertText("detail-state", "Lange nicht gefüttert")
        XCTAssertFalse(app.staticTexts["feeding-1"].exists)
    }

    func testTheFeedingFormRejectsWrongInput() {
        open("Weizensauerteig")
        tapButton("detail-feed")
        let save = element(app.buttons, "feed-save")
        XCTAssertTrue(save.isEnabled)
        replaceText("feed-flour", with: "0")
        replaceText("feed-water", with: "0")
        assertText("feed-error", "Mehl und Wasser dürfen nicht beide 0 sein.")
        XCTAssertFalse(save.isEnabled)
    }

    func testTheFridgeTemperatureCanBeChangedAndIsRemembered() {
        open("Roggensauerteig")
        replaceText("detail-fridge-temp", with: "12")
        XCTAssertFalse(app.staticTexts["detail-fridge-error"].exists)
        // A wrong value is flagged and not saved.
        replaceText("detail-fridge-temp", with: "20")
        assertText("detail-fridge-error", "Die Kühlschranktemperatur liegt meist zwischen 0 und 15 °C.")
        replaceText("detail-fridge-temp", with: "12")
        XCTAssertTrue(app.staticTexts["detail-fridge-error"].waitForNonExistence(timeout: 5))

        relaunch()
        openStarters()
        element(app.buttons, "starter-row-Roggensauerteig").tap()
        XCTAssertEqual(element(app.textFields, "detail-fridge-temp").value as? String, "12")
    }

    func testMovingTheStarterOutOfTheFridgeBringsTheDeadlineForward() {
        open("Roggensauerteig")
        let inFridge = text("detail-feedby").label
        element(app.segmentedControls, "detail-storage").buttons["Raumtemperatur"].tap()
        XCTAssertTrue(app.textFields["detail-fridge-temp"].waitForNonExistence(timeout: 5))
        XCTAssertNotEqual(text("detail-feedby").label, inFridge)
        // And back: the fridge field returns with the saved value.
        element(app.segmentedControls, "detail-storage").buttons["Kühlschrank"].tap()
        XCTAssertEqual(element(app.textFields, "detail-fridge-temp").value as? String, "5")
        XCTAssertEqual(text("detail-feedby").label, inFridge)
    }

    func testDeletingAsksFirstAndRemovesTheStarter() {
        open("Weizensauerteig")
        tapButton("detail-delete")
        tapButton("Abbrechen")
        assertText("detail-state", "Lange nicht gefüttert")
        tapButton("detail-delete")
        tapButton("Löschen")
        _ = element(app.buttons, "starter-add")
        XCTAssertTrue(app.buttons["starter-row-Weizensauerteig"].waitForNonExistence(timeout: 5))
        _ = element(app.buttons, "starter-row-Roggensauerteig")
    }

    func testTheDetailHasTipsOnTheCalculation() {
        open("Roggensauerteig")
        tapButton("detail-tips")
        assertTitle("So wird der Zustand berechnet")
        tapButton("tips-topic-close")
        assertText("detail-state", "Reift")
    }
}
