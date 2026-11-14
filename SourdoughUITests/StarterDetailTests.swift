import XCTest

/// One starter: state, feeding, storage, deleting. Starts from the demo
/// starters: a rye starter in the fridge that rests, a wheat
/// starter at room temperature that is long overdue and a young rye starter
/// on day 4 of its establishing phase with one doubling.
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
        // In the fridge at 5 °C, fed an hour ago: resting.
        assertText("detail-state", "Ruht")
        XCTAssertEqual(text("detail-hint").label, "Im Kühlschrank ruht er. Vor dem Backen einmal auffrischen.")
        // Angesetzt vor 10 Tagen.
        XCTAssertTrue(text("detail-age").label.hasPrefix("10 Tage"), text("detail-age").label)
        XCTAssertTrue(app.staticTexts["Angesetzt vor"].exists)
        XCTAssertFalse(app.staticTexts["detail-phase"].exists)
        XCTAssertTrue(app.staticTexts["Auffrischen ab"].exists)
        XCTAssertNotEqual(text("detail-feedby").label, "—")
        XCTAssertNotEqual(text("detail-refresh-twice").label, "—")
        XCTAssertFalse(app.staticTexts["detail-window"].exists)
        // Why: 7 days × 3^(−0.1) ≈ 150.5 h = 6 days 6 h, 21 days × 0.896 ≈ 451.6 h = 18 days 19 h.
        assertLabel("detail-why", contains: "Bei 5 °C im Kühlschrank")
        assertLabel("detail-why", contains: "nach etwa 6 Tage 6 Std. und zweimal Auffrischen vor dem Backen "
                    + "nach etwa 18 Tage 19 Std.")
        assertLabel("detail-check", contains: "Riecht er angenehm säuerlich")
        XCTAssertEqual(element(app.textFields, "detail-fridge-temp").value as? String, "5")
        XCTAssertFalse(app.staticTexts["detail-fridge-error"].exists)
        XCTAssertTrue(text("feeding-0").label.hasSuffix("20 g Starter + 50 g Mehl + 50 g Wasser"))
    }

    func testAnOverdueStarterAtRoomTemperature() {
        open("Weizensauerteig")
        assertText("detail-state", "Lange nicht gefüttert")
        XCTAssertEqual(text("detail-hint").label, "Erst auffrischen, dann verwenden.")
        XCTAssertFalse(app.textFields["detail-fridge-temp"].exists)
        // Wheat at 22 °C, 20 + 50 + 50 (1 : 2,5 : 2,5): dilution 6, log2 6 ≈ 2.585
        // doublings of 3 h ≈ 7.75 h = 7 h 45 min to the peak.
        assertLabel("detail-why", contains: "Bei 22 °C und einem Verhältnis von 1 : 2,5 : 2,5")
        assertLabel("detail-why", contains: "Höhepunkt nach etwa 7 Std. 45 Min.")
    }

    func testFeedingStartsTheCycleAgain() {
        open("Weizensauerteig")
        tapButton("detail-feed")
        // The sheet says which starter is fed.
        assertLabel("feed-name", contains: "Weizensauerteig")
        // The sheet starts with the amounts of the last feeding.
        XCTAssertEqual(element(app.textFields, "feed-starter").value as? String, "20")
        XCTAssertEqual(element(app.textFields, "feed-flour").value as? String, "50")
        XCTAssertEqual(element(app.textFields, "feed-water").value as? String, "50")
        // A starter past its establishing phase is not asked how far it rose.
        XCTAssertFalse(app.segmentedControls["feed-rise"].exists)
        replaceText("feed-flour", with: "40")
        tapButton("feed-save")
        assertText("detail-state", "Reift")
        XCTAssertTrue(text("feeding-0").label.hasSuffix("20 g Starter + 40 g Mehl + 50 g Wasser"))
        XCTAssertTrue(text("feeding-1").label.hasSuffix("20 g Starter + 50 g Mehl + 50 g Wasser"))
    }

    func testAYoungStarterShowsItsEstablishingPhase() {
        open("Junger Roggensauerteig")
        // Mixed 3.5 days ago at 22 °C: day 4, the quiet phase (3 to 5 days).
        assertText("detail-state", "Ansetzphase · Tag 4")
        assertText("detail-phase", "Ruhephase")
        XCTAssertEqual(text("detail-hint").label, "Er wirkt fast tot, das ist normal. Füttere ihn weiter jeden Tag.")
        assertText("detail-doubled", "1 von 2")
        XCTAssertNotEqual(text("detail-feedby").label, "—")
        XCTAssertNotEqual(text("detail-ready-by").label, "—")
        XCTAssertFalse(app.staticTexts["detail-window"].exists)
        _ = text("detail-establishing-note")
        XCTAssertTrue(text("feeding-0").label.hasSuffix("· verdoppelt"), text("feeding-0").label)
    }

    /// The rise is asked only in the establishing phase; the second doubling
    /// in a row makes the starter ready.
    func testTwoDoublingsInARowMakeAYoungStarterReady() {
        open("Junger Roggensauerteig")
        tapButton("detail-feed")
        let save = element(app.buttons, "feed-save")
        // Without an answer it cannot be saved.
        assertText("feed-rise-hint", "Wähle, wie weit er aufgegangen ist, dann lässt sich speichern.")
        XCTAssertFalse(save.isEnabled)
        element(app.segmentedControls, "feed-rise").buttons["Verdoppelt"].tap()
        assertText("feed-rise-hint", "Nach zwei Mal „Verdoppelt“ hintereinander ist er bereit.")
        XCTAssertTrue(save.isEnabled)
        tapButton("feed-save")
        // Ready: the normal estimate, just fed, and since when it is ready.
        assertText("detail-state", "Reift")
        XCTAssertNotEqual(text("detail-ready").label, "—")
        XCTAssertFalse(app.staticTexts["detail-phase"].exists)
        XCTAssertNotEqual(text("detail-window").label, "—")
        // The next feeding asks no more.
        tapButton("detail-feed")
        _ = element(app.textFields, "feed-starter")
        XCTAssertFalse(app.segmentedControls["feed-rise"].exists)
        tapButton("feed-cancel")

        relaunch()
        openStarters()
        XCTAssertTrue(element(app.buttons, "starter-row-Junger Roggensauerteig").label.contains("Roggen · Reift"))
    }

    func testARiseThatFallsShortKeepsTheStarterInItsEstablishingPhase() {
        open("Junger Roggensauerteig")
        tapButton("detail-feed")
        element(app.segmentedControls, "feed-rise").buttons["Etwas"].tap()
        tapButton("feed-save")
        assertText("detail-doubled", "0 von 2")
        assertText("detail-state", "Ansetzphase · Tag 4")
        XCTAssertTrue(text("feeding-0").label.hasSuffix("· etwas aufgegangen"), text("feeding-0").label)
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

    func testAStarterAtRoomTemperatureHasItsOwnTemperature() {
        open("Weizensauerteig")
        XCTAssertEqual(element(app.textFields, "detail-room-temp").value as? String, "22")
        XCTAssertFalse(app.textFields["detail-fridge-temp"].exists)
        let at22 = text("detail-feedby").label
        replaceText("detail-room-temp", with: "40")
        assertText("detail-room-error", "Die Raumtemperatur liegt meist zwischen 10 und 35 °C.")
        // Colder: everything takes longer, the deadline moves.
        replaceText("detail-room-temp", with: "18")
        XCTAssertTrue(app.staticTexts["detail-room-error"].waitForNonExistence(timeout: 5))
        XCTAssertNotEqual(text("detail-feedby").label, at22)
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

    func testTheDetailHasTipsOnTheStarter() {
        open("Roggensauerteig")
        tapButton("detail-tips")
        assertTitle("Sauerteigstarter")
        tapButton("tips-topic-close")
        assertText("detail-state", "Ruht")
    }
}
