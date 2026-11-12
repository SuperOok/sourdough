import Foundation
import Testing
@testable import SourdoughKit

// Expected values are worked out by hand, never taken from a program run.

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// A time in November 2026, UTC; the 14th is a Saturday.
private func nov(_ day: Int, _ hour: Int, _ minute: Double = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))! + minute * 60
}

private func close(_ a: Date, _ b: Date) -> Bool { abs(a.timeIntervalSince(b)) < 0.001 }

struct TemperaturesTests {
    @Test func placesHaveTheirTemperatures() {
        let temperatures = Temperatures(roomCelsius: 20, fridgeCelsius: 6)
        #expect(Place.allCases == [.warm, .room, .cool, .fridge])
        #expect(Place.allCases.map(temperatures.celsius) == [27, 20, 16, 6])
        #expect(Temperatures().roomCelsius == 22)
        #expect(Temperatures().fridgeCelsius == 5)
        #expect(Temperatures().coolCelsius == 16)
        #expect(Temperatures().usesCoolPlace)
    }

    @Test func aCoolPlaceNeedsToBeCoolerThanTheRoomAndWanted() {
        #expect(Temperatures().hasCoolPlace)
        #expect(!Temperatures(usesCoolPlace: false).hasCoolPlace)
        #expect(!Temperatures(roomCelsius: 15).hasCoolPlace)
        #expect(!Temperatures(roomCelsius: 16).hasCoolPlace)
        #expect(Temperatures(roomCelsius: 17).hasCoolPlace)
    }

