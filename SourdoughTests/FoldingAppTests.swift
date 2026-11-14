import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

// Expected values are worked out by hand, never taken from a program run.

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// November 2026, UTC; the 14th is a Saturday.
private func nov(_ day: Int, _ hour: Int, _ minute: Double = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))! + minute * 60
}

private let roomChoices: [RestKind: RestChoice] = [
    .sourdough: RestChoice(place: .room, hours: 8), .bulk: RestChoice(place: .room, hours: 3),
    .proof: RestChoice(place: .room, hours: 1.5)]

/// A bread on the tray, started forwards on Saturday 08:00: mixed until
/// 08:10, sourdough 8 h until 16:10, kneading until 16:30, then the bulk rest.
/// Wheat bread by hand has 3 rounds, 30 min apart: 17:00, 17:30, 18:00.
private func bake(_ bread: BreadType = .wheatBread, kneader: EquipmentItem? = nil,
                  choices: [RestKind: RestChoice] = roomChoices) -> BakeRun {
    BakeRun(startedAt: nov(13, 9), bread: bread, mix: bread.preset, totalGrams: 500, limits: [:], starter: nil,
            setup: BakeSetup(vessel: .tray, kneader: kneader), temperatures: Temperatures(),
            window: InteractionWindow(), anchor: .start, time: nov(14, 8), choices: choices, timeZone: utc.timeZone)
}

private let hook = EquipmentItem(kind: .kneader, name: "Bosch")

