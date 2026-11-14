import Foundation
import Testing
@testable import SourdoughKit

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

private func close(_ a: Double, _ b: Double, _ eps: Double = 1e-4) -> Bool { abs(a - b) < eps }
private func close(_ a: Date, _ b: Date) -> Bool { abs(a.timeIntervalSince(b)) < 0.001 }

private let hook = EquipmentItem(kind: .kneader, name: "Bosch")
private let threeRounds = Folding(rounds: 3, intervalMinutes: 30)

struct FoldingRuleTests {
    @Test func theWaterOfTheDoughSetsTheRounds() {
        // Wheat bread: 0.8 × 66 + 0.2 × 72 = 67.2 % water, between 65 and 75: 3 rounds, 30 min.
        #expect(Folding(mix: BreadType.wheatBread.preset, kneader: nil) == Folding(rounds: 3, intervalMinutes: 30))
        // Wheat 405 alone: 63 %, firm: 2 rounds, 45 min apart.
        #expect(Folding(mix: FlourMix([.wheat405: 100]), kneader: nil) == Folding(rounds: 2, intervalMinutes: 45))
        // Wheat whole grain: 80 %, soft: 4 rounds.
        #expect(Folding(mix: FlourMix([.wheatWholeGrain: 100]), kneader: nil).rounds == 4)
    }

    @Test func theBoundsBelongToTheMiddle() {
        // 62.5 % wheat 1050 and 37.5 % whole grain: 45 + 30 = 75 % exactly: still 3.
        #expect(Folding(mix: FlourMix([.wheat1050: 62.5, .wheatWholeGrain: 37.5]), kneader: nil).rounds == 3)
        // Spelt 630 alone: 65 % exactly: 3, 30 min apart.
        #expect(Folding(mix: FlourMix([.spelt630: 100]), kneader: nil) == Folding(rounds: 3, intervalMinutes: 30))
    }

    @Test func speltTakesAtMostThree() {
        // Spelt whole grain: 78 %, soft, 4 rounds, but spelt carries it: 3.
        #expect(Folding(mix: FlourMix([.speltWholeGrain: 100]), kneader: nil).rounds == 3)
    }

    @Test func ryeAndAMachineTakeOneEach() {
        // Wheat bread kneaded with a hook: 3 − 1 = 2.
        #expect(Folding(mix: BreadType.wheatBread.preset, kneader: hook).rounds == 2)
        // Wheat mixed bread: 0.5 × 66 + 0.2 × 72 + 0.3 × 85 = 72.9 %: 3; 30 % rye: 2.
        #expect(Folding(mix: BreadType.wheatMixedBread.preset, kneader: nil).rounds == 2)
        // Spelt mixed bread: 0.2 × 85 + 0.1 × 95 + 0.5 × 70 + 0.2 × 78 = 77.1 %: 4;
        // spelt carries it: 3; 30 % rye: 2; a machine: 1.
        #expect(Folding(mix: BreadType.speltMixedBread.preset, kneader: hook).rounds == 1)
        // Firm wheat 405 with a machine: 2 − 1 = 1, 45 min apart.
        #expect(Folding(mix: FlourMix([.wheat405: 100]), kneader: hook) == Folding(rounds: 1, intervalMinutes: 45))
        // 19 % rye takes none away: 0.81 × 66 + 0.19 × 85 = 69.61 %: 3.
        #expect(Folding(mix: FlourMix([.wheat550: 81, .rye1150: 19]), kneader: nil).rounds == 3)
    }

    @Test func fromFiftyPercentRyeThereIsNone() {
        #expect(Folding(mix: BreadType.ryeMixedBread50.preset, kneader: nil).rounds == 0)
        #expect(Folding.none.rounds == 0)
        #expect(Folding.none.phaseHours == 0)
    }

    @Test func thePhaseLastsUntilTheLastRound() {
        // 3 × 30 min = 1.5 h; 2 × 45 min = 1.5 h.
        #expect(threeRounds.phaseHours == 1.5)
        #expect(Folding(rounds: 2, intervalMinutes: 45).phaseHours == 1.5)
    }

