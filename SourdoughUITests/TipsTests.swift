import XCTest

/// Tips and tricks: reachable from every screen, and "Fertig" always returns
/// to the screen it was opened from, in the state it was left.
@MainActor
final class TipsTests: SourdoughUITestCase {
    func testTheStartScreenOpensTheContentsAndPagesCanBeRead() {
        launch()
        tapButton("start-tips")
        XCTAssertTrue(app.navigationBars["Tipps und Tricks"].firstMatch.waitForExistence(timeout: 10))
        for id in ["kneader", "pot", "pan", "basket", "starter", "starterStates"] {
            XCTAssertTrue(element(app.buttons, "tips-topic-\(id)").exists)
        }
        tapButton("tips-topic-pot")
        assertTitle("Bräter und Römertopf")
        // A link inside the text leads to another page.
        element(app.links, "Kastenform").tap()
        assertTitle("Kastenform")
        // Back to the pot page, back to the contents.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        assertTitle("Bräter und Römertopf")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tapButton("tips-close")
        _ = element(app.buttons, "start-tips")
    }

    func testClosingFromAPageReturnsToTheStartScreen() {
        launch()
        tapButton("start-tips")
        tapButton("tips-topic-basket")
        assertTitle("Gärkörbchen")
        tapButton("tips-topic-close")
        _ = element(app.buttons, "start-equipment")
        XCTAssertFalse(app.buttons["tips-topic-basket"].exists)
    }

    func testTheEquipmentOverviewHasTips() {
        launch()
        openEquipment()
        tapButton("tips-button")
        _ = element(app.buttons, "tips-topic-pan")
        tapButton("tips-close")
        _ = element(app.buttons, "equipment-add")
    }
}