    @Test func temperaturesSavedBeforeTheCoolPlaceGetItsDefaults() throws {
        let old = Data(#"{"roomCelsius":21,"fridgeCelsius":4}"#.utf8)
        let decoded = try JSONDecoder().decode(Temperatures.self, from: old)
        #expect(decoded == Temperatures(roomCelsius: 21, fridgeCelsius: 4, coolCelsius: 16, usesCoolPlace: true))
    }

    @Test func theCoolPlaceSurvivesEncoding() throws {
        let temperatures = Temperatures(roomCelsius: 20, fridgeCelsius: 4, coolCelsius: 13, usesCoolPlace: false)
        let decoded = try JSONDecoder().decode(Temperatures.self, from: JSONEncoder().encode(temperatures))
        #expect(decoded == temperatures)
    }

    @Test func warmWaterBringsTheDoughToItsTarget() {
        // 2 × 26 − 20 = 32 °C; for a warm rest of 27 °C: 2 × 27 − 20 = 34 °C.
        let temperatures = Temperatures(roomCelsius: 20)
        #expect(temperatures.waterCelsius() == 32)
        #expect(temperatures.waterCelsius(target: 27) == 34)
    }
}

struct ScheduleRulesTests {
    @Test func restsAndTheirPlaces() {
        #expect(RestKind.allCases == [.sourdough, .bulk, .proof])
        let kitchen = Temperatures()
        #expect(RestKind.allCases.map { $0.places(for: kitchen) }
                == [[.room, .cool, .warm], [.room, .cool, .warm], [.room, .cool, .fridge, .warm]])
        // Without a cool place the rests have the old places.
        let noCool = Temperatures(usesCoolPlace: false)
        #expect(RestKind.allCases.map { $0.places(for: noCool) }
                == [[.room, .warm], [.room, .warm], [.room, .fridge, .warm]])
    }

    @Test func atTheSameTemperatureTheRangeIsNarrowExceptInTheFridge() {
        #expect(RestKind.sourdough.factorRange(at: .room) == 0.8...1.25)
        #expect(RestKind.bulk.factorRange(at: .cool) == 0.85...1.2)
        #expect(RestKind.proof.factorRange(at: .warm) == 0.85...1.2)
        #expect(RestKind.proof.factorRange(at: .fridge) == 0.7...1.5)
    }

    @Test func theRangeIsTheNominalTimeTimesTheFactors() {
        let kitchen = Temperatures()
        // Sourdough at 22 °C: 8 h, 0.8 × = 6.4 h to 1.25 × = 10 h.
        let sourdough = ScheduleRules.range(.sourdough, ryeShare: 0, place: .room, temperatures: kitchen)
        #expect(abs(sourdough.lowerBound - 6.4) < 1e-9 && abs(sourdough.upperBound - 10) < 1e-9)
        // Proof at 22 °C: 1.5 h, 1.275 h to 1.8 h.
        let proof = ScheduleRules.range(.proof, ryeShare: 0, place: .room, temperatures: kitchen)
        #expect(abs(proof.lowerBound - 1.275) < 1e-9 && abs(proof.upperBound - 1.8) < 1e-9)
        // Proof in the fridge at 5 °C: 1.5 × 3^1.7 h, 0.7 × to 1.5 ×.
        let nominal = 1.5 * pow(3.0, 1.7)
        let fridge = ScheduleRules.range(.proof, ryeShare: 0, place: .fridge, temperatures: kitchen)
        #expect(abs(fridge.lowerBound - 0.7 * nominal) < 1e-9 && abs(fridge.upperBound - 1.5 * nominal) < 1e-9)
    }

    @Test func theTemperatureForAGivenTimeIsTheRuleTurnedAround() {
        // Proof, 1.5 h at 22 °C: three times as long is 10 °C colder, nine
        // times 20 °C, a third of the time 10 °C warmer.
        #expect(abs(ScheduleRules.celsius(.proof, ryeShare: 0, hours: 1.5) - 22) < 1e-9)
        #expect(abs(ScheduleRules.celsius(.proof, ryeShare: 0, hours: 4.5) - 12) < 1e-9)
        #expect(abs(ScheduleRules.celsius(.proof, ryeShare: 0, hours: 13.5) - 2) < 1e-9)
        #expect(abs(ScheduleRules.celsius(.proof, ryeShare: 0, hours: 0.5) - 32) < 1e-9)
        // Sourdough at 22 °C takes 8 h, so 24 h are 12 °C.
        #expect(abs(ScheduleRules.celsius(.sourdough, ryeShare: 0, hours: 24) - 12) < 1e-9)
    }

    @Test func theRightPlaceForAGivenTime() {
        // Proof, ranges: room 1.275–1.8 h, cool (3^0.6 × 1.5 = 2.90 h) 2.46–3.48 h,
        // fridge 6.80–14.56 h, warm (1.5 / √3 = 0.87 h) 0.74–1.04 h.
        let kitchen = Temperatures()
        func place(_ hours: Double, current: Place = .room, _ temperatures: Temperatures = kitchen) -> Place {
            ScheduleRules.place(forHours: hours, rest: .proof, ryeShare: 0, temperatures: temperatures,
                                current: current)
        }
        // The current place stays while it holds the time.
        #expect(place(1.5) == .room)
        #expect(place(0.9, current: .warm) == .warm)
        // Otherwise the first place that does.
        #expect(place(1.5, current: .warm) == .room)
        #expect(place(3) == .cool)
        #expect(place(10) == .fridge)
        #expect(place(0.9) == .warm)
        // In a gap the closest nominal time wins, by ratio: 2.0 h is closer to
        // 1.5 h (ln 1.33 = 0.29) than to 2.90 h (ln 1.45 = 0.37); 2.3 h is
        // closer to 2.90 h (0.23) than to 1.5 h (0.43).
        #expect(place(2.0) == .room)
        #expect(place(2.3) == .cool)
        // Beyond every range the extreme place gives the most.
        #expect(place(40) == .fridge)
        #expect(place(0.3) == .warm)
        // Without a cool place: 3 h are closest to the room (ln 2 = 0.69),
        // the fridge is at 1.17 and the warm place at 1.24.
        let noCool = Temperatures(usesCoolPlace: false)
        #expect(place(3, noCool) == .room)
        // A current place that is not offered is not kept.
        #expect(place(1.5, current: .cool, noCool) == .room)
    }

    @Test func referenceHoursAt22Degrees() {
        // Bulk: 3 − 2.5 × rye / 100: 3 h without rye, 1.75 h at 50 %, 0.5 h at 100 %.
        #expect(ScheduleRules.referenceHours(.sourdough, ryeShare: 50) == 8)
        #expect(ScheduleRules.referenceHours(.bulk, ryeShare: 0) == 3)
        #expect(ScheduleRules.referenceHours(.bulk, ryeShare: 50) == 1.75)
        #expect(ScheduleRules.referenceHours(.bulk, ryeShare: 100) == 0.5)
        #expect(ScheduleRules.referenceHours(.proof, ryeShare: 50) == 1.5)
    }

    @Test func tenDegreesColderTakesThreeTimesAsLong() {
        #expect(abs(ScheduleRules.hours(.sourdough, ryeShare: 0, celsius: 12) - 24) < 1e-9)
        #expect(abs(ScheduleRules.hours(.proof, ryeShare: 0, celsius: 32) - 0.5) < 1e-9)
        #expect(ScheduleRules.hours(.proof, ryeShare: 0, celsius: 22) == 1.5)
    }

    @Test func actionMinutes() {
        #expect(ActionKind.allCases.map { ScheduleRules.minutes($0, vessel: .pot) } == [10, 20, 15, 45, 50])
        #expect(ScheduleRules.minutes(.bake, vessel: .loafPan) == 60)
        #expect(ScheduleRules.minutes(.bake, vessel: .tray) == 45)
    }

    @Test func moreRyeCoolsLonger() {
        #expect([0, 49.9, 50, 79.9, 80, 100].map(ScheduleRules.coolingHours) == [2, 2, 6, 6, 24, 24])
    }

    @Test func theWindowHoldsWholeActions() {
        let window = InteractionWindow()
        #expect(window.startHour == 8 && window.endHour == 21)
        #expect(window.contains(nov(14, 8), nov(14, 21), calendar: utc))
        #expect(!window.contains(nov(14, 7, 59), nov(14, 8, 10), calendar: utc))
        #expect(!window.contains(nov(14, 20, 50), nov(14, 21, 1), calendar: utc))
    }
}

struct ScheduleTests {
    private let kitchen = Temperatures(roomCelsius: 22, fridgeCelsius: 5)

