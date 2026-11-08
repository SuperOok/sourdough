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
        XCTAssertTrue(app.staticTexts["Noch nicht eingerichtet"].exists)
    }

    func testTheEquipmentOptionOpensTheOverview() {
        launch()
        openEquipment()
        XCTAssertEqual(element(app.buttons, "equipment-edit").label, "Einrichten")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        _ = element(app.buttons, "start-equipment")
    }
}