    @Test func theLastHourStaysFree() {
        // A 3 h rest: rounds at 0.5, 1 and 1.5 h, all before 3 − 1 = 2 h.
        #expect(threeRounds.roundHours(bulkHours: 3) == [0.5, 1, 1.5])
        // A 2 h rest leaves room up to 1 h: the third round drops.
        #expect(threeRounds.roundHours(bulkHours: 2) == [0.5, 1])
        // 1.4 h leaves 0.4 h: none.
        #expect(threeRounds.roundHours(bulkHours: 1.4).isEmpty)
        #expect(Folding.none.roundHours(bulkHours: 5).isEmpty)
    }

    @Test func survivesAJSONRoundTrip() throws {
        let data = try JSONEncoder().encode(threeRounds)
        #expect(try JSONDecoder().decode(Folding.self, from: data) == threeRounds)
    }
}

struct FoldingRestTests {
    // Defaults: room 22 °C, cool place 16 °C. The bulk rest of a dough
    // without rye takes 3 h at 22 °C and 3 × 3^0.6 = 5.7995 h at 16 °C.

    @Test func aCoolBulkRestFoldsAtRoomTemperatureFirst() {
        // 1.5 h of folding at room temperature do 1.5 / 3 = half of the rest;
        // the other half takes 0.5 × 5.7995 h at 16 °C: 1.5 + 2.89977 = 4.39977 h.
        let cool = ScheduleRules.nominalHours(.bulk, ryeShare: 0, place: .cool, temperatures: Temperatures(),
                                              foldHours: 1.5)
        #expect(close(cool, 4.39977))
        // Without folding the cool place has its own 5.7995 h.
        #expect(close(ScheduleRules.nominalHours(.bulk, ryeShare: 0, place: .cool, temperatures: Temperatures()),
                      5.79954))
        // At room temperature and warm the dough is folded where it rests:
        // 3 h, and 3 × 3^−0.5 = 1.73205 h.
        #expect(ScheduleRules.nominalHours(.bulk, ryeShare: 0, place: .room, temperatures: Temperatures(),
                                           foldHours: 1.5) == 3)
        #expect(close(ScheduleRules.nominalHours(.bulk, ryeShare: 0, place: .warm, temperatures: Temperatures(),
                                                 foldHours: 1.5), 1.73205))
        // The range follows: 0.85 × 4.39977 = 3.73981 to 1.2 × 4.39977 = 5.27972.
        let range = ScheduleRules.range(.bulk, ryeShare: 0, place: .cool, temperatures: Temperatures(),
                                        foldHours: 1.5)
        #expect(close(range.lowerBound, 3.73981) && close(range.upperBound, 5.27972))
        #expect(ScheduleRules.roomPhase(foldHours: 1.5, place: .cool, temperatures: Temperatures()) == 1.5)
        #expect(ScheduleRules.roomPhase(foldHours: 1.5, place: .warm, temperatures: Temperatures()) == 0)
    }

    @Test func aPhaseThatDoesTheWholeRestLeavesNothingAtThePlace() {
        // 3 h of folding at room temperature do all of a 3 h rest.
        #expect(ScheduleRules.nominalHours(.bulk, ryeShare: 0, place: .cool, temperatures: Temperatures(),
                                           foldHours: 3) == 3)
    }

    @Test func theTargetTemperatureIsThatOfWhatIsLeft() {
        // 4.4 h with 1.5 h at room: the 2.9 h left do half the rest, as 5.8 h
        // would do all of it: 22 − 10 × log₃(5.8 / 3) = 22 − 6.0008 = 15.9992 °C.
        let celsius = ScheduleRules.celsius(.bulk, ryeShare: 0, hours: 4.4, place: .cool,
                                            temperatures: Temperatures(), foldHours: 1.5)
        #expect(close(celsius, 15.9992))
        // 3 h with 1.5 h at room: 1.5 h for half the rest, as at 22 °C.
        #expect(close(ScheduleRules.celsius(.bulk, ryeShare: 0, hours: 3, place: .cool,
                                            temperatures: Temperatures(), foldHours: 1.5), 22))
        // No time left after the folding, or nothing left to do: room temperature.
        #expect(ScheduleRules.celsius(.bulk, ryeShare: 0, hours: 1.5, place: .cool, temperatures: Temperatures(),
                                      foldHours: 1.5) == 22)
        #expect(ScheduleRules.celsius(.bulk, ryeShare: 0, hours: 4, place: .cool, temperatures: Temperatures(),
                                      foldHours: 3) == 22)
        // At room temperature the plain rule: 3 h is 22 °C.
        #expect(close(ScheduleRules.celsius(.bulk, ryeShare: 0, hours: 3, place: .room,
                                            temperatures: Temperatures(), foldHours: 1.5), 22))
    }

    @Test func thePlaceForAnHourCountsTheFolding() {
        // 3.8 h of bulk rest: the cool place with folding first holds it
        // (3.74 to 5.28 h). Without folding no place does (room up to 3.6 h,
        // cool from 0.85 × 5.7995 = 4.93 h); closest by ratio is the room,
        // |ln(3.8 / 3)| = 0.24 against |ln(3.8 / 5.8)| = 0.42.
        #expect(ScheduleRules.place(forHours: 3.8, rest: .bulk, ryeShare: 0, temperatures: Temperatures(),
                                    current: .room, foldHours: 1.5) == .cool)
        #expect(ScheduleRules.place(forHours: 3.8, rest: .bulk, ryeShare: 0, temperatures: Temperatures(),
                                    current: .room) == .room)
        // 10 h fits nowhere; the closest nominal time by ratio with folding is
        // the cool 4.4 h (log 10/4.4 = 0.82) rather than the room 3 h (1.20).
        #expect(ScheduleRules.place(forHours: 10, rest: .bulk, ryeShare: 0, temperatures: Temperatures(),
                                    current: .room, foldHours: 1.5) == .cool)
    }

    @Test func theScaleCoversTheRangesWithFolding() {
        // Smallest lower bound warm 0.85 × 1.73205 = 1.47224 h, largest upper
        // bound cool 5.27972 h; 15 % margin each way.
        let scale = ScheduleRules.scale(.bulk, ryeShare: 0, temperatures: Temperatures(), foldHours: 1.5)
        #expect(close(scale.lowerBound, 1.47224 / 1.15))
        #expect(close(scale.upperBound, 5.27972 * 1.15))
    }

    @Test func onlyTheFoldedRestHasFoldHours() {
        #expect(Schedule.foldHours(.bulk, folding: threeRounds) == 1.5)
        #expect(Schedule.foldHours(.sourdough, folding: threeRounds) == 0)
        #expect(Schedule.foldHours(.proof, folding: threeRounds) == 0)
    }
}

