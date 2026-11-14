import XCTest

/// The starter list: adding a starter, its form, the demo starters.
@MainActor
final class StarterListTests: SourdoughUITestCase {
    private func row(_ name: String) -> XCUIElement { element(app.buttons, "starter-row-\(name)") }

    private func add() { tapButton("starter-add") }

    func testTheStartScreenOffersTheStarters() {
        launch()
        XCTAssertTrue(element(app.buttons, "start-starters").isHittable)
        XCTAssertTrue(app.staticTexts["Noch keiner angelegt"].exists)
    }

    func testTheListIsEmptyAtFirst() {
        launch()
        openStarters()
        XCTAssertEqual(text("starters-empty").label, "Du hast noch keinen Starter angelegt.")
    }

    /// The whole journey for a starter received from someone: add, see the
    /// state, see the log, restart the app.
    func testAddingAnExistingStarterShowsItsStateAndSurvivesRestartingTheApp() {
        launch()
        openStarters()
        add()
        // "Schon vorhanden" is the first way: no flour and water to give.
        assertExact("add-origin", "Wie entsteht er?, Schon vorhanden")
        XCTAssertFalse(app.textFields["add-flour-grams"].exists)
        replaceText("add-amount", with: "120")
        replaceText("add-fridge-temp", with: "7")
        element(app.textFields, "add-name").tap()
        element(app.textFields, "add-name").typeText("Opa")
        element(app.segmentedControls, "add-flour").buttons["Weizen"].tap()
        tapButton("add-save")

        // Fed just now, in the fridge: resting.
        XCTAssertTrue(row("Opa").label.contains("Weizen · Ruht"), row("Opa").label)
        row("Opa").tap()
        assertText("detail-state", "Ruht")
        XCTAssertTrue(app.staticTexts["Bei dir seit"].exists)
        XCTAssertNotEqual(text("detail-refresh-twice").label, "—")
        XCTAssertTrue(text("feeding-0").label.hasSuffix("Übernommen: 120 g, Fütterung geschätzt"),
                      text("feeding-0").label)
        XCTAssertEqual(element(app.textFields, "detail-fridge-temp").value as? String, "7")
        // The first own feeding keeps what was received.
        tapButton("detail-feed")
        XCTAssertEqual(element(app.textFields, "feed-starter").value as? String, "120")
        XCTAssertFalse(app.segmentedControls["feed-rise"].exists)
        tapButton("feed-cancel")

        relaunch()
        XCTAssertTrue(app.staticTexts["1 angelegt"].waitForExistence(timeout: 10))
        openStarters()
        XCTAssertTrue(row("Opa").label.contains("Weizen · Ruht"), row("Opa").label)
    }

    func testAnExistingStarterWithoutAKnownFeedingWaitsForTheFirstOne() {
        launch()
        openStarters()
        add()
        flip("add-known", to: false)
        XCTAssertTrue(app.textFields["add-amount"].waitForNonExistence(timeout: 5))
        assertText("add-known-hint", "Bis zu deiner ersten Fütterung schätzt die App keinen Zustand.")
        tapButton("add-save")
        XCTAssertTrue(row("Roggensauerteig").label.contains("Roggen · Noch nicht gefüttert"),
                      row("Roggensauerteig").label)
    }

    func testAddingAStarterWithASampleKeepsTheSampleAndSurvivesRestartingTheApp() {
        launch()
        openStarters()
        add()
        choose("add-origin", "Mit Anstellgut ansetzen")
        XCTAssertFalse(app.textFields["add-amount"].exists)
        replaceText("add-sample", with: "15")
        replaceText("add-flour-grams", with: "60")
        replaceText("add-water-grams", with: "40")
        tapButton("add-save")
        XCTAssertTrue(row("Roggensauerteig").label.contains("Roggen · Ruht"), row("Roggensauerteig").label)
        row("Roggensauerteig").tap()
        // Above the log, which may be scrolled to and push the state section away.
        XCTAssertTrue(app.staticTexts["Angesetzt vor"].waitForExistence(timeout: 5))
        XCTAssertTrue(text("feeding-0").label.hasSuffix("15 g Starter + 60 g Mehl + 40 g Wasser"),
                      text("feeding-0").label)

        relaunch()
        openStarters()
        row("Roggensauerteig").tap()
        XCTAssertTrue(text("feeding-0").label.hasSuffix("15 g Starter + 60 g Mehl + 40 g Wasser"))
    }