struct FoldingRunTextTests {
    @Test func kneadingNamesTheRoundsAndTheirTimes() {
        let values = BakeRunText.values(for: bake(), step: .knead)
        #expect(values[.folding] == "Dehne und falte ihn in dieser Zeit dreimal: um 17:00, 17:30 und 18:00. "
                + "Die App führt dich durch jede Runde.")
        // 3 h at room temperature are 22 °C.
        #expect(values[.restTemperature] == "bei etwa 22 °C")
        #expect(BakeRunText.markdown(bake(), .knead).contains("Diese Ruhe heißt [Stockgare](tip:proofing). "
                                                              + "Dehne und falte ihn in dieser Zeit dreimal"))
    }

    @Test func eachRoundSaysWhatComesNext() {
        let run = bake()
        #expect(BakeRunText.values(for: run, step: .fold, round: 1)[.afterFold] == "Die nächste Runde ist um Sa 17:30.")
        #expect(BakeRunText.values(for: run, step: .fold, round: 2)[.afterFold] == "Die nächste Runde ist um Sa 18:00.")
        // The bulk rest ends 16:30 + 3 h.
        #expect(BakeRunText.values(for: run, step: .fold, round: 3)[.afterFold]
                == "Das war die letzte Runde. Lass ihn jetzt ungestört gehen, bis Sa 19:30.")
        // Without a round given, the first.
        #expect(BakeRunText.values(for: run, step: .fold)[.afterFold] == "Die nächste Runde ist um Sa 17:30.")
        #expect(BakeRunText.values(for: run, step: .fold)[.foldGentle] == "")
    }

    @Test func aRoundHasItsNumberInTheTitle() {
        let run = bake()
        #expect(BakeRunText.title(run, .fold, round: 2) == "Dehnen und Falten (2 von 3)")
        #expect(BakeRunText.title(run, .fold) == "Dehnen und Falten")
        #expect(BakeRunText.markdown(run, .fold, round: 2).hasPrefix("# Dehnen und Falten (2 von 3)\n"))
        #expect(BakeRunText.markdown(run, .fold).hasPrefix("# Dehnen und Falten\n"))
        #expect(BakeRunText.undoLabel(run, .fold, round: 1) == "Zurück zu „Dehnen und Falten (1 von 3)“")
        // Every placeholder is filled.
        #expect(!BakeRunText.markdown(run, .fold, round: 3).contains("{"))
    }

    @Test func withAHookTheMachineMayStandIn() {
        // A machine takes a round: 2 rounds, 17:00 and 17:30.
        let run = bake(kneader: hook)
        #expect(BakeRunText.values(for: run, step: .knead)[.folding]
                == "Dehne und falte ihn in dieser Zeit zweimal: um 17:00 und 17:30. Die App führt dich durch jede Runde.")
        #expect(BakeRunText.title(run, .fold, round: 1) == "Dehnen und Falten oder kurz kneten (1 von 2)")
        #expect(BakeRunText.markdown(run, .fold, round: 1).contains("niedrigsten Stufe"))
    }

    @Test func speltIsStretchedGently() {
        // Spelt bread: 0.7 × 70 + 0.3 × 78 = 72.4 % water: 3 rounds.
        let run = bake(.speltBread)
        #expect(run.foldRounds == 3)
        #expect(BakeRunText.values(for: run, step: .fold, round: 1)[.foldGentle]
                == "Dinkel verträgt weniger: Dehne ihn sanft und nur so weit, bis er sich spürbar spannt.")
    }

    @Test func aCoolBulkRestIsFoldedAtRoomTemperatureFirst() {
        // Bulk at the cool place for 4.4 h, 16:30–20:54: after folding it aims
        // for 15.9992 °C, about 16 °C.
        var choices = roomChoices
        choices[.bulk] = RestChoice(place: .cool, hours: 4.4)
        let run = bake(choices: choices)
        #expect(BakeRunText.values(for: run, step: .knead)[.restTemperature]
                == "zuerst bei Raumtemperatur und nach dem Falten bei etwa 16 °C")
        #expect(BakeRunText.values(for: run, step: .fold, round: 3)[.afterFold]
                == "Das war die letzte Runde. Stell den Teig jetzt abgedeckt an einen kühlen Ort, bei etwa 16 °C, "
                + "bis Sa 20:54.")
        // The sourdough rest is not folded: its temperature stays plain.
        #expect(BakeRunText.values(for: run, step: .mixSourdough)[.restTemperature] == "bei etwa 22 °C")
    }

    @Test func aRestTooShortForRoundsSaysSo() {
        // Warm, raised to 0.85 × 3 × 3^−0.5 = 1.4722 h: no round before the last hour.
        let run = bake(choices: [.bulk: RestChoice(place: .warm, hours: 1.4)])
        #expect(BakeRunText.values(for: run, step: .knead)[.folding]
                == "Für Dehnen und Falten ist diese Stockgare zu kurz: Lass ihn ungestört gehen.")
    }

    @Test func countsInWords() {
        #expect([1, 2, 3, 4, 5].map { BakeRunText.times(count: $0) } == ["einmal", "zweimal", "dreimal", "viermal", "5-mal"])
    }

    @Test func theLogListsEveryRound() {
        var run = bake()
        #expect(BakeLogText.times(run, .init(step: .fold, round: 2)) == "geplant Sa 17:30")
        // Kneading names the bulk rest after it, the rounds do not.
        #expect(BakeLogText.times(run, .init(step: .knead)) == "geplant Sa 16:10 · Ruhe bei etwa 22 °C")
        run.answer(.yes, at: nov(14, 7, 50))
        run.complete(at: nov(14, 8))
        run.answer(.yes, at: nov(14, 16, 10))
        run.complete(at: nov(14, 16, 30))
        run.complete(at: nov(14, 17, 2))
        #expect(BakeLogText.times(run, .init(step: .fold, round: 1)) == "geplant Sa 17:00 · erledigt Sa 17:02")
    }
}

struct FoldingScheduleTextTests {
    @Test func theClockWithoutTheDay() {
        #expect(ScheduleText.clock(nov(14, 17, 30), calendar: utc) == "17:30")
        #expect(ScheduleText.clock(nov(15, 0, 5), calendar: utc) == "00:05")
    }