struct FoldingScheduleTests {
    /// All rests at room temperature, as fixed choices: sourdough 8 h, bulk
    /// 3 h, proof 1.5 h.
    private let roomChoices: [RestKind: RestChoice] = [
        .sourdough: RestChoice(place: .room, hours: 8), .bulk: RestChoice(place: .room, hours: 3),
        .proof: RestChoice(place: .room, hours: 1.5)]

    @Test func theRoundsFollowKneading() {
        // Mixed Saturday 08:00–08:10, sourdough until 16:10, kneading until
        // 16:30; rounds 30, 60, 90 min later, 5 minutes each.
        let schedule = Schedule(start: nov(14, 8), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                                choices: roomChoices, folding: threeRounds, calendar: utc)
        #expect(schedule.folds.map(\.start) == [nov(14, 17), nov(14, 17, 30), nov(14, 18)])
        #expect(schedule.folds.map(\.end) == [nov(14, 17, 5), nov(14, 17, 35), nov(14, 18, 5)])
        #expect(schedule.folds.allSatisfy { $0.kind == .action(.fold) && !$0.outsideWindow })
        #expect(!schedule.foldsAtRoomFirst)
        // The folds are not among the steps; the rest keeps its 3 h.
        #expect(!schedule.steps.contains { $0.kind == .action(.fold) })
        #expect(schedule.rest(.bulk)?.hours == 3)
        // The round times of the process.
        #expect(BakeProcess.plannedTime(.fold, round: 2, in: schedule) == nov(14, 17, 30))
        #expect(BakeProcess.plannedTime(.fold, in: schedule) == nov(14, 17))
    }