    @Test func aLateBakeLeavesTheNightForCooling() {
        // Roggenmischbrot 50 in the pot, ready on Sunday 12:00. Cooling 6 h
        // would end the bake at 06:00 — too early. The latest bake that fits
        // ends Saturday 21:00: 50 min baking from 20:10, preheating from 19:25.
        // Proof 1.5 h at 22 °C from 18:40, shaping 18:25. Bulk 3 − 1.25 = 1.75 h
        // from 16:40, kneading 16:20. Sourdough 8 h from 08:20, mixed 08:10.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: kitchen, calendar: utc)
        let expected: [(ScheduleStep.Kind, Date, Date)] = [
            (.action(.mixSourdough), nov(14, 8, 10), nov(14, 8, 20)),
            (.rest(.sourdough, .room), nov(14, 8, 20), nov(14, 16, 20)),
            (.action(.knead), nov(14, 16, 20), nov(14, 16, 40)),
            (.rest(.bulk, .room), nov(14, 16, 40), nov(14, 18, 25)),
            (.action(.shape), nov(14, 18, 25), nov(14, 18, 40)),
            (.rest(.proof, .room), nov(14, 18, 40), nov(14, 20, 10)),
            (.action(.preheat), nov(14, 19, 25), nov(14, 20, 10)),
            (.action(.bake), nov(14, 20, 10), nov(14, 21)),
            (.cooling, nov(14, 21), nov(15, 12)),
        ]
        #expect(schedule.steps.count == expected.count)
        for (step, (kind, start, end)) in zip(schedule.steps, expected) {
            #expect(step.kind == kind)
            #expect(close(step.start, start), "\(kind) starts \(step.start)")
            #expect(close(step.end, end), "\(kind) ends \(step.end)")
        }
        #expect(schedule.conflicts.isEmpty)
        #expect(schedule.vessel == .pot)
        #expect(schedule.steps.map(\.place) == [nil, .room, nil, .room, nil, .room, nil, nil, nil])
        #expect(close(schedule.start, nov(14, 8, 10)))
        #expect(schedule.target == nov(15, 12))
        #expect(schedule.steps.last?.hours == 15)
    }

    @Test func restsKnowTheirRange() {
        // Proof at 22 °C: 1.5 h, 0.85 × = 1.275 h to 1.2 × = 1.8 h.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: kitchen, calendar: utc)
        let proof = schedule.rest(.proof)!
        #expect(abs(proof.hourRange!.lowerBound - 1.275) < 1e-9)
        #expect(abs(proof.hourRange!.upperBound - 1.8) < 1e-9)
        #expect(schedule.steps.first?.hourRange == nil)
    }

    @Test func aMorningBakeSendsTheProofIntoTheFridge() {
        // 30 % rye: cooling 2 h, so the bake ends Sunday 10:00, starts 09:10.
        // A room proof (1.275–1.8 h) would need shaping before 08:15, a cool
        // one (2.46–3.48 h) even earlier. In the fridge at 5 °C the proof takes
        // 1.5 × 3^1.7 = 9.71 h, 6.80 to 14.56 h:
        // shaping between Saturday 18:36 and Sunday 02:22, closest to 23:27
        // within the window is Saturday 21:00. Proof 21:00 – 09:10 = 12 h 10 min.
        // Bulk 3 − 0.75 = 2.25 h from 18:30, kneading 18:10, sourdough 8 h
        // from 10:10, mixed 10:00.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 30, vessel: .pot, temperatures: kitchen, calendar: utc)
        #expect(close(schedule.steps[7].start, nov(15, 9, 10)))
        #expect(close(schedule.steps[6].start, nov(15, 8, 25)))
        let proof = schedule.rest(.proof)!
        #expect(proof.kind == .rest(.proof, .fridge))
        #expect(close(proof.start, nov(14, 21)))
        #expect(abs(proof.hours - (12 + 10.0 / 60)) < 1e-9)
        #expect(close(schedule.rest(.bulk)!.start, nov(14, 18, 30)))
        #expect(close(schedule.start, nov(14, 10)))
        #expect(schedule.conflicts.isEmpty)
    }

    @Test func aChosenRestIsKeptAndMayLeaveTheWindow() {
        // As in the first case, but the sourdough ripens 10 h, the most it may
        // at 22 °C: from 06:20, mixed at 06:10 — outside the window.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                                choices: [.sourdough: RestChoice(place: .room, hours: 10)], calendar: utc)
        #expect(close(schedule.start, nov(14, 6, 10)))
        #expect(schedule.conflicts == [.mixSourdough])
    }

