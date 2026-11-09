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

    /// The whole journey: add, see the state, see the log, restart the app.
    func testAddingAStarterShowsItsStateAndSurvivesRestartingTheApp() {
        launch()
        openStarters()
        add()
        replaceText("add-flour-grams", with: "60")
        replaceText("add-water-grams", with: "40")
        replaceText("add-fridge-temp", with: "7")
        element(app.textFields, "add-name").tap()
        element(app.textFields, "add-name").typeText("Opa")
        element(app.segmentedControls, "add-flour").buttons["Weizen"].tap()
        tapButton("add-save")

        XCTAssertTrue(row("Opa").label.contains("Weizen · Reift"), row("Opa").label)
        row("Opa").tap()
        assertText("detail-state", "Reift")
        XCTAssertNotEqual(text("detail-feedby").label, "—")
        XCTAssertNotEqual(text("detail-window").label, "—")
        XCTAssertTrue(text("feeding-0").label.hasSuffix("Ansatz: 60 g Mehl + 40 g Wasser"))
        XCTAssertEqual(element(app.textFields, "detail-fridge-temp").value as? String, "7")

        relaunch()
        XCTAssertTrue(app.staticTexts["1 angelegt"].waitForExistence(timeout: 10))
        openStarters()
        XCTAssertTrue(row("Opa").label.contains("Weizen"))
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
        XCTAssertTrue(app.staticTexts["2 angelegt"].waitForExistence(timeout: 10))
        openStarters()
        XCTAssertTrue(row("Roggensauerteig").label.contains("Roggen · Reift"), row("Roggensauerteig").label)
        XCTAssertTrue(row("Weizensauerteig").label.contains("Weizen · Lange nicht gefüttert"),
                      row("Weizensauerteig").label)
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