    @Test func withoutFoldingThereAreNoRounds() {
        let schedule = Schedule(start: nov(14, 8), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                                choices: roomChoices, calendar: utc)
        #expect(schedule.folds.isEmpty)
        // Due when the bulk rest starts: 16:30.
        #expect(BakeProcess.plannedTime(.fold, round: 1, in: schedule) == nov(14, 16, 30))
    }

    @Test func aShortRestKeepsItsLastHourFree() {
        // Warm bulk rest fixed at 1.5 h (warm range 1.47 to 2.08 h): only the
        // round at 0.5 h lies before 1.5 − 1 = 0.5 h.
        var choices = roomChoices
        choices[.bulk] = RestChoice(place: .warm, hours: 1.5)
        let schedule = Schedule(start: nov(14, 8), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                                choices: choices, folding: threeRounds, calendar: utc)
        #expect(schedule.folds.map(\.start) == [nov(14, 17)])
    }

    @Test func roundsAfterNineInTheEveningAreConflicts() {
        // Mixed at 12:00: kneading 20:10–20:30, rounds at 21:00, 21:30 and
        // 22:00, all after 21:00 or ending after it. Kneading itself lies in
        // the window and is not marked.
        let schedule = Schedule(start: nov(14, 12), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                                choices: roomChoices, folding: threeRounds, calendar: utc)
        #expect(schedule.folds.map(\.outsideWindow) == [true, true, true])
        #expect(schedule.conflicts.filter { $0 == .fold }.count == 3)
        #expect(schedule.steps.first { $0.kind == .action(.knead) }?.outsideWindow == false)
    }

    @Test func theWindowMustHoldTheRoundsWhenPlanningForwards() {
        // Mixed at 11:00, only the sourdough free. Kneading (20 min) and the
        // rounds up to 1.5 h + 5 min after it must end by 21:00: the unit
        // ends 11:10 + h + 20 min + 95 min = 13:05 + h, at most 21:00, so the
        // sourdough takes 7 h 55 min (range 6.4 to 10 h) instead of 8 h.
        var choices = roomChoices
        choices[.sourdough] = nil
        let folded = Schedule(start: nov(14, 11), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                              choices: choices, folding: threeRounds, calendar: utc)
        #expect(close(folded.rest(.sourdough)!.hours, 7 + 55.0 / 60))
        #expect(close(folded.folds.last!.end, nov(14, 21)))
        #expect(folded.folds.allSatisfy { !$0.outsideWindow })
        // Without folding the nominal 8 h fit: kneading ends 19:30.
        let plain = Schedule(start: nov(14, 11), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                             choices: choices, calendar: utc)
        #expect(plain.rest(.sourdough)!.hours == 8)
    }

