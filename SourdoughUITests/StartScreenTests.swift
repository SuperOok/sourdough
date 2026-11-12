import XCTest

/// The splash animation and the start screen.
@MainActor
final class StartScreenTests: SourdoughUITestCase {
    func testTheSplashComesFirstAndGivesWayToTheStartScreen() {
        launch(skipSplash: false, splashSeconds: 4)
        element(app.staticTexts, "splash")
        _ = element(app.buttons, "start-equipment")
        XCTAssertTrue(app.staticTexts["splash"].waitForNonExistence(timeout: 10))
    }

    func testSkippingTheSplashShowsTheStartScreenAtOnce() {
        launch()
        _ = element(app.buttons, "start-equipment")
        XCTAssertFalse(app.staticTexts["splash"].exists)
    }

    func testTheStartScreenShowsThePictureAndTheOptions() {
        launch()
        element(app.otherElements, "start-hero")
        XCTAssertTrue(element(app.buttons, "start-equipment").isHittable)
        XCTAssertTrue(element(app.buttons, "start-tips").isHittable)
        XCTAssertTrue(app.staticTexts["Noch nichts angelegt"].exists)
    }

    func testTheHeadlineSitsInOneLineWithinTheScreenAndNoLargeTitleIsLeft() {
        launch()
        let title = element(app.staticTexts, "start-title")
        XCTAssertEqual(title.label, "Backen mit Sauerteig")
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(title.frame.minX, window.minX)
        XCTAssertLessThanOrEqual(title.frame.maxX, window.maxX)
        // One line, shrunk to the width: a few dozen points high, not two lines of 120.
        XCTAssertLessThan(title.frame.height, 150)
        XCTAssertGreaterThan(title.frame.height, 20)
        XCTAssertTrue(title.isHittable)
        // The old large navigation title is gone.
        XCTAssertFalse(app.navigationBars["Sourdough"].exists)
        XCTAssertFalse(app.staticTexts["Sourdough"].exists)
    }

    func testTheEquipmentOptionOpensTheOverview() {
        launch()
        openEquipment()
        XCTAssertEqual(text("equipment-empty").label, "Noch keine Utensilien angelegt.")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        _ = element(app.buttons, "start-equipment")
    }
}
