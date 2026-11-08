import Testing
@testable import Sourdough

// Expected values are worked out by hand, never taken from a program run.
struct DoughViewModelTests {
    @Test(arguments: [("", 0.0), ("  ", 0.0), ("12", 12.0), ("12,5", 12.5), ("12.5", 12.5), (" 7 ", 7.0)])
    func parsesValidInput(text: String, expected: Double) {
        #expect(DoughViewModel.parse(text) == expected)
    }

    @Test(arguments: ["abc", "1.2.3", "-5", "inf", "nan"])
    func rejectsInvalidInput(text: String) {
        #expect(DoughViewModel.parse(text) == nil)
    }

    @Test func emptyModelShowsPlaceholderAndIsValid() {
        let model = DoughViewModel()
        #expect(model.isInputValid)
        #expect(model.hydrationText == "—")
    }

    @Test func showsHydrationWithGermanDecimalComma() {
        // 1000 g flour, 700 g water, 200 g starter at 100 %:
        // 800 / 1100 = 72.7 %.
        let model = DoughViewModel()
        model.flourText = "1000"
        model.waterText = "700"
        model.starterText = "200"
        #expect(model.hydrationText == "72,7 %")
    }

    @Test func invalidInputIsReportedAndShowsPlaceholder() {
        let model = DoughViewModel()
        model.flourText = "1000"
        model.waterText = "x"
        #expect(!model.isInputValid)
        #expect(model.dough == nil)
        #expect(model.hydrationText == "—")
    }
}
