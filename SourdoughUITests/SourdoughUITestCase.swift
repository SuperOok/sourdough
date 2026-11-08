import XCTest

/// Common ground for the interface tests: launching in a defined state and
/// a few helpers. `-skipSplash` goes straight to the start screen,
/// `-resetData` forgets saved equipment, `-seedEquipment all|none` saves some
/// without the wizard; a relaunch within one test leaves
/// `-resetData` out to prove that data survives.
@MainActor
class SourdoughUITestCase: XCTestCase {
    var app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func launch(skipSplash: Bool = true, reset: Bool = true, splashSeconds: Int? = nil,
                seed: String? = nil) {
        app = XCUIApplication()
        var arguments: [String] = []
        if skipSplash { arguments.append("-skipSplash") }
        if reset { arguments.append("-resetData") }
        if let splashSeconds { arguments += ["-splashSeconds", String(splashSeconds)] }
        if let seed { arguments += ["-seedEquipment", seed] }
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
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(id) fehlt.", file: file, line: line)
        return element
    }

    func tapButton(_ id: String) {
        element(app.buttons, id).tap()
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
        _ = element(app.buttons, "equipment-edit")
    }

    func text(_ id: String) -> XCUIElement { element(app.staticTexts, id) }

    func next() { tapButton("wizard-next") }

    /// Waits for the title to change: a pushed page slides in while the old
    /// title is still on screen.
    func assertTitle(_ expected: String, line: UInt = #line) {
        let title = element(app.staticTexts, "tips-title")
        let done = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expected), object: title)
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 5), .completed,
                       "Titel ist nicht \(expected).", line: line)
    }


    func assertStep(_ title: String, line: UInt = #line) {
        XCTAssertTrue(app.navigationBars[title].firstMatch.waitForExistence(timeout: 5),
                      "Schritt \(title) fehlt.", line: line)
    }
}
