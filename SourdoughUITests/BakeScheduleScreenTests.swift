import XCTest

/// Planning a bake, step three: target, temperatures and the timeline.
/// Planned from Friday 13 November 2026, 09:00, for a Roggenmischbrot 50 in
/// the demo Römertopf at 22 °C, the first sensible target is Saturday 18:00:
///
/// - baking ends 12:00 (cooling 6 h), from 11:10, preheating from 10:25;
/// - proof at room temperature 1.5 h from 09:40, shaping 09:25;
/// - the bulk rest at room temperature would need kneading before 08:00, so
///   it goes warm (27 °C): 1.75 h × 3^−0.5 = 1 h 0.6 min, kneading 08:04;
/// - the sourdough ripens overnight from Friday 21:00, mixed at 20:50.
@MainActor
final class BakeScheduleScreenTests: SourdoughUITestCase {
    private func openSchedule() {
        launch(seedEquipment: true, now: Self.friday)
        openBake()
        tapButton("plan-next")
        tapButton("setup-next")
        _ = element(app.buttons, "schedule-target")
    }

    func testTheProposalStartsOnFridayEveningForSaturdayEvening() {
        openSchedule()
        assertLabel("schedule-target", contains: "Sa 14.11. 18:00")
        XCTAssertTrue(any("schedule-chart").exists)
        let expected = [
            ("Fr 20:50", "Sauerteig ansetzen"), ("Fr 21:00", "Sauerteig reift"),
            ("Sa 08:04", "Hauptteig kneten"), ("Sa 08:24", "Stockgare"),
            ("Sa 09:25", "Teig formen"), ("Sa 09:40", "Stückgare"),
            ("Sa 10:25", "Ofen vorheizen"), ("Sa 11:10", "Backen"), ("Sa 12:00", "Auskühlen"),
        ]
        for (index, (time, title)) in expected.enumerated() {
            assertLabel("schedule-step-\(index)", contains: time)
            assertLabel("schedule-step-\(index)", contains: title)
        }
        // 21:00 to 08:04:22 is 11 h 4 min; warm bulk 1 h 0 min; proof 1.5 h.
        assertLabel("schedule-step-1", contains: "11 Std. 4 Min.")
        assertLabel("schedule-step-5", contains: "1 Std. 30 Min.")
        assertLabel("schedule-place-bulk", contains: "Warm (27 °C)")
        // Proof at 22 °C: 0.7 × 1.5 h = 1 h 3 min to 1.5 × 1.5 h = 2 h 15 min.
        assertText("schedule-range-proof", "Sinnvoll: 1 Std. 3 Min. bis 2 Std. 15 Min.")
        XCTAssertFalse(app.staticTexts["schedule-conflict-0"].exists)
        XCTAssertFalse(element(app.buttons, "schedule-reset").isEnabled)
    }

    func testARestCanBeLengthenedAndTheProposalRestored() {
        openSchedule()
        element(app.steppers, "schedule-stepper-proof").buttons.element(boundBy: 1).tap()
        assertLabel("schedule-step-5", contains: "2 Std. 0 Min.")
        // Shaping half an hour earlier.
        assertLabel("schedule-step-4", contains: "Sa 08:55")
        tapButton("schedule-reset")
        assertLabel("schedule-step-5", contains: "1 Std. 30 Min.")
        element(app.steppers, "schedule-stepper-proof").buttons.element(boundBy: 0).tap()
        assertLabel("schedule-step-5", contains: "1 Std. 3 Min.")
    }

    func testTheFridgeLengthensTheProofIntoTheNight() {
        openSchedule()
        // In the fridge at 5 °C: 1.5 h × 3^1.7 = 9.71 h = 9 h 43 min, from Saturday
        // 01:27, shaping 01:12. The bulk rest before it fits nowhere: at room
        // temperature (1.75 h) kneading is at Friday 23:07.
        choose("schedule-place-proof", "Kühlschrank (5 °C)")
        assertLabel("schedule-step-5", contains: "9 Std. 43 Min.")
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