    @Test func theLineOfTheRounds() {
        let folding = Folding(rounds: 3, intervalMinutes: 30)
        let room = Schedule(start: nov(14, 8), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                            choices: roomChoices, folding: folding, calendar: utc)
        #expect(ScheduleText.folds(room, folding: folding, calendar: utc) == "Dehnen und Falten: 17:00, 17:30, 18:00")
        var choices = roomChoices
        choices[.bulk] = RestChoice(place: .cool, hours: 4.4)
        let cool = Schedule(start: nov(14, 8), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                            choices: choices, folding: folding, calendar: utc)
        #expect(ScheduleText.folds(cool, folding: folding, calendar: utc)
                == "Dehnen und Falten bei Raumtemperatur: 17:00, 17:30, 18:00, danach kühl stellen")
        choices[.bulk] = RestChoice(place: .warm, hours: 1.4)
        let short = Schedule(start: nov(14, 8), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                             choices: choices, folding: folding, calendar: utc)
        #expect(ScheduleText.folds(short, folding: folding, calendar: utc)
                == "Für Dehnen und Falten ist die Stockgare zu kurz.")
        #expect(ScheduleText.folds(room, folding: .none, calendar: utc) == nil)
    }

    @Test func aRoundOutsideTheWindowIsAConflict() {
        // Mixed at 12:00: kneading ends 20:30, the first round is at 21:00.
        let folding = Folding(rounds: 3, intervalMinutes: 30)
        let late = Schedule(start: nov(14, 12), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                            choices: roomChoices, folding: folding, calendar: utc)
        #expect(ScheduleText.title(.action(.fold), vessel: .tray) == "Dehnen und Falten")
        #expect(ScheduleText.conflict(late.folds[0], vessel: .tray, window: InteractionWindow(), calendar: utc)
                == "Dehnen und Falten um Sa 21:00 liegt außerhalb von 8 bis 21 Uhr.")
    }
}

struct FoldingPlanTests {
    @Test func thePlanFoldsAsTheBakeWill() {
        let model = BakePlanModel(bread: .wheatBread)
        #expect(model.folding == Folding(rounds: 3, intervalMinutes: 30))
        model.proposeSetup(from: [hook])
        // With the hook proposed: 2 rounds; 2 × 30 min at the start of the bulk rest.
        #expect(model.folding == Folding(rounds: 2, intervalMinutes: 30))
        #expect(model.foldHours(.bulk) == 1)
        #expect(model.foldHours(.proof) == 0)
        model.chosenTime = nov(15, 12)
        #expect(model.schedule(calendar: utc)?.folds.count == 2)
        // The Roggenmischbrot 50 is only mixed.
        #expect(BakePlanModel().folding.rounds == 0)
    }

    @Test func movingTheBulkRestCountsTheFolding() {
        // By hand: 3 rounds, 1.5 h of folding at room temperature first.
        let model = BakePlanModel(bread: .wheatBread)
        model.proposeSetup(from: [])
        model.useTemperatures(Temperatures())
        model.chosenTime = nov(15, 12)
        // The cool place with folding first: 1.5 + 0.5 × 5.79954 = 4.39977 h.
        model.setPlace(.cool, of: .bulk)
        #expect(abs(model.choices[.bulk]!.hours - 4.39977) < 1e-4)
        // 10 h fits nowhere: the cool place, closest by ratio, at its longest
        // 1.2 × 4.39977 = 5.2797 h; for 10 h the 8.5 h left after folding
        // would do half the rest, as 17 h would do all of it:
        // 22 − 10 × log₃(17 / 3) = 22 − 15.789 = 6.211 °C.
        model.setHours(10, of: .bulk, calendar: utc)
        #expect(model.choices[.bulk]?.place == .cool)
        let schedule = model.schedule(calendar: utc)!
        #expect(abs(schedule.rest(.bulk)!.hours - 5.27972) < 1e-4)
        let needed = model.needed(for: .bulk, in: schedule)
        #expect(needed?.hours == 10)
        #expect(abs((needed?.celsius ?? 0) - 6.211) < 1e-3)
    }
}
