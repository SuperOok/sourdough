import UIKit
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
        _ = element(app.datePickers, "schedule-time")
    }

    /// The compact date picker: a button that carries date and time as its
    /// value, and inside it one button for the date and one for the time, in
    /// this order (`buttons` lists the outer one first).
    private var picker: XCUIElement { element(app.datePickers, "schedule-time") }
    private var dateButton: XCUIElement { picker.buttons.element(boundBy: 1) }
    private var timeButton: XCUIElement { picker.buttons.element(boundBy: 2) }

    /// A moment of November 2026 in the time zone of the device, which is what
    /// the app plans in.
    private func moment(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    /// How the picker writes a moment, as far as it does not depend on the
    /// language: the time as the system writes it, the day and the year as
    /// digits. The month is a name in the language of the app, which the test
    /// process need not share ("Nov." and "Nov"); the days planned here are
    /// all in November. The label of a day in the month grid of the popover
    /// ends on the day and the month in full ("14. November").
    private func timeText(_ moment: Date) -> String {
        moment.formatted(.dateTime.hour().minute())
    }
    private func digits(_ moment: Date) -> [String] {
        let parts = Calendar.current.dateComponents([.day, .year], from: moment)
        return [String(parts.day!), String(parts.year!)]
    }
    private func dayText(_ moment: Date) -> String {
        moment.formatted(.dateTime.day().month(.wide))
    }

    /// Waits until the picker shows this time and this date.
    private func assertPicker(_ moment: Date, line: UInt = #line) {
        let value = picker.buttons.firstMatch
        for part in [timeText(moment)] + digits(moment) {
            let done = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", part),
                                                 object: value)
            XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 5), .completed,
                           "Der Wähler zeigt nicht \(part), sondern \(String(describing: value.value)).", line: line)
        }
    }

    /// Taps a day in the month grid of the opened date popover.
    private func tapDay(_ moment: Date, line: UInt = #line) {
        let day = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", dayText(moment))).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5), "Kein Tag \(dayText(moment)) im Kalender.", line: line)
        day.tap()
    }

    /// Closes the popover of the picker by tapping beside it.
    private func closePopover() {
        app.buttons["PopoverDismissRegion"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97)).tap()
        XCTAssertTrue(app.buttons["PopoverDismissRegion"].waitForNonExistence(timeout: 5), "Das Popover blieb offen.")
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
        let saturday = moment(14, 18, 0)
        assertPicker(saturday)
        // The two buttons inside the picker are the date and the time.
        for part in digits(saturday) { XCTAssertTrue(dateButton.label.contains(part), dateButton.label) }
        XCTAssertEqual(timeButton.label, timeText(saturday))
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
        assertText("schedule-needed-proof", "Für 2 Std. 0 Min. passen etwa 19 °C.")
        // Another half hour: 2 h 30 min are in the range of the cool place, the
        // proof moves there, and the line names 22 − 10 × log₃(2.5 / 1.5) = 17.35 °C.
        more.tap()
        assertLabel("schedule-step-5", contains: "2 Std. 30 Min.")
        assertLabel("schedule-step-4", contains: "Sa 08:25")
        assertLabel("schedule-place-proof", contains: "Kühl (16 °C)")
        assertText("schedule-needed-proof", "Für 2 Std. 30 Min. passen etwa 17 °C.")
        tapButton("schedule-reset")
        assertLabel("schedule-step-5", contains: "1 Std. 30 Min.")
        // The line is there for the proposal too: 1.5 h are the rule's time at 22 °C.
        assertText("schedule-needed-proof", "Für 1 Std. 30 Min. passen etwa 22 °C.")
        // A shorter proof moves to the warm place: 1 h at 27 °C is in its range,
        // and 22 − 10 × log₃(1 / 1.5) = 25.7 °C goes with it.
        element(app.steppers, "schedule-stepper-proof").buttons.element(boundBy: 0).tap()
        assertLabel("schedule-step-5", contains: "1 Std. 0 Min.")
        assertLabel("schedule-place-proof", contains: "Warm (27 °C)")
        assertText("schedule-needed-proof", "Für 1 Std. 0 Min. passen etwa 26 °C.")
    }

    func testPlusAndMinusStayWhereTheyAreWhateverTheLineSays() {
        openSchedule()
        let more = element(app.steppers, "schedule-stepper-proof").buttons.element(boundBy: 1)
        let line = text("schedule-needed-proof")
        let before = (more.frame.minY, line.frame.minY)
        // "Für 1 Std. 30 Min. passen etwa 22 °C." becomes another text, and the
        // proof moves to another place, with a shorter name ("Kühl (16 °C)"
        // for "Raumtemperatur (22 °C)", which once took two lines): the line
        // and the controls below the bar stay. The rows above change too (the
        // plan moves earlier), so they must not move this one either.
        more.tap()
        assertText("schedule-needed-proof", "Für 2 Std. 0 Min. passen etwa 19 °C.")
        XCTAssertEqual(more.frame.minY, before.0, accuracy: 0.5)
        XCTAssertEqual(line.frame.minY, before.1, accuracy: 0.5)
        more.tap()
        assertText("schedule-needed-proof", "Für 2 Std. 30 Min. passen etwa 17 °C.")
        XCTAssertEqual(more.frame.minY, before.0, accuracy: 0.5)
        XCTAssertEqual(line.frame.minY, before.1, accuracy: 0.5)
        XCTAssertLessThan(line.frame.height, 25, "Die Zeile ist einzeilig.")
    }

    func testTheTemperaturePageOpensFromTheRoomTemperature() {
        openSchedule()
        tapButton("schedule-tip-temperature")
        assertTitle("Temperatur und Zeit")
        tapButton("tips-topic-close")
        _ = element(app.datePickers, "schedule-time")
    }

    func testTheLightbulbSitsBeforeTheRoomBoxAndTheBoxesLineUp() {
        openSchedule()
        let room = any("schedule-room").frame
        let bulb = any("schedule-tip-temperature").frame
        // The other rows are one element each, label and box; the box is its
        // right 96 points (the width of every number box). The room field is
        // an element of its own because of the lightbulb, and that element is
        // the text inside the grey capsule (`inputBox`), which is inset by
        // 12 points on each side: so it ends 12 points before the row and is
        // 96 − 2 × 12 = 72 points wide, while its capsule lines up.
        let inset = 12.0
        let fridge = any("schedule-fridge").frame
        let cool = any("schedule-cool").frame
        XCTAssertEqual(room.maxX + inset, fridge.maxX, accuracy: 1, "Die Raumtemperatur sitzt nicht bündig.")
        XCTAssertEqual(room.maxX + inset, cool.maxX, accuracy: 1)
        XCTAssertEqual(room.width, 96 - 2 * inset, accuracy: 1)
        // The lightbulb is between the label and the box, inside the row.
        XCTAssertLessThanOrEqual(bulb.maxX, room.minX - inset)
        XCTAssertGreaterThan(bulb.minX, fridge.minX)
        XCTAssertEqual(bulb.midY, room.midY, accuracy: 3)
    }

    func testTheRestControlsWrapAndStayReachableAtAccessibilitySizes() {
        launch(seedEquipment: true, now: Self.friday,
               extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])
        openBake()
        tapButton("plan-next")
        tapButton("setup-next")
        _ = element(app.datePickers, "schedule-time")
        // The hint is longer than the screen is wide here: it takes more than
        // one line of its font (the footnote style at this size) instead of
        // being cut off, and its text is the whole sentence.
        let line = text("schedule-needed-proof")
        scrollTo(line)
        assertText("schedule-needed-proof", "Für 1 Std. 30 Min. passen etwa 22 °C.")
        let oneLine = UIFont.preferredFont(
            forTextStyle: .footnote,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityLarge)).lineHeight
        XCTAssertGreaterThan(line.frame.height, 1.5 * oneLine, "Der Hinweis ist abgeschnitten.")
        let range = text("schedule-range-proof")
        XCTAssertGreaterThan(range.frame.height, 1.5 * oneLine, "Die Spanne ist abgeschnitten.")
        // The place and the stepper are under each other, both on screen.
        let place = element(app.buttons, "schedule-place-proof")
        let stepper = element(app.steppers, "schedule-stepper-proof")
        scrollTo(stepper)
        XCTAssertTrue(place.isHittable, "Der Ortswähler liegt nicht im Bild.")
        XCTAssertTrue(stepper.isHittable, "Der Stepper liegt nicht im Bild.")
        XCTAssertGreaterThanOrEqual(stepper.frame.minY, place.frame.maxY - 1, "Der Stepper steht nicht unter dem Ort.")
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(place.frame.minX, screen.minX)
        XCTAssertLessThanOrEqual(place.frame.maxX, screen.maxX)
        XCTAssertLessThanOrEqual(stepper.frame.maxX, screen.maxX)
        // And it still works.
        stepper.buttons.element(boundBy: 1).tap()
        assertText("schedule-needed-proof", "Für 2 Std. 0 Min. passen etwa 19 °C.")
    }

    /// Scrolls the form up until `element` can be tapped.
    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<12 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable, "\(element) liegt nicht im Bild.")
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
        _ = element(app.datePickers, "schedule-time")
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
        dateButton.tap()
        tapDay(moment(16, 18, 0))
        closePopover()
        assertPicker(moment(16, 18, 0))
        assertLabel("schedule-step-8", contains: "Mo 12:00")
    }

    func testTheDateFieldFixesEitherEndOfThePlanAndShowsTheOther() {
        openSchedule()
        // Ready on Saturday 18:00 is mixing on Friday 16:26, as in the steps.
        assertText("schedule-result", "Sauerteig ansetzen: Fr 16:26")
        // Switching keeps the plan: the field takes the start (the picker shows
        // 16:26), and the result is the end, Saturday 18:00, as before.
        choose("schedule-anchor", "Sauerteig ansetzen")
        assertPicker(moment(13, 16, 26))
        assertText("schedule-result", "Anschnittfertig: Sa 18:00")
        let reference = ["Fr 16:26", "Fr 16:36", "Sa 08:04", "Sa 08:24", "Sa 09:25", "Sa 09:40", "Sa 10:25",
                         "Sa 11:10", "Sa 12:00"]
        for (index, time) in reference.enumerated() {
            assertLabel("schedule-step-\(index)", contains: time)
        }
        assertLabel("schedule-place-sourdough", contains: "Kühl (16 °C)")
        assertLabel("schedule-place-bulk", contains: "Warm (27 °C)")
        // A day later: every rest keeps its place and time, so the plan moves
        // by exactly a day, as the plan lies on whole minutes: Saturday 16:26
        // + 10 min = 16:36; + 928 min = Sunday 08:04; + 20 min kneading = 08:24;
        // + 61 min = 09:25; + 15 min shaping = 09:40; + 90 min = 11:10
        // (preheating 10:25); baking 50 min to 12:00; + 6 h cooling = 18:00.
        dateButton.tap()
        tapDay(moment(14, 16, 26))
        closePopover()
        assertPicker(moment(14, 16, 26))
        assertText("schedule-result", "Anschnittfertig: So 18:00")
        let later = ["Sa 16:26", "Sa 16:36", "So 08:04", "So 08:24", "So 09:25", "So 09:40", "So 10:25",
                     "So 11:10", "So 12:00"]
        for (index, time) in later.enumerated() {
            assertLabel("schedule-step-\(index)", contains: time)
        }
        assertLabel("schedule-place-sourdough", contains: "Kühl (16 °C)")
        // And back: the field takes the end (Sunday 18:00), the start is the
        // result and is where it was.
        choose("schedule-anchor", "Anschnittfertig")
        assertPicker(moment(15, 18, 0))
        assertText("schedule-result", "Sauerteig ansetzen: Sa 16:26")
        for (index, time) in later.enumerated() {
            assertLabel("schedule-step-\(index)", contains: time)
        }
    }

    func testTheTimeComesFromTheWheels() {
        openSchedule()
        timeButton.tap()
        let minutes = app.pickerWheels.element(boundBy: 1)
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        // The wheel reads "00 minutes" (in the language of the device), but
        // its values are the bare numbers "00" to "59".
        minutes.adjust(toPickerWheelValue: "30")
        closePopover()
        // Ready 18:30: baking ends 12:30 (cooling 6 h), from 11:40, preheating
        // from 10:55; proof 1.5 h at room temperature from 10:10, shaping 09:55.
        // The bulk rest no longer needs the warm place: at room temperature
        // kneading may start at 08:00, which leaves it 09:55 − 08:20 = 1 h
        // 35 min, within 0.85 × 1.75 h = 1 h 29 min and 1.2 × 1.75 h. The
        // sourdough ends at 08:00 and takes 8 × 3^0.6 = 15 h 28 min at the cool
        // place: from Friday 16:32, mixed at 16:22.
        assertPicker(moment(14, 18, 30))
        let expected = ["Fr 16:22", "Fr 16:32", "Sa 08:00", "Sa 08:20", "Sa 09:55", "Sa 10:10", "Sa 10:55",
                        "Sa 11:40", "Sa 12:30"]
        for (index, time) in expected.enumerated() {
            assertLabel("schedule-step-\(index)", contains: time)
        }
        assertLabel("schedule-step-3", contains: "1 Std. 35 Min.")
        assertLabel("schedule-place-sourdough", contains: "Kühl (16 °C)")
        assertLabel("schedule-place-bulk", contains: "Raumtemperatur (22 °C)")
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
