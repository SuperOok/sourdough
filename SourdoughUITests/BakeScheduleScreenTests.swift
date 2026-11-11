import XCTest

/// Planning a bake, step three: target, temperatures and the timeline.
/// Planned from Friday 13 November 2026, 09:00, for a Roggenmischbrot 50 in
/// the demo Römertopf at 22 °C, the first sensible target is Saturday 18:00:
///
/// - baking ends 12:00 (cooling 6 h), from 11:10, preheating from 10:25;
/// - proof at room temperature 1.5 h from 09:40, shaping 09:25;
/// - the bulk rest at room temperature would need kneading before 08:00, so
///   it goes warm (27 °C): 1.75 h × 3^−0.5 = 1 h 0.6 min, kneading 08:04;
/// - the sourdough ripens overnight at the cool place (16 °C): at room
///   temperature (6.4 to 10 h) no start fits the window, at 16 °C it takes
///   8 × 3^0.6 = 15 h 28 min, from Friday 16:36, mixed at 16:26.
@MainActor
final class BakeScheduleScreenTests: SourdoughUITestCase {
    private func openSchedule() {
        launch(seedEquipment: true, now: Self.friday)
        openBake()
        tapButton("plan-next")
        tapButton("setup-next")
        _ = element(app.buttons, "schedule-target")
    }

    func testTheRestsLinkToTheProofingPage() {
        openSchedule()
        XCTAssertFalse(app.buttons["schedule-tip-sourdough"].exists)
        tapButton("schedule-tip-bulk")
        assertTitle("Gare: Stockgare und Stückgare")
        tapButton("tips-topic-close")
        tapButton("schedule-tip-proof")
        assertTitle("Gare: Stockgare und Stückgare")
        tapButton("tips-topic-close")
    }

    func testTheProposalStartsOnFridayEveningForSaturdayEvening() {
        openSchedule()
        assertLabel("schedule-target", contains: "Sa 14.11. 18:00")
        XCTAssertTrue(any("schedule-chart").exists)
        let expected = [
            ("Fr 16:26", "Sauerteig ansetzen"), ("Fr 16:36", "Sauerteig reift"),
            ("Sa 08:04", "Hauptteig kneten"), ("Sa 08:24", "Stockgare"),
            ("Sa 09:25", "Teig formen"), ("Sa 09:40", "Stückgare"),
            ("Sa 10:25", "Ofen vorheizen"), ("Sa 11:10", "Backen"), ("Sa 12:00", "Auskühlen"),
        ]
        for (index, (time, title)) in expected.enumerated() {
            assertLabel("schedule-step-\(index)", contains: time)
            assertLabel("schedule-step-\(index)", contains: title)
        }
        // 8 × 3^0.6 h = 15 h 28 min; warm bulk 1 h 0 min; proof 1.5 h.
        assertLabel("schedule-step-1", contains: "15 Std. 28 Min.")
        assertLabel("schedule-step-5", contains: "1 Std. 30 Min.")
        assertLabel("schedule-place-sourdough", contains: "Kühl (16 °C)")
        assertLabel("schedule-place-bulk", contains: "Warm (27 °C)")
        // The range at the same temperature is narrow: 0.8 × 15.465 h = 12 h
        // 22 min to 1.25 × 15.465 h = 19 h 20 min.
        assertText("schedule-range-sourdough", "Sinnvoll: 12 Std. 22 Min. bis 19 Std. 20 Min.")
        XCTAssertFalse(app.staticTexts["schedule-conflict-0"].exists)
        XCTAssertFalse(element(app.buttons, "schedule-reset").isEnabled)
    }

    func testARestCanBeLengthenedAndTheProposalRestored() {
        openSchedule()
        let more = element(app.steppers, "schedule-stepper-proof").buttons.element(boundBy: 1)
        more.tap()
        // 2 h are more than the room allows (1 h 48 min) and less than the
        // cool place (from 2 h 28 min): the proof keeps the 1 h 48 min, shaping
        // starts at 09:07, and the hint names the temperature that 2 h would
        // take, 22 − 10 × log₃(2 / 1.5) = 19.4 °C.
        assertLabel("schedule-step-5", contains: "1 Std. 48 Min.")
        assertLabel("schedule-step-4", contains: "Sa 09:07")
        assertText("schedule-needed-proof", "Für 2 Std. 0 Min. wären etwa 19 °C nötig.")
        // Another half hour: 2 h 30 min are in the range of the cool place, the
        // proof moves there, and the hint is gone.
        more.tap()
        assertLabel("schedule-step-5", contains: "2 Std. 30 Min.")
        assertLabel("schedule-step-4", contains: "Sa 08:25")
        assertLabel("schedule-place-proof", contains: "Kühl (16 °C)")
        XCTAssertFalse(app.staticTexts["schedule-needed-proof"].exists)
        tapButton("schedule-reset")
        assertLabel("schedule-step-5", contains: "1 Std. 30 Min.")
        // A shorter proof moves to the warm place: 1 h at 27 °C is in its range.
        element(app.steppers, "schedule-stepper-proof").buttons.element(boundBy: 0).tap()
        assertLabel("schedule-step-5", contains: "1 Std. 0 Min.")
        assertLabel("schedule-place-proof", contains: "Warm (27 °C)")
    }

