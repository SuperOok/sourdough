import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

// Expected values are worked out by hand.
struct StarterTextTests {
    private let utc = TimeZone(identifier: "UTC")!
    private let epoch = Date(timeIntervalSince1970: 0)

    @Test(arguments: [
        (273_600.0, "3 Tage 4 Std."),   // 3 × 86400 + 4 × 3600
        (86_400.0, "1 Tag 0 Std."),
        (7_500.0, "2 Std. 5 Min."),     // 2 × 3600 + 5 × 60
        (2_400.0, "40 Min."),
        (59.0, "0 Min."),
        (-30.0, "0 Min."),
    ])
    func durations(seconds: Double, expected: String) {
        #expect(StarterText.duration(seconds) == expected)
    }

    @Test func datesAreShownInGermanFormat() {
        #expect(StarterText.date(epoch, timeZone: utc) == "01.01.1970 00:00")
        // 1 000 000 s = 11 days 13:46:40
        #expect(StarterText.date(Date(timeIntervalSince1970: 1_000_000), timeZone: utc)
                == "12.01.1970 13:46")
    }

    @Test func datesFollowTheTimeZone() {
        // Berlin is one hour ahead of UTC in January.
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        #expect(StarterText.date(Date(timeIntervalSince1970: 1_000_000), timeZone: berlin)
                == "12.01.1970 14:46")
    }

    @Test func numbersUseACommaAndDropWholeDecimals() {
        #expect(StarterText.number(50) == "50")
        #expect(StarterText.number(0) == "0")
        #expect(StarterText.number(12.5) == "12,5")
        #expect(StarterText.grams(50) == "50 g")
        #expect(StarterText.grams(12.5) == "12,5 g")
    }

    @Test func feedingLines() {
        let first = Feeding(date: epoch, starterGrams: 0, flourGrams: 50, waterGrams: 50)
        #expect(StarterText.feedingLine(first, timeZone: utc)
                == "01.01.1970 00:00 · Ansatz: 50 g Mehl + 50 g Wasser")
        let later = Feeding(date: epoch, starterGrams: 20, flourGrams: 50, waterGrams: 50)
        #expect(StarterText.feedingLine(later, timeZone: utc)
                == "01.01.1970 00:00 · 20 g Starter + 50 g Mehl + 50 g Wasser")
    }

    @Test func flourNames() {
        #expect(FlourType.allCases.map(\.germanName) == ["Roggen", "Weizen", "Dinkel", "Buchweizen"])
        #expect(FlourType.allCases.map(\.starterName) ==
                ["Roggensauerteig", "Weizensauerteig", "Dinkelsauerteig", "Buchweizensauerteig"])
    }

    @Test func stateTitlesAndHints() {
        let states: [StarterState] = [.rising, .peak, .pastPeak, .hungry, .neglected]
        #expect(states.map(\.title) ==
                ["Reift", "Am Höhepunkt", "Über dem Höhepunkt", "Hungrig", "Lange nicht gefüttert"])
        #expect(states.map(\.hint) == [
            "Der Starter geht noch auf.", "Jetzt ist er am besten zum Verwenden.",
            "Bald füttern oder verwenden.", "Jetzt füttern oder verwenden.",
            "Erst auffrischen, dann verwenden.",
        ])
    }

    @Test func summaryOfAFedStarter() {
        // Wheat at room temperature, dilution 4: peak 6 h, window 4.5 … 9 h, feed by 15 h.
        let starter = Starter(
            name: "W", flour: .wheat, createdAt: epoch,
            feedings: [Feeding(date: epoch, starterGrams: 10, flourGrams: 15, waterGrams: 15)],
            inFridge: false)
        let summary = StarterSummary(starter, now: epoch.addingTimeInterval(3 * 3600), timeZone: utc)
        #expect(summary.stateTitle == "Reift")
        #expect(summary.hint == "Der Starter geht noch auf.")
        #expect(summary.age == "3 Std. 0 Min.")
        #expect(summary.feedBy == "01.01.1970 15:00")
        #expect(summary.bestWindow == "01.01.1970 04:30 – 01.01.1970 09:00")
    }

    @Test func summaryOfAStarterThatWasNeverFed() {
        let summary = StarterSummary(Starter(name: "A", flour: .rye, createdAt: epoch),
                                     now: epoch, timeZone: utc)
        #expect(summary.stateTitle == "Noch nicht gefüttert")
        #expect(summary.hint == "Noch nicht gefüttert")
        #expect(summary.feedBy == "—")
        #expect(summary.bestWindow == "—")
    }
}
