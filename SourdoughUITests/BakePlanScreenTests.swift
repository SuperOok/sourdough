import XCTest

/// Planning a bake, step one: bread type, starter, flours.
/// Expected amounts are worked out by hand in the comments.
@MainActor
final class BakePlanScreenTests: SourdoughUITestCase {
    private func row(_ flour: String) -> XCUIElement { element(app.buttons, "plan-flour-\(flour)") }

    private func openFlour(_ flour: String) {
        row(flour).tap()
        _ = element(app.buttons, "flour-done")
    }

    private func done() {
        tapButton("flour-done")
        _ = element(app.buttons, "plan-bread")
    }

    func testTheStartScreenLeadsToARyeMixedBreadForAKilo() {
        launch()
        openBake()
        assertText("plan-bread-character", "Mitteldicht und würzig.")
        // 25 / 25 / 30 / 20 of 1000 g.
        XCTAssertTrue(row("rye1150").label.contains("25 %"), row("rye1150").label)
        XCTAssertTrue(row("rye1150").label.contains("250 g"), row("rye1150").label)
        XCTAssertTrue(row("spelt1050").label.contains("300 g"), row("spelt1050").label)
        assertText("plan-mix-summary", "Roggen 50 % (erlaubt 40–60 %) · Vollkorn 45 %")
        // 0.25 × 85 + 0.25 × 95 + 0.3 × 70 + 0.2 × 78 = 81.6 % → 816 g water.
        assertText("plan-hydration", "Hydration, 81,6 %")
        assertText("plan-water", "Wasser, 816 g")
        XCTAssertTrue(text("plan-no-starters").exists)
        tapButton("tips-button")
        assertTitle("Mehle wählen")
        tapButton("tips-topic-close")
        _ = element(app.buttons, "plan-bread")
    }

    /// Add-ins: added from the menu, stepped, removed with a swipe; each
    /// add-in and each flour leads to its tips page.
    func testAddInsAndTheTipsOfIngredients() {
        launch(seedEquipment: true)
        openBake()
        tapButton("plan-add-addin")
        tapButton("plan-add-addin-herbs")
        tapButton("plan-add-addin")
        tapButton("plan-add-addin-seeds")
        // 15 % of 1000 g.
        assertLabel("plan-addin-seeds", contains: "15 % · 150 g")
        element(app.steppers, "plan-addin-stepper-seeds").buttons.element(boundBy: 1).tap()
        assertLabel("plan-addin-seeds", contains: "16 % · 160 g")
        tapButton("plan-addin-tip-seeds")
        assertTitle("Saaten")
        tapButton("tips-topic-close")
        any("plan-addin-herbs").swipeLeft()
        tapButton("plan-addin-remove-herbs")
        XCTAssertTrue(app.staticTexts["plan-addin-herbs"].waitForNonExistence(timeout: 5))
        tapButton("plan-flour-tip-rye1150")
        assertTitle("Roggen")
        tapButton("tips-topic-close")
        openFlour("spelt1050")
        tapButton("flour-tips")
        assertTitle("Dinkel")
        tapButton("tips-topic-close")
        done()
        // The Römertopf takes 823.05 g dough; seeds 16 % with as much water:
        // 823.05 / (1 + 0.816 + 0.02 + 0.32) = 381.75 → 382 g flour, and
        // 16 % of it 61.1 g seeds soaking in 61.1 g water.
        tapButton("plan-next")
        assertText("setup-flour", "Mehl gesamt, 382 g")
        assertExact("recipe-soak-seeds", "Saaten, 61 g in 61 g Wasser")
        assertExact("recipe-addin-seeds", "Saaten, 61 g")
    }

    func testAnotherBreadStartsFromItsPreset() {
        launch()
        openBake()
        choose("plan-bread", "Dinkelbrot")
        assertText("plan-bread-character", "Luftig, mild-nussig, schnittfest.")
        assertText("plan-mix-summary", "Roggen 0 % (erlaubt 0–10 %) · Vollkorn 30 %")
        // 0.7 × 70 + 0.3 × 78 = 72.4 %.
        assertText("plan-hydration", "Hydration, 72,4 %")
        XCTAssertTrue(row("spelt1050").label.contains("70 %"))
        XCTAssertFalse(app.buttons["plan-flour-rye1150"].exists)
    }

    func testTheBuckwheatBreadsStartFromTheirPresetsAndBuckwheatHasItsPage() {
        launch()
        openBake()
        choose("plan-bread", "Buchweizen-Dinkelbrot")
        assertText("plan-bread-character", "Mitteldicht, feucht, mild-nussig.")
        assertText("plan-mix-summary", "Roggen 0 % (erlaubt 0–10 %) · Vollkorn 0 %")
        // 0.5 × 70 + 0.25 × 65 + 0.25 × 95 = 75 %.
        assertText("plan-hydration", "Hydration, 75 %")
        XCTAssertTrue(row("buckwheat").label.contains("Buchweizenmehl"))
        XCTAssertTrue(row("buckwheat").label.contains("25 %"))
        choose("plan-bread", "Buchweizen-Roggenbrot")
        assertText("plan-mix-summary", "Roggen 70 % (erlaubt 60–80 %) · Vollkorn 25 %")
        // 0.45 × 85 + 0.25 × 95 + 0.2 × 95 + 0.1 × 70 = 88 %.
        assertText("plan-hydration", "Hydration, 88 %")
        XCTAssertTrue(row("buckwheat").label.contains("20 %"))
        tapButton("plan-flour-tip-buckwheat")
        assertTitle("Buchweizen")
        XCTAssertEqual(any("tips-image-BuckwheatPhoto").label, "Buchweizenkörner. Foto: V.Boldychev, CC BY-SA 4.0, via Wikimedia Commons.")
        tapButton("tips-topic-close")
    }

