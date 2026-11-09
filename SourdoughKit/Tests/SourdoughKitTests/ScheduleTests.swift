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
        #expect(Place.allCases.map(temperatures.celsius) == [27, 20, 6])
        #expect(Temperatures().roomCelsius == 22)
        #expect(Temperatures().fridgeCelsius == 5)
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
        #expect(RestKind.allCases.map(\.places) == [[.room, .warm], [.room, .warm], [.room, .fridge, .warm]])
        #expect(RestKind.allCases.map(\.factorRange) == [0.6...1.6, 0.7...1.5, 0.7...1.5])
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
        // Proof at 22 °C: 1.5 h, 0.7 × = 1.05 h to 1.5 × = 2.25 h.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: kitchen, calendar: utc)
        let proof = schedule.rest(.proof)!
        #expect(abs(proof.hourRange!.lowerBound - 1.05) < 1e-9)
        #expect(abs(proof.hourRange!.upperBound - 2.25) < 1e-9)
        #expect(schedule.steps.first?.hourRange == nil)
    }

    @Test func aMorningBakeSendsTheProofIntoTheFridge() {
        // 30 % rye: cooling 2 h, so the bake ends Sunday 10:00, starts 09:10.
        // A room proof (1.05–2.25 h) would need shaping before 08:15. In the
        // fridge at 5 °C the proof takes 1.5 × 3^1.7 = 9.71 h, 6.80 to 14.56 h:
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
        // As in the first case, but the sourdough ripens 12 h: from 04:20,
        // mixed at 04:10 — outside the window.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                                choices: [.sourdough: RestChoice(place: .room, hours: 12)], calendar: utc)
        #expect(close(schedule.start, nov(14, 4, 10)))
        #expect(schedule.conflicts == [.mixSourdough])
    }

    @Test func aChosenRestIsClampedToItsRange() {
        // Sourdough at 22 °C: at most 1.6 × 8 = 12.8 h, so 20 h become 12.8 h:
        // 16:20 − 12 h 48 min = 03:32, mixed 03:22.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                                choices: [.sourdough: RestChoice(place: .room, hours: 20)], calendar: utc)
        #expect(close(schedule.rest(.sourdough)!.start, nov(14, 3, 32)))
        #expect(close(schedule.start, nov(14, 3, 22)))
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
        // - Friday 12:00 and Saturday 12:00 need the sourdough mixed at 08:10
        //   of the day before: too early.
        // - Friday 18:00: the bake ends 12:00, the proof (room, 1.5 h) starts
        //   09:40, the bulk at room would need kneading before 08:00, warm
        //   (27 °C, 1.75 × 3^−0.5 = 1.01 h) works: kneading ends 08:24. The
        //   sourdough then needs mixing on Thursday evening: too early.
        // - Saturday 18:00 is the same a day later: mixed Friday 20:50.
        let target = Schedule.proposedTarget(after: nov(13, 9), ryeShare: 50, vessel: .pot,
                                             temperatures: kitchen, calendar: utc)
        #expect(target == nov(14, 18))
        let schedule = Schedule(target: target, ryeShare: 50, vessel: .pot, temperatures: kitchen, calendar: utc)
        #expect(close(schedule.start, nov(13, 20, 50)))
        #expect(schedule.rest(.bulk)!.kind == .rest(.bulk, .warm))
    }

    @Test func withoutAFittingTargetItIsNoonAWeekLater() {
        let target = Schedule.proposedTarget(after: nov(13, 9), ryeShare: 50, vessel: .pot, temperatures: kitchen,
                                             window: InteractionWindow(startHour: 8, endHour: 8), calendar: utc)
        #expect(target == nov(20, 12))
    }
}