    @Test func aChosenRestIsClampedToItsRange() {
        // Sourdough at 22 °C: at most 1.25 × 8 = 10 h, so 20 h become 10 h:
        // 16:20 − 10 h = 06:20, mixed 06:10. At least 0.8 × 8 = 6.4 h, so 2 h
        // become 6 h 24 min: from 09:56.
        let long = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                            choices: [.sourdough: RestChoice(place: .room, hours: 20)], calendar: utc)
        #expect(close(long.rest(.sourdough)!.start, nov(14, 6, 20)))
        #expect(close(long.start, nov(14, 6, 10)))
        let short = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                             choices: [.sourdough: RestChoice(place: .room, hours: 2)], calendar: utc)
        #expect(close(short.rest(.sourdough)!.start, nov(14, 9, 56)))
    }

    @Test func aCoolPlaceTakesItsOwnTemperature() {
        // Sourdough at 16 °C: 8 × 3^0.6 = 15.47 h, range 12.37 to 19.33 h; 15 h
        // are in it, so 16:20 − 15 h = 01:20, mixed 01:10 (outside the window).
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                                choices: [.sourdough: RestChoice(place: .cool, hours: 15)], calendar: utc)
        let sourdough = schedule.rest(.sourdough)!
        #expect(sourdough.kind == .rest(.sourdough, .cool))
        #expect(close(sourdough.start, nov(14, 1, 20)))
        #expect(close(schedule.start, nov(14, 1, 10)))
        #expect(schedule.conflicts == [.mixSourdough])
    }

    @Test func aChosenCoolPlaceIsIgnoredWhenTheKitchenHasNone() {
        // Without a cool place the choice is void and the sourdough is
        // planned as in the first case: room, 08:20 to 16:20.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot,
                                temperatures: Temperatures(usesCoolPlace: false),
                                choices: [.sourdough: RestChoice(place: .cool, hours: 15)], calendar: utc)
        #expect(schedule.rest(.sourdough)!.kind == .rest(.sourdough, .room))
        #expect(close(schedule.rest(.sourdough)!.start, nov(14, 8, 20)))
        #expect(schedule.conflicts.isEmpty)
    }

    @Test func aWarmPlaceShortensTheRest() {
        // Sourdough warm at 27 °C: 8 × 3^(−0.5) = 4.6188 h before 16:20.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                                choices: [.sourdough: RestChoice(place: .warm, hours: 8 / 3.0.squareRoot())],
                                calendar: utc)
        let sourdough = schedule.rest(.sourdough)!
        #expect(sourdough.kind == .rest(.sourdough, .warm))
        #expect(abs(sourdough.hours - 4.618802) < 1e-6)
        #expect(schedule.conflicts.isEmpty)
    }

    @Test func withoutAnyRoomEveryActionIsAConflict() {
        // A window that closes when it opens: nothing fits, the rests take
        // their nominal times at the usual place.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                                window: InteractionWindow(startHour: 8, endHour: 8), calendar: utc)
        #expect(schedule.conflicts == [.mixSourdough, .knead, .shape, .preheat, .bake])
        // Cooling 6 h from 06:00, baking from 05:10, proof 1.5 h from 03:40.
        #expect(close(schedule.rest(.proof)!.start, nov(15, 3, 40)))
        #expect(schedule.rest(.proof)!.kind == .rest(.proof, .room))
    }

    @Test func theProposedTargetIsTheFirstThatStartsLaterWithoutConflicts() {
        // Now: Friday 09:00, Roggenmischbrot 50 in the pot.
        // - Friday 12:00: the bake ends Thursday 21:00, long before now.
        // - Friday 18:00: the bake ends 12:00, the proof (room, 1.5 h) starts
        //   09:40, the bulk rest at room (1.49–2.1 h) would need kneading before
        //   08:00, warm (27 °C, 1.75 × 3^−0.5 = 1.01 h) works: kneading ends
        //   08:24. The sourdough then ripens at the cool place (room: 6.4 to
        //   10 h, no start in the window) for 8 × 3^0.6 = 15.47 h: mixed on
        //   Thursday afternoon, before now.
        // - Saturday 12:00: the bake ends Friday 21:00, proof 17:55, bulk 15:55
        //   at room, then the sourdough at room needs mixing at 08:00 on
        //   Friday: before now.
        // - Saturday 18:00 is Friday 18:00 a day later: the sourdough mixed
        //   Friday afternoon, 8:04 + 20 min kneading.
        let target = Schedule.proposedTarget(after: nov(13, 9), ryeShare: 50, vessel: .pot,
                                             temperatures: kitchen, calendar: utc)
        #expect(target == nov(14, 18))
        let schedule = Schedule(target: target, ryeShare: 50, vessel: .pot, temperatures: kitchen, calendar: utc)
        #expect(schedule.rest(.bulk)!.kind == .rest(.bulk, .warm))
        #expect(schedule.rest(.sourdough)!.kind == .rest(.sourdough, .cool))
        // Warm bulk ends at shaping, 09:25; it takes 1.75 / √3 h; kneading
        // 20 min; the sourdough 8 × 3^0.6 h and the mixing 10 min before it.
        let knead = nov(14, 9, 25) - (1.75 / 3.0.squareRoot() + 1.0 / 3) * 3600
        let mixing = knead - 8 * pow(3.0, 0.6) * 3600 - 600
        #expect(close(schedule.start, mixing))
        #expect(schedule.conflicts.isEmpty)
        #expect(schedule.start > nov(13, 9))
    }

    @Test func withoutAFittingTargetItIsNoonAWeekLater() {
        let target = Schedule.proposedTarget(after: nov(13, 9), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                                             window: InteractionWindow(startHour: 8, endHour: 8), calendar: utc)
        #expect(target == nov(20, 12))
    }
}

struct RangeScaleTests {
    @Test func aLogarithmicScaleGivesEqualFactorsEqualWidths() {
        // 1 to 100 h: 10 h is the middle, as it is two factors of 10 from 1 h
        // either way. log₁₀ 2 / 2 = 0.150515 is the share of a doubling from 1 h.
        let scale = RangeScale(lowerBound: 1, upperBound: 100)
        #expect(abs(scale.position(of: 10) - 0.5) < 1e-12)
        #expect(scale.position(of: 1) == 0)
        #expect(abs(scale.position(of: 100) - 1) < 1e-12)
        #expect(abs(scale.position(of: 2) - 0.150515) < 1e-6)
        // A doubling is as wide at 10 h as at 1 h.
        #expect(abs((scale.position(of: 20) - scale.position(of: 10)) - 0.150515) < 1e-6)
        // 2 h to 32 h are four doublings: each takes a quarter.
        let octaves = RangeScale(lowerBound: 2, upperBound: 32)
        #expect(abs(octaves.position(of: 4) - 0.25) < 1e-12)
        #expect(abs(octaves.position(of: 8) - 0.5) < 1e-12)
        #expect(abs(octaves.position(of: 16) - 0.75) < 1e-12)
    }

