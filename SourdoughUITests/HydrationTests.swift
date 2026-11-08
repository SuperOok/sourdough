import XCTest

/// The calculator: every field is operated and its effect read back.
@MainActor
final class HydrationTests: SourdoughUITestCase {
    override func setUp() async throws {
        try await super.setUp()
        launch()
        tapButton("start-calculator")
    }

    private func enter(_ text: String, in id: String) {
        let field = element(app.textFields, id)
        field.tap()
        field.typeText(text)
    }

    private var result: XCUIElement { text("hydration-result") }

    func testTheStartShowsThePlaceholderAndNoError() {
        XCTAssertEqual(result.label, "—")
        XCTAssertFalse(app.staticTexts["input-error"].exists)
    }

    func testHydrationFollowsTheInput() {
        enter("1000", in: "flour-field")
        enter("700", in: "water-field")
        XCTAssertEqual(result.label, "70,0 %")
        enter("200", in: "starter-field")
        // (700 + 100) / (1000 + 100) = 72.7 %
        XCTAssertEqual(result.label, "72,7 %")
    }

    func testInvalidInputShowsAnErrorAndRecovers() {
        enter("1000", in: "flour-field")
        enter("1.2.3", in: "water-field")
        XCTAssertTrue(app.staticTexts["input-error"].waitForExistence(timeout: 5))
        XCTAssertEqual(result.label, "—")
        let water = app.textFields["water-field"]
        // Tap right of the text so the cursor lands at its end.
        water.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        water.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "500")
        XCTAssertEqual(water.value as? String, "500")
        XCTAssertTrue(app.staticTexts["input-error"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(result.label, "50,0 %")
    }

    func testTheBackButtonLeadsToTheStartScreen() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        _ = element(app.buttons, "start-calculator")
    }
}
