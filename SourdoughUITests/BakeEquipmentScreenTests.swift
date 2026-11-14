import XCTest

/// Planning a bake, step two: equipment, amount of dough, recipe.
/// The demo equipment: Thermomix, Römertopf (oval 30 × 20 × 12 cm),
/// Gusseisenform (30 × 10 × 8 cm), Kastenform (no size), Gärkörbchen. The
/// Thermomix has a 2.2 l bowl: 2.2 × 0.4 kg/l = 880 g of dough.
@MainActor
final class BakeEquipmentScreenTests: SourdoughUITestCase {
    private func openEquipmentStep(bread: String? = nil) {
        launch(seedEquipment: true)
        openBake()
        if let bread { choose("plan-bread", bread) }
        tapButton("plan-next")
        _ = element(app.segmentedControls, "setup-vessel")
    }

    private func vessel(_ name: String) {
        element(app.segmentedControls, "setup-vessel").buttons[name].tap()
    }

    func testTheRecipeNamesTheChosenStarter() {
        launch(seedEquipment: true, seedStarters: true)
        openBake()
        choose("plan-starter", "Roggensauerteig (Roggen)")
        tapButton("plan-next")
        _ = element(app.segmentedControls, "setup-vessel")
        assertLabel("recipe-starter", contains: "Anstellgut „Roggensauerteig“")
    }

    func testThePotIsProposedWithItsAmountAndRecipe() {
        openEquipmentStep()
        XCTAssertTrue(element(app.segmentedControls, "setup-vessel").buttons["Bräter"].isSelected)
        // Oval 30 × 20 against a round 27 cm pot: 1000 g × 600 / 729 = 823 g
        // dough; / (1 + 0.816 + 0.02) = 448 g flour.
        assertText("setup-dough", "Teig, 823 g")
        assertText("setup-flour", "Mehl gesamt, 448 g")
        assertText("setup-dough-source",
                   "Aus der Bodenfläche von „Römertopf“: Ein runder Bräter mit 27 cm Durchmesser fasst etwa 1 kg Teig.")
        // Rye 50 % of 448 g = 224 g, 35 % soured = 78.4 g from rye whole grain
        // (112 g), as much water, starter 20 % = 15.7 g; together 172.5 g.
        assertLabel("recipe-sour-ryeWholeGrain", contains: "78 g")
        assertLabel("recipe-sour-water", contains: "78 g")
        assertLabel("recipe-starter", contains: "16 g")
        assertText("recipe-sourdough", "Zusammen 172 g.")
        // Main dough: rye whole grain 112 − 78.4 = 33.6 g, rye 1150 112 g,
        // spelt 1050 134.4 g, water 448 × 0.816 − 78.4 = 287.2 g, salt 9 g.
        assertLabel("recipe-main-ryeWholeGrain", contains: "34 g")
        assertLabel("recipe-main-rye1150", contains: "112 g")
        assertLabel("recipe-main-spelt1050", contains: "134 g")
        assertLabel("recipe-main-water", contains: "287 g")
        assertLabel("recipe-salt", contains: "9 g")
    }

    func testTheLoafPanTakesItsVolumeAndAPanWithoutSizeAKilo() {
        openEquipmentStep()
        vessel("Kastenform")
        // 30 × 10 × 8 = 2400 ml × 0.5 = 1200 g dough → 1200 / 1.836 = 654 g flour.
        assertText("setup-dough", "Teig, 1200 g")
        assertText("setup-flour", "Mehl gesamt, 654 g")
        assertText("setup-dough-source", "Aus dem Volumen von „Gusseisenform“ (2,4 l), zu etwa 60 % gefüllt.")
        XCTAssertFalse(app.buttons["setup-basket"].exists)
        choose("setup-pan", "Kastenform")
        assertText("setup-dough", "Teig, 1000 g")
        assertText("setup-dough-source", "Ohne Innenmaße rechnet die App mit 1000 g Teig.")
        tapButton("tips-button")
        assertTitle("Utensilien und Menge")
        tapButton("tips-topic-close")
        _ = element(app.segmentedControls, "setup-vessel")
    }

    /// The hint when the dough is too much for the kneader; it does not stop the plan.
    func testADoughTooLargeForTheKneaderShowsAHint() {
        openEquipmentStep()
        // In the Römertopf: 448 g flour × 1.836 = 822.5 g, with 15.7 g starter
        // 838.2 g; under 880 g, no hint.
        assertText("setup-dough", "Teig, 823 g")
        XCTAssertFalse(app.staticTexts["setup-kneader-hint"].exists)
        // In the Gusseisenform: 654 g flour × 1.836 = 1200.7 g; rye 327 g, 35 %
        // soured = 114.45 g, starter 22.9 g; 1223.6 g ≈ 1,2 kg, over 880 g.
        vessel("Kastenform")
        assertText("setup-kneader-hint", "Für deine 2,2-l-Schüssel ist der Teig mit 1,2 kg wahrscheinlich zu groß. "
                   + "Teile ihn oder knete von Hand.")
        XCTAssertFalse(app.staticTexts["setup-issue-0"].exists)
        // By hand there is no limit.
        choose("setup-kneader", "von Hand")
        XCTAssertTrue(app.staticTexts["setup-kneader-hint"].waitForNonExistence(timeout: 5))
    }

    func testTheTrayProofsInABowlAndKneadingCanBeByHand() {
        openEquipmentStep()
        vessel("Blech")
        assertText("setup-dough", "Teig, 1000 g")
        XCTAssertFalse(app.buttons["setup-pot"].exists)
        choose("setup-basket", "Schüssel")
        assertLabel("setup-basket", contains: "Schüssel")
        choose("setup-kneader", "von Hand")
        assertLabel("setup-kneader", contains: "von Hand")
        vessel("Bräter")
        choose("setup-pot", "Römertopf")
        assertText("setup-dough", "Teig, 823 g")
    }

    func testTooMuchRyeCannotStandFree() {
        // Roggenmischbrot 70 is proposed in the loaf pan; in the pot it runs.
        openEquipmentStep(bread: "Roggenmischbrot 70")
        XCTAssertTrue(element(app.segmentedControls, "setup-vessel").buttons["Kastenform"].isSelected)
        vessel("Bräter")
        assertText("setup-issue-0", "Mit mehr als 50 % Roggen läuft ein freigeschobenes Brot auseinander. "
                   + "Nimm die Kastenform oder weniger Roggen.")
    }

    func testFreeStandingLinksToItsPageFromTheHintAndFromTheIssue() {
        openEquipmentStep()
        // The pot is proposed: the hint under the vessels names the term as a link.
        let link = element(app.links, "Freigeschoben")
        link.tap()
        assertTitle("Freigeschoben backen")
        tapButton("tips-topic-close")
        openEquipmentStepAgainWithRye()
        tapButton("setup-issue-tip-0")
        assertTitle("Freigeschoben backen")
        tapButton("tips-topic-close")
    }

    private func openEquipmentStepAgainWithRye() {
        // Roggenmischbrot 70 does not stand free: back to step one, new bread.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        choose("plan-bread", "Roggenmischbrot 70")
        tapButton("plan-next")
        _ = element(app.segmentedControls, "setup-vessel")
        vessel("Bräter")
    }
}