    @Test func beyondTheEndsThePositionStaysAtTheEnds() {
        let scale = RangeScale(lowerBound: 1, upperBound: 100)
        #expect(scale.position(of: 0.5) == 0)
        #expect(scale.position(of: 1000) == 1)
    }

    @Test func aScaleCoversAllRangesWithAMarginOnBothEnds() {
        // 2 to 4 h and 8 to 16 h with a margin of 2: from 1 h to 32 h, five
        // doublings, so 2 h is at 1/5, 4 h at 2/5, 8 h at 3/5, 16 h at 4/5.
        let scale = RangeScale(covering: [2...4, 8...16], margin: 2)
        #expect(scale.lowerBound == 1 && scale.upperBound == 32)
        #expect(abs(scale.position(of: 2) - 0.2) < 1e-12)
        #expect(abs(scale.position(of: 4) - 0.4) < 1e-12)
        #expect(abs(scale.position(of: 8) - 0.6) < 1e-12)
        #expect(abs(scale.position(of: 16) - 0.8) < 1e-12)
        // The margin is 15 % unless said otherwise.
        let usual = RangeScale(covering: [2...4])
        #expect(RangeScale.margin == 1.15)
        #expect(abs(usual.lowerBound - 2 / 1.15) < 1e-12 && abs(usual.upperBound - 4 * 1.15) < 1e-12)
    }

    @Test func allPlacesOfARestShareOneScale() {
        // The sourdough takes 8 h at 22 °C; the ranges of its places are
        // 0.8 to 1.25 times the nominal time: warm (27 °C, 8 / √3 = 4.619 h)
        // from 6.4 / √3 = 3.695 h, room (22 °C) up to 10 h, cool (16 °C,
        // 8 × 3^0.6 = 15.465 h) up to 10 × 3^0.6 = 19.332 h.
        let kitchen = Temperatures(roomCelsius: 22, fridgeCelsius: 5, coolCelsius: 16)
        let scale = ScheduleRules.scale(.sourdough, ryeShare: 50, temperatures: kitchen)
        #expect(abs(scale.lowerBound - 6.4 / 3.0.squareRoot() / 1.15) < 1e-9)
        #expect(abs(scale.upperBound - 10 * pow(3, 0.6) * 1.15) < 1e-9)
        // Without the cool place the room, at most 10 h, is the longest.
        let noCool = Temperatures(roomCelsius: 22, fridgeCelsius: 5, usesCoolPlace: false)
        let narrow = ScheduleRules.scale(.sourdough, ryeShare: 50, temperatures: noCool)
        #expect(abs(narrow.lowerBound - scale.lowerBound) < 1e-12)
        #expect(abs(narrow.upperBound - 10 * 1.15) < 1e-9)
        // The range of one place is as wide as the next on this scale: both
        // are 0.8 to 1.25 times the nominal time, a factor of 1.5625.
        func width(_ place: Place) -> Double {
            let range = ScheduleRules.range(.sourdough, ryeShare: 50, place: place, temperatures: kitchen)
            return scale.position(of: range.upperBound) - scale.position(of: range.lowerBound)
        }
        #expect(abs(width(.warm) - width(.cool)) < 1e-12)
        #expect(abs(width(.room) - width(.cool)) < 1e-12)
        // A longer rest is further right.
        #expect(scale.position(of: 8) < scale.position(of: 15.465))
        // The proof has the fridge, whose range goes to 1.5 × 1.5 × 3^1.7 h.
        let proof = ScheduleRules.scale(.proof, ryeShare: 0, temperatures: kitchen)
        #expect(abs(proof.upperBound - 1.5 * 1.5 * pow(3, 1.7) * 1.15) < 1e-9)
        #expect(abs(proof.lowerBound - 0.85 * 1.5 / 3.0.squareRoot() / 1.15) < 1e-9)
    }
}

struct TargetTemperatureTests {
    private let kitchen = Temperatures(roomCelsius: 22, fridgeCelsius: 5)

    @Test func atTheNominalTimeARestAimsForTheTemperatureOfItsPlace() {
        // The reference plan for Saturday 18:00: sourdough at the cool place
        // (16 °C), warm bulk rest (27 °C), proof at room temperature (22 °C),
        // each at its nominal time.
        let schedule = Schedule(target: nov(14, 18), ryeShare: 50, vessel: .pot, temperatures: kitchen, calendar: utc)
        #expect(abs(schedule.rest(.sourdough)!.celsius! - 16) < 1e-9)
        #expect(abs(schedule.rest(.bulk)!.celsius! - 27) < 1e-9)
        #expect(abs(schedule.rest(.proof)!.celsius! - 22) < 1e-9)
        #expect(schedule.steps.filter { $0.celsius != nil }.count == 3)
        let celsius = schedule.restCelsius
        #expect(Set(celsius.keys) == [.sourdough, .bulk, .proof])
        #expect(abs(celsius[.bulk]! - 27) < 1e-9)
    }

