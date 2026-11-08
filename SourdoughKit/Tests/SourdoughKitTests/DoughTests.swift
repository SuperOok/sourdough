import Testing
@testable import SourdoughKit

// Expected values are worked out by hand, never taken from a program run.
struct DoughTests {
    @Test func hydrationWithoutStarter() {
        // 700 g water per 1000 g flour: 70 %.
        let dough = Dough(flour: 1000, water: 700, starter: 0)
        #expect(dough.totalFlour == 1000)
        #expect(dough.totalWater == 700)
        #expect(dough.hydration == 70)
    }

    @Test func starterAtHundredPercentSplitsEvenly() {
        // 200 g starter at 100 % = 100 g flour + 100 g water.
        // Flour 1000 + 100 = 1100, water 700 + 100 = 800, 800 / 1100 = 72.727…
        let dough = Dough(flour: 1000, water: 700, starter: 200)
        #expect(dough.totalFlour == 1100)
        #expect(dough.totalWater == 800)
        #expect(abs(dough.hydration! - 72.7272727) < 1e-6)
    }

    @Test func starterWithOtherHydration() {
        // 150 g starter at 50 %: flour 150 * 100 / 150 = 100, water 50.
        let dough = Dough(flour: 500, water: 350, starter: 150, starterHydration: 50)
        #expect(dough.totalFlour == 600)
        #expect(dough.totalWater == 400)
        #expect(abs(dough.hydration! - 66.6666667) < 1e-6)
    }

    @Test func noFlourHasNoHydration() {
        #expect(Dough(flour: 0, water: 100, starter: 0).hydration == nil)
    }
}