    func testAWheatStarterIsNotEnoughForRye() {
        launch(seedStarters: true)
        openBake()
        choose("plan-starter", "Weizensauerteig (Weizen)")
        assertText("plan-issue-0", "Ab 30 % Roggen braucht der Teig einen Roggensauerteig. "
                   + "Wähle einen Roggenstarter oder nimm weniger Roggen.")
        choose("plan-starter", "Roggensauerteig (Roggen)")
        XCTAssertTrue(app.staticTexts["plan-issue-0"].waitForNonExistence(timeout: 5))
    }

    func testAShareCanBeSteppedLimitedAndSlid() {
        launch()
        openBake()
        openFlour("spelt1050")
        assertText("flour-share", "Anteil, 30 %")
        // Less spelt 1050 goes to spelt whole grain; more takes it from there
        // (20) and then from the rye, which must stay ≥ 40: at most 60.
        assertText("flour-range", "Möglich: 0–60 %")
        element(app.steppers, "flour-stepper").buttons.element(boundBy: 0).tap()
        assertText("flour-share", "Anteil, 29 %")
        element(app.steppers, "flour-stepper").buttons.element(boundBy: 1).tap()
        element(app.steppers, "flour-stepper").buttons.element(boundBy: 1).tap()
        assertText("flour-share", "Anteil, 31 %")
        // At most 200 g of 1000 g: 20 %.
        replaceText("flour-limit", with: "200")
        assertText("flour-share", "Anteil, 20 %")
        assertText("flour-range", "Möglich: 0–20 %")
        element(app.sliders, "flour-slider").adjust(toNormalizedSliderPosition: 0)
        assertText("flour-share", "Anteil, 0 %")
        done()
        // All 50 % spelt are whole grain now.
        XCTAssertFalse(app.buttons["plan-flour-spelt1050"].exists)
        XCTAssertTrue(row("speltWholeGrain").label.contains("500 g"), row("speltWholeGrain").label)
    }

    func testAFlourCanBeReplacedAddedAndRemoved() {
        launch()
        openBake()
        openFlour("rye1150")
        choose("flour-kind", "Roggen 997")
        XCTAssertTrue(app.navigationBars["Roggen 997"].waitForExistence(timeout: 5))
        done()
        XCTAssertTrue(row("rye997").label.contains("25 %"))
        // Wheat 1050 at 10 % takes a tenth from each: rye 997 25 → 22.5 %.
        tapButton("plan-add-flour")
        tapButton("plan-add-wheat1050")
        XCTAssertTrue(row("wheat1050").label.contains("10 %"), row("wheat1050").label)
        XCTAssertTrue(row("rye997").label.contains("22,5 %"), row("rye997").label)
        // Removing rye 997 gives its share to rye whole grain: 22.5 + 22.5 = 45 %.
        openFlour("rye997")
        tapButton("flour-remove")
        XCTAssertTrue(app.buttons["plan-flour-rye997"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(row("ryeWholeGrain").label.contains("45 %"), row("ryeWholeGrain").label)
    }

    func testRulesBoundTheShares() {
        launch()
        openBake()
        choose("plan-bread", "Roggenmischbrot 70")
        // Rye whole grain into rye 1150: 70 % of one rye flour, which must
        // stay between 60 and 80 %, so it cannot be removed.
        openFlour("ryeWholeGrain")
        choose("flour-kind", "Roggen 1150")
        assertText("flour-share", "Anteil, 70 %")
        assertText("flour-range", "Möglich: 60–80 %")
        XCTAssertFalse(element(app.buttons, "flour-remove").isEnabled)
        // At most 100 g of 1000 g: 10 % rye, the rest goes to spelt. Nothing
        // brings the rye back to 60 %.
        replaceText("flour-limit", with: "100")
        assertText("flour-range", "Der Anteil lässt sich nicht ändern, ohne eine Regel zu verletzen.")
        XCTAssertFalse(app.steppers["flour-stepper"].exists)
        done()
        assertText("plan-issue-0", "Zu wenig Roggen: Ein Roggenmischbrot 70 braucht mindestens 60 % Roggen.")
    }

    func testIssuesNameTooMuchRyeAndLimitsThatCannotBeMet() {
        launch()
        openBake()
        choose("plan-bread", "Dinkelbrot")
        openFlour("speltWholeGrain")
        choose("flour-kind", "Roggenvollkorn")
        done()
        assertText("plan-issue-0", "Zu viel Roggen: Ein Dinkelbrot verträgt höchstens 10 % Roggen.")
        // One rye flour alone, limited: nobody can take the rest.
        choose("plan-bread", "Roggenvollkornbrot")
        openFlour("ryeWholeGrain")
        choose("flour-kind", "Roggen 1150")
        replaceText("flour-limit", with: "500")
        done()
        assertText("plan-issue-0", "Roggen 1150 liegt über deiner Grenze, und kein anderes Mehl kann den Rest übernehmen.")
    }

    func testWithoutFlourThereIsNoNextStep() {
        launch()
        openBake()
        replaceText("plan-total", with: "0")
        assertText("plan-error", "Gib eine Mehlmenge über 0 g ein.")
        XCTAssertFalse(element(app.buttons, "plan-next").isEnabled)
        XCTAssertFalse(app.staticTexts["plan-water"].exists)
    }
}