    @Test func theWindowMustHoldTheRoundsWhenPlanningBackwards() {
        // Ready Sunday 12:00 on the tray: cooling 2 h, baking 09:15–10:00 with
        // preheating 08:30–09:15. The proof is fixed in the fridge for 10 h,
        // 23:15–09:15, shaping 23:00–23:15; the sourdough at 8 h; only the
        // bulk rest is free and ends at 23:00.
        var choices = roomChoices
        choices[.proof] = RestChoice(place: .fridge, hours: 10)
        choices[.bulk] = nil
        // Without folding it takes its nominal 3 h at room temperature from
        // 20:00; kneading 19:40–20:00 lies in the window.
        let plain = Schedule(target: nov(15, 12), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                             choices: choices, calendar: utc)
        #expect(plain.rest(.bulk)!.hours == 3)
        #expect(plain.rest(.bulk)!.start == nov(14, 20))
        // With folding the last round must end by 21:00: kneading, then 95
        // minutes of rounds after its end, end at 23:00 + 95 min − h =
        // 00:35 − h; the room range (2.55 to 3.6 h) gives 20:59 to 22:02, and
        // the closest to the nominal 21:35 in the window is 21:00: the rest
        // takes 3 h 35 min from 19:25, rounds 19:55, 20:25, 20:55–21:00.
        let folded = Schedule(target: nov(15, 12), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                              choices: choices, folding: threeRounds, calendar: utc)
        #expect(close(folded.rest(.bulk)!.hours, 3 + 35.0 / 60))
        #expect(folded.rest(.bulk)!.place == .room)
        #expect(close(folded.rest(.bulk)!.start, nov(14, 19, 25)))
        #expect(zip(folded.folds.map(\.start), [nov(14, 19, 55), nov(14, 20, 25), nov(14, 20, 55)])
            .allSatisfy { close($0, $1) })
        #expect(folded.folds.allSatisfy { !$0.outsideWindow })
    }

    @Test func aCoolBulkRestStartsWithTheRoundsAtRoomTemperature() {
        // Bulk at the cool place, 4.4 h: within 3.74 to 5.28 h with folding.
        // It aims for 15.9992 °C after folding (see above), and the rounds at
        // room temperature come first.
        var choices = roomChoices
        choices[.bulk] = RestChoice(place: .cool, hours: 4.4)
        let schedule = Schedule(start: nov(14, 8), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                                choices: choices, folding: threeRounds, calendar: utc)
        let bulk = schedule.rest(.bulk)!
        #expect(close(bulk.hours, 4.4))
        #expect(close(bulk.celsius!, 15.9992))
        #expect(close(bulk.hourRange!.lowerBound, 3.73981) && close(bulk.hourRange!.upperBound, 5.27972))
        #expect(schedule.foldsAtRoomFirst)
        #expect(schedule.folds.count == 3)
        // Without folding the 4.4 h are below the cool range (4.93 h) and
        // are raised to it: 0.85 × 5.79954 = 4.92961 h.
        let plain = Schedule(start: nov(14, 8), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                             choices: choices, calendar: utc)
        #expect(close(plain.rest(.bulk)!.hours, 4.92961))
        #expect(!plain.foldsAtRoomFirst)
    }

    @Test func theProposedTargetAvoidsRoundsInTheNight() {
        // Proposing with folding goes through the same conflicts; for a plain
        // tray bread the first noon or evening without conflicts is unchanged
        // if it has none either way. Here it only has to be a valid proposal.
        let now = nov(13, 9)
        let target = Schedule.proposedTarget(after: now, ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                                             folding: threeRounds, calendar: utc)
        let schedule = Schedule(target: target, ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                                folding: threeRounds, calendar: utc)
        #expect(schedule.conflicts.isEmpty)
        #expect(schedule.start >= now)
        #expect(schedule.folds.count == 3)
    }
}

struct FoldingRunTests {
    /// Wheat bread by hand on the tray, started forwards on Saturday 08:00
    /// with every rest at room temperature: 3 rounds at 17:00, 17:30, 18:00.
    private func wheat(kneader: EquipmentItem? = nil,
                       choices: [RestKind: RestChoice] = [.sourdough: RestChoice(place: .room, hours: 8),
                                                          .bulk: RestChoice(place: .room, hours: 3),
                                                          .proof: RestChoice(place: .room, hours: 1.5)]) -> BakeRun {
        BakeRun(startedAt: nov(13, 9), bread: .wheatBread, mix: BreadType.wheatBread.preset, totalGrams: 500,
                limits: [:], starter: nil, setup: BakeSetup(vessel: .tray, kneader: kneader),
                temperatures: Temperatures(), window: InteractionWindow(), anchor: .start, time: nov(14, 8),
                choices: choices, timeZone: TimeZone(identifier: "UTC")!)
    }

    /// Answers and completes up to the folding.
    private func kneaded(_ bake: BakeRun) -> BakeRun {
        var bake = bake
        bake.answer(.yes, at: nov(14, 7, 50))
        bake.complete(at: nov(14, 8))
        bake.answer(.yes, at: nov(14, 16, 10))
        bake.complete(at: nov(14, 16, 30))
        return bake
    }

