import XCTest

/// The equipment list: adding, changing and removing pieces, their form, the
/// kinds that are still missing. Five pieces come from `-seedEquipment all`:
/// the kneader "Thermomix", the oval pot "Römertopf" (with liner, 5,7 l), the
/// cast iron pan "Gusseisenform" (lid, liner, 2,4 l), a plain pan "Kastenform"
/// and the basket "Gärkörbchen".
@MainActor
final class EquipmentListTests: SourdoughUITestCase {
    private func row(_ name: String) -> XCUIElement { element(app.buttons, "equipment-row-\(name)") }

    /// Opens the form for a new piece of that kind (a `EquipmentKind` raw value).
    private func add(_ kind: String) {
        tapButton("equipment-add")
        tapButton("equipment-add-\(kind)")
        _ = element(app.buttons, "item-save")
    }

    private func typeName(_ name: String) {
        let field = element(app.textFields, "item-name")
        field.tap()
        field.typeText(name)
    }

    private func start(seed: Bool = false) {
        launch(seedEquipment: seed)
        openEquipment()
    }

    func testTheListIsEmptyAtFirstAndEveryKindIsMissing() {
        launch()
        XCTAssertTrue(app.staticTexts["Noch nichts angelegt"].exists)
        openEquipment()
        XCTAssertEqual(text("equipment-empty").label, "Noch keine Utensilien angelegt.")
        XCTAssertEqual(text("missing-kneader").label, "Küchenmaschine")
        XCTAssertEqual(text("missing-pot").label, "Bräter/Römertopf")
        XCTAssertEqual(text("missing-pan").label, "Kastenform")
        XCTAssertEqual(text("missing-basket").label, "Gärkörbchen")
    }

    func testABannetonIsRoundOrLong() {
        start()
        add("basket")
        element(app.segmentedControls, "item-basket-shape").buttons["Rechteckig"].tap()
        typeName("Lang")
        tapButton("item-save")
        XCTAssertTrue(row("Lang").label.contains("Gärkörbchen, rechteckig"), row("Lang").label)
        // Open again: the shape is kept.
        tapButton("equipment-row-Lang")
        XCTAssertTrue(element(app.segmentedControls, "item-basket-shape").buttons["Rechteckig"].isSelected)
    }

    /// The "+" of a missing kind opens the form for that kind; the "+" of a
    /// piece adds another one of its kind.
    func testThePlusOfAKindAddsAPieceOfIt() {
        start()
        tapButton("missing-add-basket")
        XCTAssertEqual(element(app.textFields, "item-name").placeholderValue, "Gärkörbchen")
        typeName("Oval")
        tapButton("item-save")
        XCTAssertFalse(app.staticTexts["missing-basket"].exists)
        tapButton("equipment-plus-Oval")
        XCTAssertEqual(element(app.textFields, "item-name").placeholderValue, "Gärkörbchen")
        typeName("Rund")
        tapButton("item-save")
        XCTAssertTrue(row("Rund").label.contains("Gärkörbchen"))
        XCTAssertTrue(row("Oval").label.contains("Gärkörbchen"))
    }

    /// The whole journey: add a pan with size, see it, restart the app.
    func testAddingAPanShowsItWithItsVolumeAndSurvivesRestartingTheApp() {
        start()
        add("pan")
        replaceText("item-length", with: "30")
        replaceText("item-width", with: "10")
        replaceText("item-height", with: "8")
        assertText("item-volume", "2,4 l")
        element(app.segmentedControls, "item-material").buttons["Gusseisen"].tap()
        flip("item-lid", to: true)
        flip("item-liner", to: true)
        typeName("Opas Form")
        tapButton("item-save")

        let label = row("Opas Form").label
        XCTAssertTrue(label.contains("Kastenform aus Gusseisen, mit Deckel, mit Silikoneinlage"), label)
        XCTAssertTrue(label.contains("30 × 10 × 8 cm · 2,4 l"), label)
        XCTAssertFalse(app.staticTexts["equipment-empty"].exists)

        relaunch()
        XCTAssertTrue(app.staticTexts["1 angelegt"].waitForExistence(timeout: 10))
        openEquipment()
        XCTAssertTrue(row("Opas Form").label.contains("2,4 l"))
    }

    func testAPotCanBeWithoutALid() {
        start()
        add("pot")
        flip("item-lid", to: false)
        typeName("Offener Topf")
        tapButton("item-save")
        XCTAssertTrue(row("Offener Topf").label.contains("Bräter/Römertopf, ohne Deckel"), row("Offener Topf").label)
        // Opening it again shows the setting as it was saved.
        tapButton("equipment-row-Offener Topf")
        XCTAssertEqual(element(app.switches, "item-lid").value as? String, "0")
    }

