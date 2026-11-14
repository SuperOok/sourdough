import XCTest

/// Every screen has a lightbulb that opens the page about that screen, and
/// "Fertig" returns to the screen. The pages of single flours, utensils and
/// terms behind the small bulbs in the rows are tested with their screens.
@MainActor
final class ScreenTipsTests: SourdoughUITestCase {
    /// Opens the page behind the bulb `id`, checks its title and closes it.
    private func assertPage(bulb id: String, title: String, line: UInt = #line) {
        tapButton(id)
        assertTitle(title, line: line)
        tapButton("tips-topic-close")
        XCTAssertTrue(app.staticTexts["tips-title"].waitForNonExistence(timeout: 5),
                      "Die Seite \(title) blieb offen.", line: line)
    }

    func testTheStartScreenHasAWelcomePageWithTheVersionAndTheFontCredit() {
        launch()
        tapButton("start-tips-bulb")
        assertTitle("Willkommen")
        // The line comes from the bundle of the app under test: "Version 1.2 (1)".
        let version = text("tips-version")
        XCTAssertTrue(version.label.hasPrefix("Version "), version.label)
        XCTAssertFalse(version.label.contains("unbekannt"), version.label)
        XCTAssertTrue(version.label.hasSuffix(")"), version.label)
        assertText("tips-font-credit", "Schrift: Caveat, The Caveat Project Authors, SIL OFL 1.1")
        // A link of the page leads on, here to the page about the log.
        element(app.links, "Backprotokoll").tap()
        assertTitle("Das Backprotokoll")
        tapButton("tips-topic-close")
        _ = element(app.buttons, "start-equipment")
        // The card "Tipps und Tricks" still opens the whole contents.
        tapButton("start-tips")
        XCTAssertTrue(app.navigationBars["Tipps und Tricks"].firstMatch.waitForExistence(timeout: 10))
        tapButton("tips-close")
        _ = element(app.buttons, "start-tips-bulb")
    }

    func testTheThreePlanningStepsHaveTheirOwnPages() {
        launch(seedEquipment: true, now: Self.friday)
        openBake()
        assertPage(bulb: "tips-button", title: "Mehle wählen")
        tapButton("plan-next")
        _ = element(app.buttons, "setup-next")
        assertPage(bulb: "tips-button", title: "Utensilien und Menge")
        tapButton("setup-next")
        _ = element(app.datePickers, "schedule-time")
        assertPage(bulb: "tips-button", title: "Zeitplan einstellen")
        // Still on the schedule.
        _ = element(app.buttons, "schedule-reset")
    }

    func testTheLogAndAnEntryOfItHaveTheirOwnPages() {
        launch(seedEquipment: true, seedStarters: true, now: Self.friday, seedRun: "finished")
        tapButton("start-log")
        assertPage(bulb: "tips-button", title: "Das Backprotokoll")
        tapButton("log-row-0")
        _ = element(app.buttons, "log-delete")
        assertPage(bulb: "tips-button", title: "Ein Durchgang im Protokoll")
        _ = element(app.buttons, "log-delete")
        // The list is still on the page about the list after coming back.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        assertPage(bulb: "tips-button", title: "Das Backprotokoll")
    }

    func testTheEquipmentListHasItsOwnPage() {
        launch()
        openEquipment()
        assertPage(bulb: "tips-button", title: "Backutensilien verwalten")
    }

    func testTheStarterFormsHaveTheirOwnPages() {
        launch(seedStarters: true)
        openStarters()
        // The list and the detail screen both show the page about starters.
        assertPage(bulb: "tips-button", title: "Sauerteigstarter")
        tapButton("starter-add")
        assertPage(bulb: "add-tips", title: "Neuen Starter anlegen")
        tapButton("add-cancel")
        element(app.buttons, "starter-row-Roggensauerteig").tap()
        assertPage(bulb: "detail-tips", title: "Sauerteigstarter")
        tapButton("detail-feed")
        assertPage(bulb: "feed-tips", title: "Starter füttern")
        tapButton("feed-cancel")
        _ = element(app.buttons, "detail-feed")
    }
}