    func testTheCoolPlaceCanBeSetSwitchedOffAndIsRemembered() {
        openSchedule()
        replaceText("schedule-cool", with: "20")
        assertText("schedule-error", "Ein kühler Ort liegt meist zwischen 8 und 18 °C.")
        replaceText("schedule-cool", with: "14")
        XCTAssertTrue(app.staticTexts["schedule-error"].waitForNonExistence(timeout: 5))
        assertLabel("schedule-place-sourdough", contains: "Kühl (14 °C)")
        // Without a cool place the field is gone and no rest can take it.
        flip("schedule-cool-toggle", to: false)
        XCTAssertTrue(app.textFields["schedule-cool"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["schedule-place-sourdough"].label.contains("Kühl ("))
        // The kitchen is remembered, cool place included.
        relaunch()
        openBake()
        tapButton("plan-next")
        tapButton("setup-next")
        _ = element(app.buttons, "schedule-target")
        XCTAssertEqual(element(app.switches, "schedule-cool-toggle").value as? String, "0")
        flip("schedule-cool-toggle", to: true)
        XCTAssertEqual(element(app.textFields, "schedule-cool").value as? String, "14")
    }

    func testTheFridgeLengthensTheProofIntoTheNight() {
        openSchedule()
        // In the fridge at 5 °C: 1.5 h × 3^1.7 = 9.71 h = 9 h 43 min, from Saturday
        // 01:27, shaping 01:12. The bulk rest before it fits nowhere: at room
        // temperature (1.75 h) kneading is at Friday 23:07.
        // The warning must not move what is above it: the control stays where it was.
        let before = element(app.buttons, "schedule-place-proof").frame.minY
        choose("schedule-place-proof", "Kühlschrank (5 °C)")
        XCTAssertEqual(element(app.buttons, "schedule-place-proof").frame.minY, before, accuracy: 0.5)
        assertLabel("schedule-step-5", contains: "9 Std. 43 Min.")
        // The rows outside the window say so (colour for the eye, a value for VoiceOver).
        XCTAssertEqual(any("schedule-step-2").value as? String, "außerhalb des Zeitfensters")
        XCTAssertEqual(any("schedule-step-8").value as? String, "")
        assertText("schedule-conflict-0", "Hauptteig kneten um Fr 23:07 liegt außerhalb von 8 bis 21 Uhr.")
        assertText("schedule-conflict-1", "Teig formen um Sa 01:12 liegt außerhalb von 8 bis 21 Uhr.")
    }

    func testTheTargetComesFromTheCalendar() {
        openSchedule()
        tapButton("schedule-target")
        let picker = element(app.datePickers, "schedule-datepicker")
        let day = picker.buttons.matching(NSPredicate(format: "label CONTAINS %@", "16")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()
        tapButton("schedule-target-done")
        assertLabel("schedule-target", contains: "Mo 16.11. 18:00")
        assertLabel("schedule-step-8", contains: "Mo 12:00")
    }

    func testTemperaturesAreCheckedAndRemembered() {
        openSchedule()
        replaceText("schedule-room", with: "5")
        assertText("schedule-error", "Die Raumtemperatur liegt meist zwischen 10 und 35 °C.")
        replaceText("schedule-room", with: "20")
        XCTAssertTrue(app.staticTexts["schedule-error"].waitForNonExistence(timeout: 5))
        replaceText("schedule-fridge", with: "20")
        assertText("schedule-error", "Die Kühlschranktemperatur liegt meist zwischen 0 und 15 °C.")
        replaceText("schedule-fridge", with: "4")
        // A new starter starts with the kitchen as it was left.
        relaunch()
        openStarters()
        tapButton("starter-add")
        XCTAssertEqual(element(app.textFields, "add-fridge-temp").value as? String, "4")
        element(app.segmentedControls, "add-storage").buttons["Raumtemperatur"].tap()
        XCTAssertEqual(element(app.textFields, "add-room-temp").value as? String, "20")
    }
}