    @Test func aRestLongerThanNominalAimsColder() {
        // The fridge proof of Sunday 12:00 at 30 % rye lasts 12 h 10 min
        // (see `aMorningBakeSendsTheProofIntoTheFridge`): 22 − 10 × log₃(12.1667 /
        // 1.5) = 22 − 10 × ln 8.1111 / ln 3 = 22 − 10 × 2.09324 / 1.09861 = 2.946 °C,
        // colder than the 5 °C of the fridge.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 30, vessel: .pot, temperatures: kitchen, calendar: utc)
        #expect(abs(schedule.rest(.proof)!.celsius! - 2.946) < 0.001)
    }

    @Test func aClampedChoiceAimsForTheTemperatureOfItsHours() {
        // A proof of 1.8 h at room temperature, the most its range allows:
        // 22 − 10 × log₃(1.8 / 1.5) = 22 − 10 × 0.18232 / 1.09861 = 20.340 °C.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                                choices: [.proof: RestChoice(place: .room, hours: 1.8)], calendar: utc)
        #expect(abs(schedule.rest(.proof)!.celsius! - 20.340) < 0.001)
    }
}

struct ForwardScheduleTests {
    private let kitchen = Temperatures()
    private let sqrt3 = 3.0.squareRoot()
    /// 8 h × 3^0.6: the sourdough at the cool place (16 °C), 15.4655 h.
    private let coolSourdough = 8 * pow(3.0, 0.6)

    private func forward(_ start: Date, window: InteractionWindow = InteractionWindow(),
                         choices: [RestKind: RestChoice] = [:]) -> Schedule {
        Schedule(start: start, ryeShare: 50, vessel: .pot, temperatures: kitchen, window: window,
                 choices: choices, calendar: utc)
    }

    @Test func theReferencePlanForwardsComesBackToItsTarget() {
        // Backwards from Saturday 18:00 (Roggenmischbrot 50, pot, room 22 °C,
        // fridge 5 °C, cool place 16 °C): proof 1.5 h at room temperature from
        // 09:40, shaping 09:25, warm bulk rest 1.75 / √3 = 1.0104 h, kneading
        // from 08:04:23, the sourdough 8 × 3^0.6 = 15.4655 h = 15 h 28 min at
        // the cool place from Friday 16:36, mixed at 16:26.
        let backward = Schedule(target: nov(14, 18), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                                calendar: utc)
        let mixing = nov(14, 9, 25) - (1.75 / sqrt3 + 20.0 / 60 + coolSourdough + 10.0 / 60) * 3600
        #expect(close(backward.start, mixing))
        #expect(backward.start >= nov(13, 16, 26) && backward.start < nov(13, 16, 27))
        let choices = backward.restChoices
        #expect(choices[.sourdough]?.place == .cool && abs(choices[.sourdough]!.hours - coolSourdough) < 1e-9)
        #expect(choices[.bulk]?.place == .warm && abs(choices[.bulk]!.hours - 1.75 / sqrt3) < 1e-9)
        #expect(choices[.proof]?.place == .room && abs(choices[.proof]!.hours - 1.5) < 1e-9)
        // Forwards from that start with the same rests: every step where it
        // was, and the bread ready at Saturday 18:00 exactly.
        let schedule = forward(backward.start, choices: choices)
        #expect(close(schedule.target, nov(14, 18)))
        #expect(schedule.steps.map(\.kind) == backward.steps.map(\.kind))
        for (step, expected) in zip(schedule.steps, backward.steps) {
            #expect(close(step.start, expected.start) && close(step.end, expected.end), "\(step.kind)")
        }
        #expect(schedule.conflicts.isEmpty)
    }

