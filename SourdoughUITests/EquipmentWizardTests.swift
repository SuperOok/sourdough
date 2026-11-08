import XCTest

/// The wizard itself: its steps, its details and what it saves from a blank
/// start. Whole-journey and seeded cases live in `EquipmentSavedTests`.
@MainActor
final class EquipmentWizardTests: SourdoughUITestCase {
    private func start() {
        launch()
        openEquipment()
    }

    func testNothingIsSetUpAtFirst() {
        start()
        XCTAssertEqual(text("equipment-empty").label, "Noch nichts eingerichtet.")
    }

    func testTheWizardWalksThroughFourStepsAndBack() {
        start()
        tapButton("equipment-edit")
        assertStep("Küchenmaschine")
        XCTAssertFalse(element(app.buttons, "wizard-back").isEnabled)
        XCTAssertTrue(app.staticTexts["Schritt 1 von 4"].exists)
        next()
        assertStep("Bräter oder Römertopf")
        next()
        assertStep("Kastenform")
        next()
        assertStep("Gärkörbchen")
        XCTAssertFalse(app.buttons["wizard-next"].exists)
        XCTAssertTrue(element(app.buttons, "wizard-save").isEnabled)
        tapButton("wizard-back")
        assertStep("Kastenform")
    }

    func testDetailsAppearOnlyWhileThePartIsSwitchedOn() {
        start()
        tapButton("equipment-edit")
        next()
        XCTAssertFalse(app.switches["toggle-pot-liner"].exists)
        flip("toggle-pot", to: true)
        element(app.switches, "toggle-pot-liner")
        flip("toggle-pot", to: false)
        XCTAssertTrue(app.switches["toggle-pot-liner"].waitForNonExistence(timeout: 5))
        next()
        XCTAssertFalse(app.segmentedControls["pan-material"].exists)
        flip("toggle-pan", to: true)
        element(app.segmentedControls, "pan-material")
        element(app.switches, "toggle-pan-lid")
        element(app.switches, "toggle-pan-liner")
    }

    func testPlainVariantsAreShownAsWithout() {
        start()
        tapButton("equipment-edit")
        next()
        flip("toggle-pot", to: true)
        next()
        flip("toggle-pan", to: true)
        next()
        tapButton("wizard-save")
        XCTAssertEqual(text("equipment-pot").label, "Bräter/Römertopf ohne Silikoneinlage")
        XCTAssertEqual(text("equipment-pan").label,
                       "Kastenform aus Blech, ohne Deckel, ohne Silikoneinlage")
        XCTAssertFalse(app.staticTexts["equipment-kneader"].exists)
        XCTAssertFalse(app.staticTexts["equipment-basket"].exists)
    }

    func testSavingWithNothingOwnedIsRememberedAsSetUp() {
        start()
        tapButton("equipment-edit")
        next(); next(); next()
        tapButton("wizard-save")
        XCTAssertEqual(text("equipment-empty").label, "Du hast keine Utensilien angegeben.")
        XCTAssertEqual(element(app.buttons, "equipment-edit").label, "Ändern")
    }

    func testCancellingThrowsTheDraftAway() {
        start()
        tapButton("equipment-edit")
        flip("toggle-kneader", to: true)
        tapButton("wizard-cancel")
        XCTAssertEqual(text("equipment-empty").label, "Noch nichts eingerichtet.")
        XCTAssertEqual(element(app.buttons, "equipment-edit").label, "Einrichten")
    }
}
