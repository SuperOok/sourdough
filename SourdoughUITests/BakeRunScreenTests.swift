import XCTest

/// A bake in progress: starting it, its steps and decisions, coming back
/// after a restart, cancelling and finishing.
/// The demo bake (`-seedRun active`) is the proposal for Friday 13 November
/// 2026, 09:00: Roggenmischbrot 50 in the Römertopf, 448 g flour, ready on
/// Saturday 18:00, sourdough mixed on Friday 16:26.
@MainActor
final class BakeRunScreenTests: SourdoughUITestCase {
    private func launchWithRun() {
        launch(seedEquipment: true, seedStarters: true, now: Self.friday, seedRun: "active")
        _ = element(app.buttons, "run-answer-yes")
    }

    private func done() {
        tapButton("run-done")
    }

    private func answer(_ answer: String) {
        tapButton("run-answer-\(answer)")
    }

    func testStartingABakeOpensItsFirstStepAndSurvivesARestart() {
        launch(seedEquipment: true, seedStarters: true, now: Self.friday)
        openBake()
        choose("plan-starter", "Roggensauerteig (Roggen)")
        tapButton("plan-next")
        tapButton("setup-next")
        tapButton("schedule-start")
        assertExact("run-target", "Anschnittfertig, Sa 14.11. 18:00")
        assertText("run-planned", "Geplant: Fr 16:26")
        assertLabel("run-text", contains: "Ist dein Starter aktiv?")
        assertLabel("run-text", contains: "„Roggensauerteig“")
        // The app opens the bake again after a restart.
        relaunch()
        assertText("run-planned", "Geplant: Fr 16:26")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        assertLabel("start-bake", contains: "Läuft: Roggenmischbrot 50")
        tapButton("start-bake")
        _ = element(app.buttons, "run-answer-yes")
    }

    func testDecisionsWaitOrGoOnAndStepsNameTheAmounts() {
        launchWithRun()
        answer("notYet")
        assertLabel("run-hint", contains: "Erst auffrischen")
        assertLabel("run-step-0", contains: "geplant Fr 16:26")
        answer("yes")
        // 35 % of the 224 g rye soured: 78 g rye whole grain, 78 g water,
        // 16 g starter; ripening at the cool place until Saturday 08:04.
        assertLabel("run-text", contains: "Sauerteigstufe ansetzen")
        assertLabel("run-text", contains: "78 g Roggenvollkorn")
        assertLabel("run-text", contains: "16 g Anstellgut – nimm dafür „Roggensauerteig“")
        assertLabel("run-text", contains: "bei etwa 16 °C reifen: etwa 15 Std. 28 Min., bis Sa 08:04")
        assertLabel("run-step-0", contains: "erledigt")
        done()
        answer("yes")
        // 50 % rye: mixed briefly, warm bulk rest with water at 2 × 27 − 22 = 32 °C.
        assertLabel("run-text", contains: "Hauptteig mischen")
        assertLabel("run-text", contains: "287 g Wasser, etwa 32 °C warm")
        assertLabel("run-text", contains: "mit „Thermomix“")
        // Still there after a restart.
        relaunch()
        assertLabel("run-text", contains: "Hauptteig mischen")
        done()
        assertLabel("run-text", contains: "das Gärkörbchen „Gärkörbchen“")
    }

    func testTheKneadingStepLinksToTheKneadingPage() {
        launchWithRun()
        answer("yes")
        done()
        answer("yes")
        assertLabel("run-text", contains: "Hauptteig mischen")
        element(app.links, "Kneten").tap()
        assertTitle("Kneten")
        // The page opens over the bake; "Fertig" returns to the same step.
        tapButton("tips-topic-close")
        assertLabel("run-text", contains: "Hauptteig mischen")
    }

    func testAStepTappedByMistakeCanBeOpenedAgain() {
        launchWithRun()
        XCTAssertFalse(app.buttons["run-undo"].exists)
        answer("yes")
        done()
        assertLabel("run-text", contains: "Ist der Sauerteig reif?")
        assertLabel("run-undo", contains: "Zurück zu „Sauerteigstufe ansetzen“")
        tapButton("run-undo")
        assertLabel("run-text", contains: "Sauerteigstufe ansetzen")
        assertLabel("run-step-1", contains: "geplant")
        assertLabel("run-step-0", contains: "erledigt")
        // Back to the first decision, which asks again.
        tapButton("run-undo")
        _ = element(app.buttons, "run-answer-notYet")
        XCTAssertFalse(app.buttons["run-undo"].exists)
    }

