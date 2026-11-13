import XCTest

/// Tips and tricks: reachable from every screen, and "Fertig" always returns
/// to the screen it was opened from, in the state it was left.
@MainActor
final class TipsTests: SourdoughUITestCase {
    func testTheStartScreenOpensTheContentsAndPagesCanBeRead() {
        launch()
        tapButton("start-tips")
        XCTAssertTrue(app.navigationBars["Tipps und Tricks"].firstMatch.waitForExistence(timeout: 10))
        for id in ["kneader", "pot", "pan", "basket", "starter"] {
            XCTAssertTrue(element(app.buttons, "tips-topic-\(id)").exists)
        }
        // The ingredients and the schedule further down.
        app.swipeUp()
        for id in ["flours", "wheat", "rye", "spelt", "seeds", "nuts", "driedFruit", "roastedOnions", "herbs",
                   "temperature", "schedule"] {
            XCTAssertTrue(element(app.buttons, "tips-topic-\(id)").exists, id)
        }
        // The pages about the screens of the app come last.
        for id in ["start", "planFlours", "planSetup", "planSchedule", "run", "log", "logDetail", "equipmentList",
                   "starterNew", "starterFeed"] {
            XCTAssertTrue(element(app.buttons, "tips-topic-\(id)").exists, id)
        }
        app.swipeDown()
        app.swipeDown()
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

    func testTheBannetonPageShowsItsPhoto() {
        launch()
        tapButton("start-tips")
        tapButton("tips-topic-basket")
        assertTitle("Gärkörbchen")
        XCTAssertEqual(any("tips-image-BasketPhoto").label, "Ein rundes und ein längliches Gärkörbchen mit Teig")
    }

    func testTheRyePageShowsMyOwnPhoto() {
        launch()
        tapButton("start-tips")
        tapButton("tips-topic-rye")
        assertTitle("Roggen")
        XCTAssertEqual(any("tips-image-RyePhoto").label, "Roggenähren. Foto: Roger Culos, CC BY-SA 3.0, via Wikimedia Commons.")
        app.swipeUp()
        XCTAssertEqual(any("tips-image-RyeBreadPhoto").label,
                       "Roggenmischbrot aus der Kastenform, frisch angeschnitten. Eigenes Foto.")
    }

    func testTheKneadingPageShowsThePhotoAndTheAnimation() {
        launch()
        tapButton("start-tips")
        tapButton("tips-topic-kneading")
        assertTitle("Kneten")
        XCTAssertEqual(any("tips-image-KneadingPhoto").label,
                       "Krume bei zu kurz, richtig und zu lang geknetetem Teig")
        app.swipeUp()
        app.swipeUp()
        app.swipeUp()
        XCTAssertEqual(any("tips-animation-stretchFold").label,
                       "Dehnen und Falten: Teig an einer Seite greifen, hochziehen, zur Mitte falten, "
                       + "Schüssel eine Vierteldrehung drehen")
    }

    func testTheWheatPageLinksToKneading() {
        launch()
        tapButton("start-tips")
        tapButton("tips-topic-wheat")
        assertTitle("Weizen")
        element(app.links, "Kneten").tap()
        assertTitle("Kneten")
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
        assertTitle("Backutensilien verwalten")
        // The page leads on to the pages of the kinds.
        element(app.links, "Kastenform").tap()
        assertTitle("Kastenform")
        tapButton("tips-topic-close")
        _ = element(app.buttons, "equipment-add")
    }
}