    func testAddingASpontaneousStarterStartsItsEstablishingPhaseAndSurvivesRestartingTheApp() {
        launch()
        openStarters()
        add()
        choose("add-origin", "Spontan ansetzen")
        XCTAssertFalse(app.textFields["add-sample"].exists)
        // A spontaneous mix is kept warm: room temperature, 22 °C, no hint.
        _ = element(app.textFields, "add-room-temp")
        XCTAssertFalse(app.staticTexts["add-cold-hint"].exists)
        replaceText("add-room-temp", with: "18")
        assertText("add-cold-hint", "Unter 22 °C dauert jede Phase länger. Am schnellsten geht es bei 24 bis 28 °C.")
        tapButton("add-scratch-tip")
        assertTitle("Starter selbst ansetzen")
        tapButton("tips-topic-close")
        tapButton("add-save")

        XCTAssertTrue(row("Roggensauerteig").label.contains("Roggen · Ansetzphase · Tag 1"),
                      row("Roggensauerteig").label)
        XCTAssertTrue(row("Roggensauerteig").label.contains("Füttern bis "), row("Roggensauerteig").label)
        row("Roggensauerteig").tap()
        assertText("detail-state", "Ansetzphase · Tag 1")
        assertText("detail-phase", "Frisch angesetzt")
        assertText("detail-doubled", "0 von 2")
        XCTAssertFalse(app.staticTexts["detail-window"].exists)
        XCTAssertTrue(text("feeding-0").label.hasSuffix("Ansatz: 50 g Mehl + 50 g Wasser"))

        relaunch()
        openStarters()
        XCTAssertTrue(row("Roggensauerteig").label.contains("Ansetzphase · Tag 1"), row("Roggensauerteig").label)
    }

    func testTheNameDefaultsToTheFlour() {
        launch()
        openStarters()
        add()
        XCTAssertTrue(element(app.textFields, "add-name").exists)
        element(app.segmentedControls, "add-flour").buttons["Dinkel"].tap()
        tapButton("add-save")
        XCTAssertTrue(row("Dinkelsauerteig").label.contains("Dinkel"))
    }

    func testCancellingAddsNothing() {
        launch()
        openStarters()
        add()
        tapButton("add-cancel")
        XCTAssertEqual(text("starters-empty").label, "Du hast noch keinen Starter angelegt.")
    }

    func testTheFormRejectsWrongInput() {
        launch()
        openStarters()
        add()
        let save = element(app.buttons, "add-save")
        XCTAssertTrue(save.isEnabled)
        XCTAssertFalse(app.staticTexts["add-error"].exists)

        // (Text instead of numbers cannot be typed on the decimal pad; the
        // form model's unit tests cover it.)
        replaceText("add-amount", with: "0")
        assertText("add-error", "Gib an, wie viel Starter du hast.")
        XCTAssertFalse(save.isEnabled)

        choose("add-origin", "Mit Anstellgut ansetzen")
        replaceText("add-sample", with: "0")
        assertText("add-error", "Gib an, wie viel Anstellgut du nimmst. Ohne Probe ist es ein spontaner Ansatz.")
        replaceText("add-sample", with: "20")
        replaceText("add-flour-grams", with: "0")
        replaceText("add-water-grams", with: "0")
        assertText("add-error", "Mehl und Wasser dürfen nicht beide 0 sein.")

        replaceText("add-water-grams", with: "50")
        replaceText("add-fridge-temp", with: "30")
        assertText("add-error", "Die Kühlschranktemperatur liegt meist zwischen 0 und 15 °C.")
        XCTAssertFalse(save.isEnabled)

        // At room temperature the fridge temperature does not matter.
        element(app.segmentedControls, "add-storage").buttons["Raumtemperatur"].tap()
        XCTAssertTrue(app.staticTexts["add-error"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.textFields["add-fridge-temp"].exists)
        XCTAssertTrue(save.isEnabled)
    }

    func testTheDemoStartersAreListedWithTheirStates() {
        launch(seedStarters: true)
        XCTAssertTrue(app.staticTexts["3 angelegt"].waitForExistence(timeout: 10))
        openStarters()
        XCTAssertTrue(row("Roggensauerteig").label.contains("Roggen · Ruht"), row("Roggensauerteig").label)
        XCTAssertTrue(row("Roggensauerteig").label.contains("Auffrischen ab"), row("Roggensauerteig").label)
        XCTAssertTrue(row("Weizensauerteig").label.contains("Weizen · Lange nicht gefüttert"),
                      row("Weizensauerteig").label)
        XCTAssertTrue(row("Junger Roggensauerteig").label.contains("Roggen · Ansetzphase · Tag 4"),
                      row("Junger Roggensauerteig").label)
        XCTAssertFalse(app.staticTexts["starters-empty"].exists)
    }

    func testTheListHasTips() {
        launch()
        openStarters()
        tapButton("tips-button")
        assertTitle("Sauerteigstarter")
        tapButton("tips-topic-close")
        _ = element(app.buttons, "starter-add")
    }
}