    func testFinishingABakeLeadsBackToTheStartScreen() {
        launchWithRun()
        answer("yes")
        done()
        answer("yes")
        done()
        done()
        // The proof is checked with the finger; not yet, then ripe.
        answer("notYet")
        assertLabel("run-hint", contains: "Noch etwas gehen lassen")
        answer("yes")
        assertLabel("run-text", contains: "Ofen und Bräter vorheizen")
        done()
        assertLabel("run-text", contains: "Backen im Bräter")
        done()
        assertLabel("run-text", contains: "bis Sa 18:00")
        done()
        assertText("run-finished", "Dein Brot ist anschnittfertig. Guten Appetit!")
        assertText("run-status", "Durchgang fertig.")
        XCTAssertFalse(app.buttons["run-cancel"].exists)
        // The last "Erledigt" by mistake: the bake runs again.
        tapButton("run-undo")
        assertLabel("run-text", contains: "bis Sa 18:00")
        done()
        assertText("run-finished", "Dein Brot ist anschnittfertig. Guten Appetit!")
        tapButton("run-close")
        assertLabel("start-log", contains: "1 Durchgang")
        assertLabel("start-bake", contains: "Brot planen")
    }

    func testCancellingAsksFirstAndKeepsTheBakeInTheLog() {
        launchWithRun()
        tapButton("run-cancel")
        app.alerts.buttons["Weiterbacken"].tap()
        _ = element(app.buttons, "run-answer-yes")
        tapButton("run-cancel")
        app.alerts.buttons["Abbrechen"].tap()
        assertLabel("start-log", contains: "1 Durchgang")
        tapButton("start-bake")
        _ = element(app.buttons, "plan-bread")
    }

    func testTheRunHasItsOwnTipsPage() {
        launchWithRun()
        tapButton("tips-button")
        assertTitle("Der Durchgang")
        tapButton("tips-topic-close")
        _ = element(app.buttons, "run-answer-yes")
    }

    func testADoughOverTheRimBakesWithoutTheLid() {
        // The Gusseisenform has a lid.
        launch(seedEquipment: true, seedStarters: true, now: Self.friday)
        openBake()
        tapButton("plan-next")
        element(app.segmentedControls, "setup-vessel").buttons["Kastenform"].tap()
        tapButton("setup-next")
        tapButton("schedule-start")
        answer("yes")
        done()
        answer("yes")
        done()
        assertLabel("run-text", contains: "„Gusseisenform“")
        done()
        assertLabel("run-text", contains: "Wie hoch ist der Teig?")
        answer("overRim")
        done()
        assertLabel("run-text", contains: "Backen ohne Deckel, mit Dampf")
    }
}

/// The log of all bakes.
@MainActor
final class BakeLogScreenTests: SourdoughUITestCase {
    func testTheLogIsEmptyAtFirst() {
        launch()
        assertLabel("start-log", contains: "Noch kein Durchgang")
        tapButton("start-log")
        assertExact("log-empty", "Noch kein Brot gebacken.")
    }

    func testAFinishedBakeShowsEverythingAndCanBeDeleted() {
        launch(seedEquipment: true, seedStarters: true, now: Self.friday, seedRun: "finished")
        tapButton("start-log")
        assertLabel("log-row-0", contains: "Roggenmischbrot 50")
        assertLabel("log-row-0", contains: "Fr 13.11. 09:00 · fertig")
        tapButton("log-row-0")
        assertExact("log-status", "Status, fertig")
        assertExact("log-target", "Anschnittfertig geplant, Sa 14.11. 18:00")
        assertExact("log-starter", "Starter, Roggensauerteig (Roggen)")
        assertExact("log-equipment", "Utensilien, Römertopf, Gärkörbchen, Thermomix")
        assertExact("log-temperatures", "Temperaturen, Raum 22 °C, Kühlschrank 5 °C")
        // 25 % of 448 g = 112 g; 81.6 % water; sourdough 172 g; salt 9 g.
        assertExact("log-flour-rye1150", "Roggen 1150, 25 % · 112 g")
        assertExact("log-hydration", "Hydration, 81,6 %")
        assertExact("log-sourdough", "Sauerteigstufe, 172 g")
        assertLabel("log-step-0", contains: "geplant Fr 16:26 · erledigt Fr 09:00 · Ja")
        // The sourdough ripens at the cool place, 16 °C.
        assertLabel("log-step-1", contains: "Ruhe bei etwa 16 °C")
        tapButton("log-delete")
        app.alerts.buttons["Abbrechen"].tap()
        tapButton("log-delete")
        app.alerts.buttons["Löschen"].tap()
        assertExact("log-empty", "Noch kein Brot gebacken.")
    }
}