    @Test func aBakePlansItsRoundsAndShowsEachOnItsOwn() {
        let bake = wheat()
        #expect(bake.folding == Folding(rounds: 3, intervalMinutes: 30))
        #expect(bake.foldRounds == 3)
        #expect(bake.steps.contains(.fold))
        #expect(bake.schedule.folds.map(\.start) == [nov(14, 17), nov(14, 17, 30), nov(14, 18)])
        let entries = bake.entries.map { "\($0.step.rawValue)\($0.round.map(String.init) ?? "")" }
        #expect(entries == ["checkStarter", "mixSourdough", "checkSourdough", "knead", "fold1", "fold2", "fold3",
                            "shape", "checkProof", "preheat", "bake", "cool"])
        // With a hook one round fewer: 2.
        #expect(wheat(kneader: hook).foldRounds == 2)
    }

    @Test func eachRoundIsDoneOnItsOwn() {
        var bake = kneaded(wheat())
        #expect(bake.current == .fold)
        #expect(bake.currentRound == 1)
        #expect(bake.previous == .knead)
        #expect(bake.previousRound == nil)
        bake.complete(at: nov(14, 17, 2))
        #expect(bake.current == .fold)
        #expect(bake.currentRound == 2)
        #expect(bake.foldsDone == [1: nov(14, 17, 2)])
        #expect(bake.done[.fold] == nil)
        #expect(bake.doneAt(BakeRun.Entry(step: .fold, round: 1)) == nov(14, 17, 2))
        #expect(bake.doneAt(BakeRun.Entry(step: .fold, round: 2)) == nil)
        #expect(bake.doneAt(BakeRun.Entry(step: .knead, round: nil)) == nov(14, 16, 30))
        // The round done last opens again first.
        #expect(bake.previous == .fold)
        #expect(bake.previousRound == 1)
        bake.undo()
        #expect(bake.currentRound == 1)
        #expect(bake.foldsDone.isEmpty)
        bake.complete(at: nov(14, 17))
        bake.complete(at: nov(14, 17, 30))
        bake.complete(at: nov(14, 18))
        // The last round marks the step.
        #expect(bake.done[.fold] == nov(14, 18))
        #expect(bake.current == .shape)
        #expect(bake.currentRound == nil)
        #expect(bake.previous == .fold)
        #expect(bake.previousRound == 3)
        bake.undo()
        #expect(bake.current == .fold)
        #expect(bake.currentRound == 3)
        #expect(bake.done[.fold] == nil)
    }

    @Test func undoAfterTheRoundsOpensTheStepAfterThem() {
        var bake = kneaded(wheat())
        for minute in [0.0, 30, 60] { bake.complete(at: nov(14, 17, minute)) }
        bake.complete(at: nov(14, 19, 30))
        #expect(bake.previous == .shape)
        #expect(bake.previousRound == nil)
        bake.undo()
        #expect(bake.current == .shape)
        #expect(bake.foldsDone.count == 3)
    }

    @Test func fromFiftyPercentRyeThereIsNoFoldingStep() {
        let bake = BakeRun(startedAt: nov(13, 9), bread: .ryeMixedBread50, mix: BreadType.ryeMixedBread50.preset,
                           totalGrams: 800, limits: [:], starter: nil, setup: BakeSetup(vessel: .tray),
                           temperatures: Temperatures(), window: InteractionWindow(), time: nov(15, 12),
                           choices: [:], timeZone: TimeZone(identifier: "UTC")!)
        #expect(bake.foldRounds == 0)
        #expect(!bake.steps.contains(.fold))
        #expect(bake.entries.count == 9)
    }

    @Test func aRestTooShortForAnyRoundHasNoFoldingStep() {
        // The bulk rest fixed warm at 1.4 h is raised to the shortest warm
        // rest, 0.85 × 3 × 3^−0.5 = 1.4722 h, which leaves room for rounds up
        // to 0.4722 h: the first is at 0.5 h, so there is none.
        let bake = wheat(choices: [.bulk: RestChoice(place: .warm, hours: 1.4)])
        #expect(bake.folding.rounds == 3)
        #expect(bake.foldRounds == 0)
        #expect(!bake.steps.contains(.fold))
    }

    @Test func roundsSurviveAJSONRoundTrip() throws {
        var bake = kneaded(wheat())
        bake.complete(at: nov(14, 17))
        let data = try JSONEncoder().encode(bake)
        let loaded = try JSONDecoder().decode(BakeRun.self, from: data)
        #expect(loaded == bake)
        #expect(loaded.foldsDone == [1: nov(14, 17)])
    }

    @Test func aBakeSavedBeforeFoldingHasNoRounds() throws {
        // Version 1.1 files have neither the folding nor rounds.
        var bake = kneaded(wheat())
        bake.complete(at: nov(14, 17))
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(bake)) as? [String: Any])
        for key in ["plannedFolding", "plannedRounds", "roundsDone"] {
            #expect(object[key] != nil)
            object[key] = nil
        }
        let old = try JSONDecoder().decode(BakeRun.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.folding == .none)
        #expect(old.foldRounds == 0)
        #expect(old.foldsDone.isEmpty)
        #expect(!old.steps.contains(.fold))
        #expect(old.schedule.folds.isEmpty)
        // Kneaded, so shaping is next.
        #expect(old.current == .shape)
    }
}