    @Test func forwardsEachRestTakesThePlaceThatPutsTheNextActionIntoTheWindow() {
        // From Friday 16:30: mixing until 16:40. The sourdough at room
        // temperature (6.4 to 10 h) would put kneading (20 min) between 23:04
        // and 02:40: not in 8–21 h. At the cool place 15.4655 h end at 08:07:56
        // on Saturday, kneading until 08:27:56 fits. The bulk rest at room
        // temperature, 1.75 h, ends 10:12:56, shaping until 10:27:56; the proof
        // 1.5 h at room temperature ends 11:57:56, preheating from 11:12:56,
        // baking until 12:47:56, cooling 6 h: ready at 18:47:56.
        let schedule = forward(nov(13, 16, 30))
        #expect(schedule.steps.map(\.kind) == [
            .action(.mixSourdough), .rest(.sourdough, .cool), .action(.knead), .rest(.bulk, .room),
            .action(.shape), .rest(.proof, .room), .action(.preheat), .action(.bake), .cooling,
        ])
        let knead = nov(13, 16, 40) + coolSourdough * 3600
        #expect(close(schedule.steps[2].start, knead))
        #expect(close(schedule.steps[4].start, knead + (20.0 / 60 + 1.75) * 3600))
        let bake = knead + (20.0 / 60 + 1.75 + 15.0 / 60 + 1.5) * 3600
        #expect(close(schedule.steps[6].start, bake - 45 * 60))
        #expect(close(schedule.steps[7].start, bake))
        #expect(close(schedule.target, bake + (50.0 / 60 + 6) * 3600))
        #expect(schedule.conflicts.isEmpty)
        #expect(close(schedule.start, nov(13, 16, 30)))
        #expect(abs(schedule.rest(.sourdough)!.celsius! - 16) < 1e-9)
    }

    @Test func aTargetInTheNightIsNoConflict() {
        // From Friday 08:00, all at room temperature: mixing to 08:10,
        // sourdough 8 h to 16:10, kneading to 16:30, bulk 1.75 h to 18:15,
        // shaping to 18:30, proof 1.5 h to 20:00, preheating 19:15, baking
        // 20:00 to 20:50, cooling 6 h: ready Saturday 02:50.
        let schedule = forward(nov(13, 8))
        #expect(schedule.steps.compactMap(\.place) == [.room, .room, .room])
        #expect(close(schedule.steps[7].start, nov(13, 20)))
        #expect(close(schedule.target, nov(14, 2, 50)))
        #expect(schedule.conflicts.isEmpty)
    }

    @Test func aShorterRestMovesEveryStepAfterIt() {
        // As before, with the sourdough one hour shorter, 7 h (within 6.4 to
        // 10 h): everything after it comes one hour earlier, ready 01:50.
        let plain = forward(nov(13, 8))
        let shorter = forward(nov(13, 8), choices: [.sourdough: RestChoice(place: .room, hours: 7)])
        #expect(shorter.steps[0] == plain.steps[0])
        for (step, before) in zip(shorter.steps.dropFirst(2), plain.steps.dropFirst(2)) {
            #expect(close(step.start, before.start - 3600) && close(step.end, before.end - 3600))
        }
        #expect(close(shorter.target, nov(14, 1, 50)))
        #expect(shorter.conflicts.isEmpty)
    }

    @Test func aChosenRestIsClampedAndMayPushTheNextActionOutOfTheWindow() {
        // From Friday 12:00 a sourdough of 20 h at room temperature is
        // clamped to 10 h: 12:10 to 22:10, kneading 22:10 — outside.
        let schedule = forward(nov(13, 12), choices: [.sourdough: RestChoice(place: .room, hours: 20)])
        #expect(abs(schedule.rest(.sourdough)!.hours - 10) < 1e-9)
        #expect(close(schedule.steps[2].start, nov(13, 22, 10)))
        #expect(schedule.conflicts.first == .knead)
    }

    @Test func aLateStartIsAConflictOfTheMixing() {
        // From Friday 21:30 the mixing ends 21:40, after the window. The
        // sourdough then goes to the cool place (room: kneading at 04:04 to
        // 07:40, too early) and kneading falls at 13:07:56 on Saturday.
        let schedule = forward(nov(13, 21, 30))
        #expect(schedule.conflicts == [.mixSourdough])
        #expect(schedule.rest(.sourdough)!.kind == .rest(.sourdough, .cool))
    }

    @Test func withoutAnyRoomEveryActionIsAConflictForwardsToo() {
        // The window closes when it opens: every rest takes its nominal time
        // at room temperature. From Friday 16:30: 10 + 20 + 15 + 50 min of
        // actions and 8 + 1.75 + 1.5 + 6 h of rests and cooling, 18 h 50 min:
        // ready Saturday 11:20.
        let schedule = forward(nov(13, 16, 30), window: InteractionWindow(startHour: 8, endHour: 8))
        #expect(schedule.conflicts == [.mixSourdough, .knead, .shape, .preheat, .bake])
        #expect(schedule.steps.compactMap(\.place) == [.room, .room, .room])
        #expect(close(schedule.target, nov(14, 11, 20)))
    }

    @Test func theAnchorChoosesTheDirection() {
        let ready = Schedule(anchor: .ready, time: nov(14, 18), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                             calendar: utc)
        #expect(ready == Schedule(target: nov(14, 18), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                                  calendar: utc))
        let start = Schedule(anchor: .start, time: nov(13, 8), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                             calendar: utc)
        #expect(start == forward(nov(13, 8)))
        #expect(ScheduleAnchor.allCases == [.ready, .start])
        #expect(start.time(of: .start) == nov(13, 8))
        #expect(ready.time(of: .ready) == nov(14, 18))
        #expect(close(start.time(of: .ready), nov(14, 2, 50)))
    }
}

struct ScheduleDaysTests {
    private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    /// Roggenmischbrot 50 in the pot for Saturday 14th, 18:00, at 22 °C (the plan
    /// the interface tests use). Cooling 6 h (rye ≥ 50 %): baking 11:10 to 12:00
    /// (pot, 50 min), preheating 10:25 to 11:10, proof 1.5 h at room temperature
    /// 09:40 to 11:10, shaping 09:25 to 09:40, warm bulk rest 1.75 h × 3^−0.5 =
    /// 1.01036 h, kneading 20 min, then the sourdough rest at the cool place
    /// (16 °C): 8 × 3^0.6 = 15.465 h overnight from Friday 16:36, with the
    /// mixing before it, 16:26 to 16:36.
    private func schedule(choices: [RestKind: RestChoice] = [:]) -> Schedule {
        Schedule(target: nov(14, 18), ryeShare: 50, vessel: .pot, temperatures: Temperatures(),
                 choices: choices, calendar: utc)
    }

    @Test func oneRowPerCalendarDay() {
        let strip = ScheduleDays(schedule(), calendar: utc)
        #expect(strip.days.map(\.start) == [nov(13, 0), nov(14, 0)])
        #expect(strip.days.map(\.id) == [nov(13, 0), nov(14, 0)])
        #expect(ScheduleDays.firstHour == 7 && ScheduleDays.lastHour == 22)
    }

