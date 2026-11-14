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
        let estimate = Feeding.estimate(date: epoch, grams: 120)
        #expect(StarterText.feedingLine(estimate, timeZone: utc)
                == "01.01.1970 00:00 · Übernommen: 120 g, Fütterung geschätzt")
        let young = Feeding(date: epoch, starterGrams: 20, flourGrams: 50, waterGrams: 50, rise: .doubled)
        #expect(StarterText.feedingLine(young, timeZone: utc)
                == "01.01.1970 00:00 · 20 g Starter + 50 g Mehl + 50 g Wasser · verdoppelt")
    }

    @Test func flourNames() {
        #expect(FlourType.allCases.map(\.germanName) == ["Roggen", "Weizen", "Dinkel", "Buchweizen"])
        #expect(FlourType.allCases.map(\.starterName) ==
                ["Roggensauerteig", "Weizensauerteig", "Dinkelsauerteig", "Buchweizensauerteig"])
    }

    @Test func stateTitlesAndHints() {
        let states: [StarterState] = [.rising, .peak, .pastPeak, .hungry, .neglected,
                                      .resting, .refreshRecommended, .refreshTwice]
        #expect(states.map(\.title) ==
                ["Reift", "Am Höhepunkt", "Über dem Höhepunkt", "Hungrig", "Lange nicht gefüttert",
                 "Ruht", "Auffrischen empfohlen", "Vor dem Backen zweimal auffrischen"])
        #expect(states.map(\.hint) == [
            "Der Starter geht noch auf.", "Jetzt ist er am besten zum Verwenden.",
            "Bald füttern oder verwenden.", "Jetzt füttern oder verwenden.",
            "Erst auffrischen, dann verwenden.",
            "Im Kühlschrank ruht er. Vor dem Backen einmal auffrischen.",
            "Frisch ihn bald auf, dann hält er wieder eine Weile.",
            "Er hat lange geruht. Vor dem Backen zweimal auffrischen, dann ist er wieder kräftig.",
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
        #expect(summary.refreshTwice == nil)
        // 10 + 15 + 15: 1 : 1,5 : 1,5; peak 6 h, hungry 2,5 × 6 = 15 h, neglected 4 × 6 = 24 h.
        #expect(summary.why == "Bei 22 °C und einem Verhältnis von 1 : 1,5 : 1,5 (Starter : Mehl : Wasser) "
                + "erwartet die App den Höhepunkt nach etwa 6 Std. 0 Min.; hungrig ist er nach etwa "
                + "15 Std. 0 Min., lange nicht gefüttert nach etwa 1 Tag 0 Std., jeweils ab der Fütterung. "
                + "Das sind Richtwerte, keine Messung.")
    }

    @Test func summaryInTheFridge() {
        // Rye at 14 °C: refresh from 7 days / 3 = 56 h (03.01. 08:00), twice
        // from 21 days / 3 = 168 h = 7 days (08.01. 00:00).
        let starter = Starter(
            name: "R", flour: .rye, createdAt: epoch,
            feedings: [Feeding(date: epoch, starterGrams: 20, flourGrams: 50, waterGrams: 50)],
            inFridge: true, fridgeCelsius: 14)
        let summary = StarterSummary(starter, now: epoch + 3600, timeZone: utc)
        #expect(summary.stateTitle == "Ruht")
        #expect(summary.feedByTitle == "Auffrischen ab")
        #expect(summary.feedBy == "03.01.1970 08:00")
        #expect(summary.feedByLine == "Auffrischen ab 03.01.1970 08:00")
        #expect(summary.refreshTwice == "08.01.1970 00:00")
        #expect(summary.bestWindow == "—")
        #expect(summary.why == "Bei 14 °C im Kühlschrank wächst der Starter kaum, die Mengen der Fütterung "
                + "zählen deshalb nicht. Die App empfiehlt das Auffrischen nach etwa 2 Tage 8 Std. und zweimal "
                + "Auffrischen vor dem Backen nach etwa 7 Tage 0 Std., jeweils ab der letzten Fütterung. "
                + "Das sind Richtwerte aus der Praxis, keine Messung.")
    }

    @Test func ratiosOfAFeeding() {
        #expect(StarterText.ratio(Feeding(date: epoch, starterGrams: 20, flourGrams: 50, waterGrams: 50))
                == "einem Verhältnis von 1 : 2,5 : 2,5")
        // 40 / 15 ≈ 2,67, to one decimal 2,7.
        #expect(StarterText.ratio(Feeding(date: epoch, starterGrams: 15, flourGrams: 40, waterGrams: 30))
                == "einem Verhältnis von 1 : 2,7 : 2")
        #expect(StarterText.ratio(Feeding.estimate(date: epoch, grams: 100)) == "dem angenommenen Verhältnis 1 : 1 : 1")
        #expect(StarterText.ratio(Feeding(date: epoch, starterGrams: 0, flourGrams: 50, waterGrams: 50))
                == "dem angenommenen Verhältnis 1 : 1 : 1")
    }

    @Test func theCheckNamesTheSigns() {
        for part in ["angenehm säuerlich", "Graue Flüssigkeit", "Nagellack", "Schimmel", "rosa und orange"] {
            #expect(StarterText.checkYourself.contains(part), "\(part)")
        }
    }

    @Test func noExplanationWithoutAFeeding() {
        // Only reachable with a status, which needs a feeding; the text guards anyway.
        let fed = Starter(name: "W", flour: .wheat, createdAt: epoch,
                          feedings: [Feeding(date: epoch, starterGrams: 10, flourGrams: 15, waterGrams: 15)],
                          inFridge: false)
        let status = fed.status(at: epoch)!
        #expect(StarterText.explanation(Starter(name: "A", flour: .rye, createdAt: epoch), status: status) == nil)
    }

    @Test func originsRisesAndPhases() {
        #expect(StarterOrigin.allCases.map(\.title) == ["Schon vorhanden", "Mit Anstellgut ansetzen", "Spontan ansetzen"])
        #expect(Rise.allCases.map(\.title) == ["Verdoppelt", "Etwas", "Nicht"])
        #expect(Rise.allCases.map(\.logText) == ["verdoppelt", "etwas aufgegangen", "nicht aufgegangen"])
        #expect(EstablishingPhase.allCases.map(\.title)
                == ["Frisch angesetzt", "Scheinblüte", "Ruhephase", "Wird stabil", "Dauert länger als üblich"])
        #expect(EstablishingPhase.allCases.map(\.hint) == [
            "Noch tut sich wenig. Halte ihn warm und füttere ihn einmal am Tag.",
            "Starkes Blubbern ist jetzt meist noch keine Hefe. Weiter füttern, noch nicht backen.",
            "Er wirkt fast tot, das ist normal. Füttere ihn weiter jeden Tag.",
            "Hefen und Milchsäurebakterien übernehmen. Achte darauf, ob er sich nach dem Füttern verdoppelt.",
            "Prüfe Wärme, Mehl und Wasser: Die Tipps unter „Starter selbst ansetzen“ nennen die häufigen Gründe.",
        ])
    }

    @Test func summaryInTheEstablishingPhase() {
        // Mixed at 0, fed after 1 day (doubled); 3.5 days after mixing: day 4,
        // quiet phase at 22 °C (3 to 5 days), feed by 1 + 1 = 2 days (02.01. 00:00
        // + 1 day = 03.01. 00:00), usually ready by 10 days (11.01. 00:00).
        let day: TimeInterval = 86_400
        let starter = Starter(
            name: "J", flour: .rye, createdAt: epoch,
            feedings: [Feeding(date: epoch, starterGrams: 0, flourGrams: 50, waterGrams: 50),
                       Feeding(date: epoch + day, starterGrams: 20, flourGrams: 50, waterGrams: 50, rise: .doubled)],
            inFridge: false, origin: .spontaneous)
        let summary = StarterSummary(starter, now: epoch + 3.5 * day, timeZone: utc)
        #expect(summary.stateTitle == "Ansetzphase · Tag 4")
        #expect(summary.hint == "Er wirkt fast tot, das ist normal. Füttere ihn weiter jeden Tag.")
        #expect(summary.establishing == StarterSummary.Establishing(
            phase: "Ruhephase", doubled: "1 von 2", usuallyReadyBy: "11.01.1970 00:00"))
        #expect(summary.feedByTitle == "Füttern bis")
        #expect(summary.feedBy == "03.01.1970 00:00")
        #expect(summary.feedByLine == "Füttern bis 03.01.1970 00:00")
        #expect(summary.bestWindow == "—")
        #expect(summary.ageTitle == "Angesetzt vor")
        #expect(summary.age == "3 Tage 12 Std.")
        #expect(summary.readySince == nil)
    }

    @Test func summaryOfAReadyStarterSaysSinceWhen() {
        // Doubled after the feedings at 1 and 2 days: ready since 03.01. 00:00.
        let day: TimeInterval = 86_400
        let starter = Starter(
            name: "J", flour: .rye, createdAt: epoch,
            feedings: [Feeding(date: epoch, starterGrams: 0, flourGrams: 50, waterGrams: 50),
                       Feeding(date: epoch + day, starterGrams: 20, flourGrams: 50, waterGrams: 50, rise: .doubled),
                       Feeding(date: epoch + 2 * day, starterGrams: 20, flourGrams: 50, waterGrams: 50, rise: .doubled)],
            inFridge: false, origin: .spontaneous)
        let summary = StarterSummary(starter, now: epoch + 2 * day, timeZone: utc)
        #expect(summary.readySince == "03.01.1970 00:00")
        #expect(summary.establishing == nil)
        #expect(summary.stateTitle == "Reift")
        #expect(summary.feedByLine.hasPrefix("Füttern oder verwenden bis "))
    }

    @Test func anExistingStarterIsWithYouSince() {
        let starter = Starter(name: "A", flour: .rye, createdAt: epoch, origin: .existing)
        let summary = StarterSummary(starter, now: epoch + 7200, timeZone: utc)
        #expect(summary.ageTitle == "Bei dir seit")
        #expect(summary.age == "2 Std. 0 Min.")
    }

    @Test func summaryOfAStarterThatWasNeverFed() {
        let summary = StarterSummary(Starter(name: "A", flour: .rye, createdAt: epoch),
                                     now: epoch, timeZone: utc)
        #expect(summary.stateTitle == "Noch nicht gefüttert")
        #expect(summary.hint == "Noch nicht gefüttert")
        #expect(summary.feedBy == "—")
        #expect(summary.bestWindow == "—")
        #expect(summary.feedByLine == "Füttern oder verwenden bis —")
        #expect(summary.establishing == nil)
        #expect(summary.why == nil)
        #expect(summary.refreshTwice == nil)
    }
}