struct FoldingDiagramTests {
    @Test func theRoundsLoopAndCanBeLeftOut() {
        let edges = BakeProcess.edges()
        #expect(edges.contains(.init(from: "kneadFold", to: "foldHook", label: "Küchenmaschine mit Knethaken")))
        #expect(edges.contains(.init(from: "kneadFold", to: "fold", label: "sonst")))
        #expect(edges.contains(.init(from: "fold", to: "fold", label: "weitere Runde")))
        #expect(edges.contains(.init(from: "foldBlade", to: "rest.bulk", label: nil)))
        // From 50 % rye the way goes past the rounds.
        #expect(edges.contains(.init(from: "kneadRye", to: "rest.bulk", label: "Roggen ab 50 %")))
        let diagram = BakeProcess.plantUML()
        #expect(diagram.contains("""
            if (Roggen ab 50 %) then (ja)
            else (sonst)
              repeat
                switch ()
                case (Küchenmaschine mit Knethaken)
                  :Dehnen und Falten oder kurz kneten\\n//während der Stockgare//;
            """))
        #expect(diagram.contains("  repeat while (weitere Runde) is (ja) not (nein)\nendif\n"))
        #expect(BakeProcess.restName(.bulk) == "Stockgare")
    }
}

struct FoldingDaysTests {
    @Test func theRoundsAreMarksInTheRowOfTheirDay() {
        // Rounds Saturday 17:00, 17:30, 18:00 (see above): in the row from 7
        // to 22 o'clock, (17 − 7) / 15 = 0.6667, 0.7, 0.7333.
        let choices: [RestKind: RestChoice] = [
            .sourdough: RestChoice(place: .room, hours: 8), .bulk: RestChoice(place: .room, hours: 3),
            .proof: RestChoice(place: .room, hours: 1.5)]
        let schedule = Schedule(start: nov(14, 8), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                                choices: choices, folding: threeRounds, calendar: utc)
        let days = ScheduleDays(schedule, calendar: utc).days
        // Shaped 19:30, proof until 21:15, baked until 22:00, cooled 2 h:
        // ready Sunday 00:00, a second row without rounds.
        #expect(days.count == 2)
        #expect(days[1].folds.isEmpty)
        #expect(zip(days[0].folds.map(\.position), [10.0 / 15, 10.5 / 15, 11.0 / 15]).allSatisfy { close($0, $1) })
        #expect(days[0].folds.allSatisfy { !$0.outsideWindow })
    }

    @Test func roundsInTheNightAreNotMarked() {
        // Mixed at 15:00: kneading 23:10–23:30, rounds Sunday 00:00, 00:30 and
        // 01:00, before the row opens at 7: no marks; they are conflicts.
        let choices: [RestKind: RestChoice] = [
            .sourdough: RestChoice(place: .room, hours: 8), .bulk: RestChoice(place: .room, hours: 3),
            .proof: RestChoice(place: .room, hours: 1.5)]
        let schedule = Schedule(start: nov(14, 15), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                                choices: choices, folding: threeRounds, calendar: utc)
        #expect(schedule.folds.map(\.start) == [nov(15, 0), nov(15, 0, 30), nov(15, 1)])
        #expect(ScheduleDays(schedule, calendar: utc).days.allSatisfy { $0.folds.isEmpty })
        // At 21:00 a round is still in the row (14 / 15), outside the window.
        let late = Schedule(start: nov(14, 12), ryeShare: 0, vessel: .tray, temperatures: Temperatures(),
                            choices: choices, folding: threeRounds, calendar: utc)
        let marks = ScheduleDays(late, calendar: utc).days[0].folds
        #expect(marks.count == 3)
        #expect(close(marks[0].position, 14.0 / 15))
        #expect(marks.allSatisfy(\.outsideWindow) == true)
    }
}