    @Test func theAfternoonOfFridayHoldsTheMixAndTheStartOfTheOvernightRest() {
        let friday = ScheduleDays(schedule(), calendar: utc).days[0]
        #expect(friday.segments.count == 2)
        // The rest starts where kneading on Saturday (8.07297 h) lies 15.465 h
        // earlier: 24 + 8.07297 − 8 × 3^0.6 h on Friday, the mixing 10 min
        // before it. In the row, 7 h are cut off and 15 h remain.
        let kneadStart = 9.0 + 25.0 / 60 - 1.75 / 3.0.squareRoot() - 20.0 / 60
        let restStart = 24 + kneadStart - 8 * pow(3.0, 0.6)
        let mix = friday.segments[0]
        #expect(mix.kind == .action(.mixSourdough))
        #expect(close(mix.from, (restStart - 10.0 / 60 - 7) / 15) && close(mix.to, (restStart - 7) / 15))
        #expect(!mix.continuesBefore && !mix.continuesAfter && !mix.inTheNight)
        // The rest runs out of the row at 22:00 into the night.
        let rest = friday.segments[1]
        #expect(rest.kind == .rest(.sourdough, .cool))
        #expect(close(rest.from, (restStart - 7) / 15) && close(rest.to, 1))
        #expect(!rest.continuesBefore && rest.continuesAfter)
        #expect(friday.target == nil)
    }

    @Test func theNightRestComesBackInTheMorningOfSaturday() {
        let saturday = ScheduleDays(schedule(), calendar: utc).days[1]
        let rest = saturday.segments[0]
        #expect(rest.kind == .rest(.sourdough, .cool))
        // It ends where kneading starts: 9:25 − 1.75/√3 h − 20 min = 8.07297 h,
        // 1.07297 h after 07:00.
        let kneadStart = 9.0 + 25.0 / 60 - 1.75 / 3.0.squareRoot() - 20.0 / 60
        #expect(close(rest.from, 0) && close(rest.to, (kneadStart - 7) / 15))
        #expect(rest.continuesBefore && !rest.continuesAfter)
    }

    @Test func daytimeStepsStandWhereTheirTimesPutThem() {
        let saturday = ScheduleDays(schedule(), calendar: utc).days[1]
        func segment(_ kind: ScheduleStep.Kind) -> ScheduleDays.Segment {
            saturday.segments.first { $0.kind == kind }!
        }
        // Baking 11:10 to 12:00: 4 h 10 min to 5 h of 15 h.
        let bake = segment(.action(.bake))
        #expect(close(bake.from, (4.0 + 10.0 / 60) / 15) && close(bake.to, 5.0 / 15))
        // Preheating 10:25 to 11:10.
        let preheat = segment(.action(.preheat))
        #expect(close(preheat.from, (3.0 + 25.0 / 60) / 15) && close(preheat.to, (4.0 + 10.0 / 60) / 15))
        // Proof 09:40 to 11:10.
        let proof = segment(.rest(.proof, .room))
        #expect(close(proof.from, (2.0 + 40.0 / 60) / 15) && close(proof.to, (4.0 + 10.0 / 60) / 15))
        // Cooling 12:00 to 18:00, which is also where the bread can be cut.
        let cooling = segment(.cooling)
        #expect(close(cooling.from, 5.0 / 15) && close(cooling.to, 11.0 / 15))
        #expect(saturday.target.map { close($0, 11.0 / 15) } == true)
        // Preheating and the proof overlap in time, so they stay separate segments.
        #expect(saturday.segments.map(\.stepIndex) == saturday.segments.map(\.stepIndex).sorted())
    }

    @Test func aStepCompletelyInTheNightIsAMarkAtTheEdgeOfItsDay() {
        // The proof in the fridge at 5 °C, 1.5 h × 3^1.7 = 9.71 h, starts at about
        // 01:27 on Saturday; shaping 01:12 to 01:27 and, before the warm bulk
        // rest, kneading fall into the night: kneading on Friday 23:07 to
        // 23:27, shaping on Saturday 01:12.
        let hours = 1.5 * pow(3.0, 1.7)
        let strip = ScheduleDays(schedule(choices: [.proof: RestChoice(place: .fridge, hours: hours)]),
                                 calendar: utc)
        let knead = strip.days[0].segments.first { $0.kind == .action(.knead) }!
        #expect(knead.inTheNight && knead.from == 1 && knead.to == 1)
        #expect(knead.outsideWindow)
        let shape = strip.days[1].segments.first { $0.kind == .action(.shape) }!
        #expect(shape.inTheNight && shape.from == 0 && shape.to == 0)
        // A step with a visible part is no mark.
        #expect(strip.days[0].segments.contains { !$0.inTheNight })
    }

    @Test func theTargetSitsInTheLastRowAndTheRowsFollowEachOther() {
        // Rye 100 %: cooling a day (24 h) puts the target a day after baking, so
        // the rows are the days between, one each.
        let schedule = Schedule(target: nov(16, 18), ryeShare: 100, vessel: .pot, temperatures: Temperatures(),
                                calendar: utc)
        let strip = ScheduleDays(schedule, calendar: utc)
        #expect(strip.days.last!.start == nov(16, 0))
        #expect(strip.days.last!.target.map { close($0, 11.0 / 15) } == true)
        #expect(strip.days.dropLast().allSatisfy { $0.target == nil })
        #expect(strip.days.count >= 2)
        // The days are consecutive.
        #expect(zip(strip.days, strip.days.dropFirst()).allSatisfy {
            utc.date(byAdding: .day, value: 1, to: $0.start) == $1.start
        })
    }
}
