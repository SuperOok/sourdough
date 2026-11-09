import XCTest

/// Common ground for the interface tests: launching in a defined state and
/// a few helpers. `-skipSplash` goes straight to the start screen,
/// `-resetData` forgets saved data, `-seedEquipment all` saves five pieces of
/// equipment, `-seedStarters demo` two starters; a relaunch within one test leaves
/// `-resetData` out to prove that data survives.
@MainActor
class SourdoughUITestCase: XCTestCase {
    var app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// The Friday morning the bake tests plan from (local time).
    static let friday = "2026-11-13T09:00"

    func launch(skipSplash: Bool = true, reset: Bool = true, splashSeconds: Int? = nil,
                seedEquipment: Bool = false, seedStarters: Bool = false, now: String? = nil) {
        app = XCUIApplication()
        var arguments: [String] = []
        if skipSplash { arguments.append("-skipSplash") }
        if reset { arguments.append("-resetData") }
        if let splashSeconds { arguments += ["-splashSeconds", String(splashSeconds)] }
        if seedEquipment { arguments += ["-seedEquipment", "all"] }
        if seedStarters { arguments += ["-seedStarters", "demo"] }
        if let now { arguments += ["-now", now] }
        app.launchArguments = arguments
        app.launch()
    }

    func relaunch() {
        app.terminate()
        launch(reset: false)
    }

    @discardableResult
    func element(_ query: XCUIElementQuery, _ id: String,
                 file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = query[id]
        if !element.waitForExistence(timeout: 4) { reveal(element) }
        if !element.exists { print("FEHLT \(id):\n\(app.debugDescription)") }
        XCTAssertTrue(element.exists, "\(id) fehlt.", file: file, line: line)
        return element
    }

    /// Lists build their rows lazily, so a row below the fold is not on screen
    /// yet: scroll down, and back up if it was above.
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<4 where !element.exists { app.swipeUp() }
        for _ in 0..<8 where !element.exists { app.swipeDown() }
        _ = element.waitForExistence(timeout: 3)
    }

    func tapButton(_ id: String) {
        let button = element(app.buttons, id)
        // A row at the very bottom exists but cannot be tapped yet.
        if !button.isHittable { app.swipeUp() }
        button.tap()
    }

    /// Flips a switch and checks that it took.
    func flip(_ id: String, to expected: Bool) {
        let toggle = element(app.switches, id)
        if (toggle.value as? String == "1") != expected {
            // The row's centre is its label; the switch sits at the right edge.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        let predicate = NSPredicate(format: "value == %@", expected ? "1" : "0")
        let done = XCTNSPredicateExpectation(predicate: predicate, object: toggle)
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 5), .completed, "\(id) steht falsch.")
    }

    func openEquipment() {
        tapButton("start-equipment")
        _ = element(app.buttons, "equipment-add")
    }

    func text(_ id: String) -> XCUIElement { element(app.staticTexts, id) }

    /// Waits until the static text with this identifier has this label: a
    /// pushed page slides in while the old text is still on screen, and a
    /// state changes a moment after the tap.
    func assertText(_ id: String, _ expected: String, line: UInt = #line) {
        let label = element(app.staticTexts, id)
        let done = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expected), object: label)
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 5), .completed,
                       "\(id) ist nicht \(expected), sondern \(label.label).", line: line)
    }

    func assertTitle(_ expected: String, line: UInt = #line) {
        assertText("tips-title", expected, line: line)
    }

    /// Replaces the text of a number field: tapping a number field selects
    /// all of its text, so typing replaces it.
    func replaceText(_ id: String, with text: String) {
        let field = element(app.textFields, id)
        // The element spans the whole row, but only its right end is the text
        // field; the rest is the label (which is long for the temperature).
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        // Keys typed before the keyboard is up are lost.
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Keine Tastatur für \(id).")
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text, "\(id) hat nicht den getippten Wert.")
        // Put the keyboard away so it does not cover the next field.
        if app.buttons["keyboard-done"].exists { app.buttons["keyboard-done"].tap() }
    }

    /// Any element with this identifier, whatever its type.
    func any(_ id: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        element(app.descendants(matching: .any), id, file: file, line: line)
    }

    /// Opens a menu picker and picks the option with this label. A segment
    /// below may have the same label; while the menu is open it cannot be
    /// tapped, the menu's button can.
    func choose(_ id: String, _ option: String, line: UInt = #line) {
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", option))
        let before = matches.count
        tapButton(id)
        let open = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count > %d", before), object: matches)
        XCTAssertEqual(XCTWaiter().wait(for: [open], timeout: 5), .completed, "\(option) fehlt in \(id).", line: line)
        // A menu that is still opening swallows the tap: wait until one of
        // the buttons can be tapped.
        var item: XCUIElement?
        for _ in 0..<10 where item == nil {
            item = (0..<matches.count).map(matches.element(boundBy:)).first(where: \.isHittable)
            if item == nil { _ = app.wait(for: .runningForeground, timeout: 0.5) }
        }
        XCTAssertNotNil(item, "\(option) lässt sich nicht tippen.", line: line)
        item?.tap()
    }

    /// Waits until the element with this identifier has a label containing `part`.
    func assertLabel(_ id: String, contains part: String, line: UInt = #line) {
        let element = any(id, line: line)
        let done = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", part), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 5), .completed,
                       "\(id) enthält nicht \(part), sondern: \(element.label)", line: line)
    }

    func openBake() {
        tapButton("start-bake")
        _ = element(app.buttons, "plan-bread")
    }

    func openStarters() {
        tapButton("start-starters")
        _ = element(app.buttons, "starter-add")
    }
}