    func testTheNameDefaultsToTheKind() {
        start()
        add("kneader")
        tapButton("item-save")
        XCTAssertTrue(row("Küchenmaschine").label.contains("Küchenmaschine mit Knetfunktion"))
    }

    func testKindsWithoutAPieceAreListedAsMissingWithTheirTips() {
        start()
        add("kneader")
        tapButton("item-save")
        XCTAssertFalse(app.staticTexts["missing-kneader"].exists)
        XCTAssertEqual(text("missing-pot").label, "Bräter/Römertopf")
        XCTAssertEqual(text("missing-pan").label, "Kastenform")
        XCTAssertEqual(text("missing-basket").label, "Gärkörbchen")
        tapButton("missing-tip-pot")
        assertTitle("Bräter und Römertopf")
        tapButton("tips-topic-close")
        _ = element(app.buttons, "equipment-add")
        tapButton("missing-tip-basket")
        assertTitle("Gärkörbchen")
        tapButton("tips-topic-close")
    }

    func testSeveralPiecesOfOneKindAreListed() {
        start(seed: true)
        XCTAssertTrue(row("Thermomix").label.contains("Küchenmaschine mit Knetfunktion"))
        XCTAssertTrue(row("Römertopf").label.contains(
            "Bräter/Römertopf, mit Deckel, mit Silikoneinlage · oval 30 × 20 × 12 cm · 5,7 l"), row("Römertopf").label)
        XCTAssertTrue(row("Gusseisenform").label.contains(
            "Kastenform aus Gusseisen, mit Deckel, mit Silikoneinlage · 30 × 10 × 8 cm · 2,4 l"))
        XCTAssertTrue(row("Kastenform").label.contains(
            "Kastenform aus Blech, ohne Deckel, ohne Silikoneinlage"))
        XCTAssertFalse(row("Kastenform").label.contains(" · "))
        XCTAssertTrue(row("Gärkörbchen").label.contains("Gärkörbchen"))
        XCTAssertFalse(app.staticTexts["equipment-empty"].exists)
        // One of every kind: nothing is missing.
        XCTAssertFalse(app.staticTexts["missing-pot"].exists)
    }

    func testTheStartScreenCountsThePieces() {
        launch(seedEquipment: true)
        XCTAssertTrue(app.staticTexts["5 angelegt"].waitForExistence(timeout: 10))
    }

    func testAPieceCanBeChanged() {
        start(seed: true)
        row("Römertopf").tap()
        XCTAssertEqual(element(app.switches, "item-liner").value as? String, "1")
        assertText("item-volume", "5,7 l")
        flip("item-liner", to: false)
        // π/4 × 40 × 20 × 12 ≈ 7539,8 ml
        replaceText("item-length", with: "40")
        assertText("item-volume", "7,5 l")
        let field = element(app.textFields, "item-name")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Römertopf".count) + "Bräter")
        tapButton("item-save")

        XCTAssertTrue(app.buttons["equipment-row-Römertopf"].waitForNonExistence(timeout: 5))
        let label = row("Bräter").label
        XCTAssertTrue(label.contains("Bräter/Römertopf, mit Deckel, ohne Silikoneinlage"), label)
        XCTAssertTrue(label.contains("oval 40 × 20 × 12 cm · 7,5 l"), label)
    }

    func testCancellingKeepsThePiece() {
        start(seed: true)
        row("Römertopf").tap()
        flip("item-liner", to: false)
        tapButton("item-cancel")
        XCTAssertTrue(row("Römertopf").label.contains("mit Silikoneinlage"))
        XCTAssertFalse(row("Römertopf").label.contains("ohne Silikoneinlage"))
    }

    func testCancellingANewPieceAddsNothing() {
        start()
        add("basket")
        tapButton("item-cancel")
        XCTAssertEqual(text("equipment-empty").label, "Noch keine Utensilien angelegt.")
    }

