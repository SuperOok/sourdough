import XCTest

/// Saved equipment: the one whole journey through the wizard, and the cases
/// that start from equipment seeded with `-seedEquipment all`.
@MainActor
final class EquipmentSavedTests: SourdoughUITestCase {
    private func assertEverythingShown() {
        XCTAssertEqual(text("equipment-kneader").label, "Küchenmaschine mit Knetfunktion")
        XCTAssertEqual(text("equipment-pot").label, "Bräter/Römertopf mit Silikoneinlage")
        XCTAssertEqual(text("equipment-pan").label,
                       "Kastenform aus Gusseisen, mit Deckel, mit Silikoneinlage")
        XCTAssertEqual(text("equipment-basket").label, "Gärkörbchen")
        XCTAssertEqual(element(app.buttons, "equipment-edit").label, "Ändern")
    }

    /// The one end-to-end case: set up everything, see it, restart, see it again.
    func testEverythingSavedIsShownAndSurvivesRestartingTheApp() {
        launch()
        openEquipment()
        tapButton("equipment-edit")
        flip("toggle-kneader", to: true)
        next()
        flip("toggle-pot", to: true)
        flip("toggle-pot-liner", to: true)
        next()
        flip("toggle-pan", to: true)
        element(app.segmentedControls, "pan-material").buttons["Gusseisen"].tap()
        flip("toggle-pan-lid", to: true)
        flip("toggle-pan-liner", to: true)
        next()
        flip("toggle-basket", to: true)
        tapButton("wizard-save")
        assertEverythingShown()
        XCTAssertFalse(app.staticTexts["equipment-empty"].exists)

        relaunch()
        XCTAssertTrue(app.staticTexts["Eingerichtet"]
            .waitForExistence(timeout: 10))
        openEquipment()
        assertEverythingShown()
    }

    func testOwnedItemsHaveASymbolThatLeadsToTheirTips() {
        launch(seed: "all")
        openEquipment()
        tapButton("equipment-tip-pan")
        assertTitle("Kastenform")
        tapButton("tips-topic-close")
        // Back on the overview, which is unchanged.
        assertEverythingShown()
        tapButton("equipment-tip-kneader")
        assertTitle("Küchenmaschine")
        tapButton("tips-topic-close")
    }

    func testNothingIsMissingWhenEverythingIsOwned() {
        launch(seed: "all")
        openEquipment()
        XCTAssertFalse(app.staticTexts["missing-kneader"].exists)
        XCTAssertFalse(app.staticTexts["missing-pot"].exists)
        XCTAssertFalse(app.staticTexts["missing-pan"].exists)
        XCTAssertFalse(app.staticTexts["missing-basket"].exists)
    }

    func testMissingItemsAreListedWithTheirTips() {
        launch(seed: "none")
        openEquipment()
        XCTAssertEqual(text("missing-kneader").label, "Küchenmaschine mit Knetfunktion")
        XCTAssertEqual(text("missing-pot").label, "Bräter/Römertopf")
        XCTAssertEqual(text("missing-pan").label, "Kastenform")
        XCTAssertEqual(text("missing-basket").label, "Gärkörbchen")
        tapButton("missing-tip-pot")
        assertTitle("Bräter und Römertopf")
        tapButton("tips-topic-close")
        _ = element(app.buttons, "equipment-edit")
        tapButton("missing-tip-basket")
        assertTitle("Gärkörbchen")
        tapButton("tips-topic-close")
    }

    func testSeededEquipmentIsShownAtOnce() {
        launch(seed: "all")
        openEquipment()
        assertEverythingShown()
    }

    func testTheSavedEquipmentCanBeChanged() {
        launch(seed: "all")
        openEquipment()
        tapButton("equipment-edit")
        // The wizard starts with what was saved.
        XCTAssertEqual(element(app.switches, "toggle-kneader").value as? String, "1")
        flip("toggle-kneader", to: false)
        next()
        flip("toggle-pot-liner", to: false)
        next()
        element(app.segmentedControls, "pan-material").buttons["Blech"].tap()
        flip("toggle-pan-lid", to: false)
        next()
        flip("toggle-basket", to: false)
        tapButton("wizard-save")
        XCTAssertFalse(app.staticTexts["equipment-kneader"].exists)
        XCTAssertEqual(text("equipment-pot").label, "Bräter/Römertopf ohne Silikoneinlage")
        XCTAssertEqual(text("equipment-pan").label,
                       "Kastenform aus Blech, ohne Deckel, mit Silikoneinlage")
        XCTAssertFalse(app.staticTexts["equipment-basket"].exists)
    }

    func testCancellingKeepsTheSavedEquipment() {
        launch(seed: "all")
        openEquipment()
        tapButton("equipment-edit")
        flip("toggle-kneader", to: false)
        tapButton("wizard-cancel")
        assertEverythingShown()
    }

    func testSeedingNothingShowsASetUpButEmptyList() {
        launch(seed: "none")
        openEquipment()
        XCTAssertEqual(text("equipment-empty").label, "Du hast keine Utensilien angegeben.")
    }
}