    func testAPieceIsDeletedOnlyAfterConfirming() {
        start(seed: true)
        XCTAssertFalse(app.staticTexts["missing-kneader"].exists)
        row("Thermomix").tap()
        tapButton("item-delete")
        let cancel = app.alerts.buttons["Abbrechen"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        // Still in the form, nothing deleted.
        tapButton("item-cancel")
        _ = row("Thermomix")
        row("Thermomix").tap()
        tapButton("item-delete")
        let confirm = app.alerts.buttons["Löschen"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["equipment-row-Thermomix"].waitForNonExistence(timeout: 5))
        // The kind it was the only piece of is missing now.
        XCTAssertEqual(text("missing-kneader").label, "Küchenmaschine")
        XCTAssertTrue(app.buttons["equipment-row-Römertopf"].exists)
    }

    func testTheFormShowsOnlyWhatBelongsToTheKind() {
        start()
        for kind in ["kneader", "basket"] {
            add(kind)
            XCTAssertFalse(app.segmentedControls["item-material"].exists)
            XCTAssertFalse(app.switches["item-lid"].exists)
            XCTAssertFalse(app.switches["item-liner"].exists)
            XCTAssertFalse(app.segmentedControls["item-shape"].exists)
            XCTAssertFalse(app.textFields["item-length"].exists)
            // A new piece cannot be deleted.
            XCTAssertFalse(app.buttons["item-delete"].exists)
            tapButton("item-cancel")
        }
        add("pot")
        element(app.switches, "item-liner")
        element(app.segmentedControls, "item-shape")
        XCTAssertFalse(app.segmentedControls["item-material"].exists)
        // A pot may have a lid; a new one has.
        XCTAssertEqual(element(app.switches, "item-lid").value as? String, "1")
        // A pot starts round, which has no width; oval and rectangle do.
        XCTAssertFalse(app.textFields["item-width"].exists)
        element(app.segmentedControls, "item-shape").buttons["Oval"].tap()
        element(app.textFields, "item-width")
        element(app.segmentedControls, "item-shape").buttons["Rund"].tap()
        XCTAssertTrue(app.textFields["item-width"].waitForNonExistence(timeout: 5))
        tapButton("item-cancel")
        add("pan")
        element(app.segmentedControls, "item-material")
        element(app.switches, "item-lid")
        element(app.switches, "item-liner")
        element(app.textFields, "item-width")
    }

    func testTheSizeIsOptionalButMustBeComplete() {
        start()
        add("pan")
        let save = element(app.buttons, "item-save")
        XCTAssertTrue(save.isEnabled)
        XCTAssertFalse(app.staticTexts["item-error"].exists)
        XCTAssertFalse(app.staticTexts["item-volume"].exists)

        replaceText("item-length", with: "30")
        assertText("item-error", "Noch fehlen: Breite und Höhe. Gib alle Maße an oder keines.")
        XCTAssertFalse(save.isEnabled)
        XCTAssertFalse(app.staticTexts["item-volume"].exists)

        replaceText("item-width", with: "10")
        replaceText("item-height", with: "8")
        XCTAssertTrue(app.staticTexts["item-error"].waitForNonExistence(timeout: 5))
        assertText("item-volume", "2,4 l")
        XCTAssertTrue(save.isEnabled)

        // A round shape needs no width: π/4 × 30² × 8 ≈ 5654,9 ml.
        element(app.segmentedControls, "item-shape").buttons["Rund"].tap()
        assertText("item-volume", "5,7 l")
    }

    /// Typing one measure after the other with the keypad up: the next
    /// field is tapped directly, the last one reached with "Weiter".
    func testTheMeasuresCanBeTypedOneAfterTheOther() {
        start()
        add("pan")
        let length = element(app.textFields, "item-length")
        length.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        typeOnKeypad("30")
        // Not under the keypad: the field with the focus sits in the middle.
        let width = element(app.textFields, "item-width")
        XCTAssertTrue(width.isHittable)
        width.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        typeOnKeypad("10")
        tapButton("keyboard-next")
        typeOnKeypad("8")
        // The last field has no next one.
        XCTAssertFalse(app.buttons["keyboard-next"].isEnabled)
        tapButton("keyboard-done")
        XCTAssertEqual(length.value as? String, "30")
        XCTAssertEqual(width.value as? String, "10")
        // 30 × 10 × 8 cm = 2400 ml.
        assertText("item-volume", "2,4 l")
    }

    func testTheTipsOfTheKindOpenFromTheFormAndLeaveItUnchanged() {
        start()
        add("pan")
        replaceText("item-length", with: "30")
        tapButton("item-tips")
        assertTitle("Kastenform")
        tapButton("tips-topic-close")
        XCTAssertEqual(element(app.textFields, "item-length").value as? String, "30")
    }

    func testEachPieceHasASymbolThatLeadsToItsTips() {
        start(seed: true)
        tapButton("equipment-tip-Gusseisenform")
        assertTitle("Kastenform")
        tapButton("tips-topic-close")
        // Back on the list, which is unchanged.
        XCTAssertTrue(row("Gusseisenform").label.contains("2,4 l"))
        tapButton("equipment-tip-Thermomix")
        assertTitle("Küchenmaschine")
        tapButton("tips-topic-close")
    }
}
