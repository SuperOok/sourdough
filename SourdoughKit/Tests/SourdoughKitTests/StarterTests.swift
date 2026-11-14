import Foundation
import Testing
@testable import SourdoughKit

struct StarterTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func feeding(at date: Date, starter: Double = 10, flour: Double = 15,
                         water: Double = 15) -> Feeding {
        Feeding(date: date, starterGrams: starter, flourGrams: flour, waterGrams: water)
    }

    @Test func flourTimeFactors() {
        #expect(FlourType.rye.timeFactor == 0.8)
        #expect(FlourType.wheat.timeFactor == 1.0)
        #expect(FlourType.spelt.timeFactor == 0.9)
        #expect(FlourType.buckwheat.timeFactor == 1.0)
        #expect(FlourType.allCases == [.rye, .wheat, .spelt, .buckwheat])
        // A starter is made of one of the grains, not of buckwheat.
        #expect(FlourType.starterGrains == [.rye, .wheat, .spelt])
    }

    @Test func hydrationOfAFeeding() {
        #expect(feeding(at: t0, flour: 50, water: 40).hydration == 80)
        #expect(feeding(at: t0, flour: 0, water: 40).hydration == nil)
    }

    @Test func celsiusFollowsTheStorage() {
        var starter = Starter(name: "A", flour: .rye, createdAt: t0, inFridge: true, fridgeCelsius: 4)
        #expect(starter.celsius == 4)
        starter.inFridge = false
        #expect(starter.celsius == 22)
        starter.roomCelsius = 19
        #expect(starter.celsius == 19)
    }

    @Test func aStarterSavedWithoutRoomTemperatureGetsTheDefault() throws {
        // As saved before the room temperature was added.
        let json = """
            {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Alt","flour":"rye","createdAt":0,
             "feedings":[],"inFridge":false,"fridgeCelsius":5}
            """
        let starter = try JSONDecoder().decode(Starter.self, from: Data(json.utf8))
        #expect(starter.roomCelsius == 22)
        #expect(starter.name == "Alt")
        #expect(!starter.inFridge)
    }

    @Test func aStarterSavedBeforeTheOriginReadsAsInoculated() throws {
        // As saved by version 1.1: no origin, a first mix without estimate or rise.
        let json = """
            {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Alt","flour":"wheat","createdAt":0,
             "feedings":[{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","date":0,"starterGrams":0,
                          "flourGrams":50,"waterGrams":50}],
             "inFridge":false,"fridgeCelsius":5,"roomCelsius":22}
            """
        let starter = try JSONDecoder().decode(Starter.self, from: Data(json.utf8))
        #expect(starter.origin == .inoculated)
        let first = try #require(starter.feedings.first)
        #expect(!first.isEstimate)
        #expect(first.rise == nil)
        // Its state is as before: the first mix counts as dilution 3, wheat at
        // 22 °C doubles in 3 h, so the peak is log2(3) × 3 h ≈ 1.585 × 3 = 4.755 h.
        #expect(!starter.isEstablishing)
        let status = try #require(starter.status(at: Date(timeIntervalSince1970: 0)))
        #expect(abs(status.peakHours - 4.755) < 1e-3)
    }

    @Test func originsAndRises() {
        #expect(StarterOrigin.allCases.map(\.rawValue) == ["existing", "inoculated", "spontaneous"])
        #expect(Rise.allCases.map(\.rawValue) == ["doubled", "some", "none"])
        #expect(Starter(name: "A", flour: .rye, createdAt: t0).origin == .inoculated)
    }

    @Test func anEstimateHoldsOnlyTheAmountReceived() {
        let estimate = Feeding.estimate(date: t0, grams: 80)
        #expect(estimate.isEstimate)
        #expect(estimate.starterGrams == 80)
        #expect(estimate.flourGrams == 0)
        #expect(estimate.waterGrams == 0)
        #expect(estimate.rise == nil)
        #expect(estimate.hydration == nil)
    }

    @Test func ageNeverGoesNegative() {
        let starter = Starter(name: "A", flour: .rye, createdAt: t0)
        #expect(starter.age(at: t0.addingTimeInterval(3600)) == 3600)
        #expect(starter.age(at: t0.addingTimeInterval(-5)) == 0)
    }

    @Test func lastFeedingIsTheLatestByDateNotByPosition() {
        let early = feeding(at: t0)
        let late = feeding(at: t0.addingTimeInterval(100))
        let starter = Starter(name: "A", flour: .rye, createdAt: t0, feedings: [late, early])
        #expect(starter.lastFeeding == late)
        #expect(Starter(name: "B", flour: .rye, createdAt: t0).lastFeeding == nil)
    }

    @Test func survivesAJSONRoundTrip() throws {
        let starter = Starter(name: "A", flour: .spelt, createdAt: t0,
                              feedings: [feeding(at: t0), Feeding(date: t0 + 60, starterGrams: 10, flourGrams: 10,
                                                                  waterGrams: 10, rise: .some),
                                         Feeding.estimate(date: t0 - 60, grams: 40)],
                              inFridge: false, fridgeCelsius: 7, roomCelsius: 19, origin: .spontaneous)
        let data = try JSONEncoder().encode([starter])
        #expect(try JSONDecoder().decode([Starter].self, from: data) == [starter])
    }
}

// Expected values are worked out by hand.
//
// Dilution 4 (10 g starter + 15 g flour + 15 g water = 40 g / 10 g) is
// 2 doublings. Wheat at 22 °C doubles every 3 h, so the peak is after 6 h;
// the window 0.75 … 1.5 × is 4.5 … 9 h, hungry at 2.5 × = 15 h, neglected at
// 4 × = 24 h.
struct StarterModelTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func wheat(inFridge: Bool = false, celsius: Double = 5, fedAt: Date? = nil,
                       starter: Double = 10, flour: Double = 15, water: Double = 15) -> Starter {
        Starter(name: "W", flour: .wheat, createdAt: t0,
                feedings: [Feeding(date: fedAt ?? t0, starterGrams: starter, flourGrams: flour,
                                   waterGrams: water)],
                inFridge: inFridge, fridgeCelsius: celsius)
    }

    @Test func doublingTimeAtRoomTemperature() {
        #expect(StarterModel.doublingHours(celsius: 22, flour: .wheat) == 3)
        #expect(abs(StarterModel.doublingHours(celsius: 22, flour: .rye) - 2.4) < 1e-12)
        #expect(abs(StarterModel.doublingHours(celsius: 22, flour: .spelt) - 2.7) < 1e-12)
    }

    @Test func tenDegreesColderTakesThreeTimesAsLong() {
        #expect(abs(StarterModel.doublingHours(celsius: 12, flour: .wheat) - 9) < 1e-12)
        #expect(abs(StarterModel.doublingHours(celsius: 2, flour: .wheat) - 27) < 1e-12)
    }

    @Test func tenDegreesWarmerTakesAThirdOfTheTime() {
        #expect(abs(StarterModel.doublingHours(celsius: 32, flour: .wheat) - 1) < 1e-12)
    }

    @Test func dilutionAndPeak() {
        let feeding = Feeding(date: t0, starterGrams: 10, flourGrams: 15, waterGrams: 15)
        #expect(StarterModel.dilution(of: feeding) == 4)
        #expect(abs(StarterModel.peakHours(of: feeding, celsius: 22, flour: .wheat) - 6) < 1e-12)
        #expect(abs(StarterModel.peakHours(of: feeding, celsius: 22, flour: .rye) - 4.8) < 1e-12)
        #expect(abs(StarterModel.peakHours(of: feeding, celsius: 12, flour: .wheat) - 18) < 1e-12)
    }

    @Test func anEstimatedFeedingCountsAsADilutionOfThree() throws {
        // 100 g received: as if fed 1 : 1 : 1, not as "100 g kept, nothing added".
        let estimate = Feeding.estimate(date: t0, grams: 100)
        #expect(StarterModel.dilution(of: estimate) == 3)
        #expect(StarterModel.assumedDilution == 3)
        // Wheat at 22 °C: log2(3) × 3 h ≈ 4.755 h to the peak, hungry at
        // 2.5 × 4.755 ≈ 11.9 h, neglected at 4 × ≈ 19 h: at 12 h it is hungry.
        let starter = Starter(name: "W", flour: .wheat, createdAt: t0, feedings: [estimate],
                              inFridge: false, origin: .existing)
        let status = try #require(starter.status(at: t0.addingTimeInterval(12 * 3600)))
        #expect(abs(status.peakHours - 4.755) < 1e-3)
        #expect(status.state == .hungry)
    }

    @Test func theFirstMixCountsAsADilutionOfThree() {
        let first = Feeding(date: t0, starterGrams: 0, flourGrams: 50, waterGrams: 50)
        let third = Feeding(date: t0, starterGrams: 10, flourGrams: 10, waterGrams: 10)
        #expect(StarterModel.dilution(of: first) == 3)
        #expect(StarterModel.dilution(of: third) == 3)
    }

    @Test func moreFreshFoodMeansALongerWaitToThePeak() {
        let small = Feeding(date: t0, starterGrams: 10, flourGrams: 10, waterGrams: 10)   // × 3
        let large = Feeding(date: t0, starterGrams: 10, flourGrams: 50, waterGrams: 50)   // × 11
        #expect(StarterModel.peakHours(of: large, celsius: 22, flour: .wheat)
                > StarterModel.peakHours(of: small, celsius: 22, flour: .wheat))
    }

    @Test func datesFollowFromThePeak() throws {
        let status = try #require(wheat().status(at: t0))
        #expect(status.peakHours == 6)
        #expect(status.bestFrom == t0.addingTimeInterval(4.5 * 3600))
        #expect(status.bestUntil == t0.addingTimeInterval(9 * 3600))
        #expect(status.feedBy == t0.addingTimeInterval(15 * 3600))
    }

    @Test func datesStretchInTheFridge() throws {
        // 12 °C: peak after 18 h, feed by 2.5 × 18 = 45 h.
        let status = try #require(wheat(inFridge: true, celsius: 12).status(at: t0))
        #expect(status.feedBy == t0.addingTimeInterval(45 * 3600))
    }

    @Test(arguments: [
        (0.0, StarterState.rising), (4.4, .rising), (4.5, .peak), (8.9, .peak),
        (9.0, .pastPeak), (14.9, .pastPeak), (15.0, .hungry), (23.9, .hungry),
        (24.0, .neglected), (500.0, .neglected),
    ])
    func stateAtTheHour(hours: Double, expected: StarterState) throws {
        let status = try #require(wheat().status(at: t0.addingTimeInterval(hours * 3600)))
        #expect(status.state == expected)
        #expect(status.hoursSinceFeeding == hours)
    }

    @Test func theLatestFeedingCounts() throws {
        var starter = wheat()
        starter.feedings.append(Feeding(date: t0.addingTimeInterval(10 * 3600), starterGrams: 10,
                                        flourGrams: 15, waterGrams: 15))
        // 11 h after t0 is only 1 h after the latest feeding.
        let status = try #require(starter.status(at: t0.addingTimeInterval(11 * 3600)))
        #expect(status.state == .rising)
        #expect(status.hoursSinceFeeding == 1)
    }

    @Test func aFeedingInTheFutureIsTreatedAsJustFed() throws {
        let status = try #require(wheat(fedAt: t0.addingTimeInterval(3600)).status(at: t0))
        #expect(status.hoursSinceFeeding == 0)
        #expect(status.state == .rising)
    }

    @Test func noFeedingNoStatus() {
        #expect(Starter(name: "A", flour: .rye, createdAt: t0).status(at: t0) == nil)
    }

    @Test func noFreshFoodMeansNoTimeAtAll() throws {
        // Nothing added: dilution 1, no doublings, the peak is now and gone.
        let status = try #require(wheat(flour: 0, water: 0).status(at: t0))
        #expect(status.peakHours == 0)
        #expect(status.state == .neglected)
        #expect(status.feedBy == t0)
    }
}

// Expected values are worked out by hand from the rules of thumb in
// `StarterEstablishing`: at 22 °C the false rise from 2 days after mixing, the
// quiet phase from 3, stabilizing from 5, usually ready by 10, overdue from 14;
// every 10 °C colder three times as long.
struct StarterEstablishingTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private let day: TimeInterval = 86_400

    private func young(_ rises: [Rise?] = [], celsius: Double = 22, origin: StarterOrigin = .spontaneous) -> Starter {
        // The mix at t0, then one feeding a day with the observed rise.
        let mix = Feeding(date: t0, starterGrams: 0, flourGrams: 50, waterGrams: 50)
        let later = rises.enumerated().map { index, rise in
            Feeding(date: t0.addingTimeInterval(Double(index + 1) * day), starterGrams: 20,
                    flourGrams: 50, waterGrams: 50, rise: rise)
        }
        return Starter(name: "J", flour: .rye, createdAt: t0, feedings: [mix] + later, inFridge: false,
                       roomCelsius: celsius, origin: origin)
    }

    @Test func theConstantsAreTheRulesOfThumb() {
        #expect(StarterEstablishing.falseRiseDays == 2)
        #expect(StarterEstablishing.quietDays == 3)
        #expect(StarterEstablishing.stabilizingDays == 5)
        #expect(StarterEstablishing.usuallyReadyDays == 10)
        #expect(StarterEstablishing.overdueDays == 14)
        #expect(StarterEstablishing.feedingHours == 24)
        #expect(StarterEstablishing.doublingsToBeReady == 2)
        #expect(EstablishingPhase.allCases == [.fresh, .falseRise, .quiet, .stabilizing, .overdue])
    }

    @Test func theFactorIsThreeForEveryTenDegreesColder() {
        #expect(StarterEstablishing.factor(celsius: 22) == 1)
        #expect(abs(StarterEstablishing.factor(celsius: 12) - 3) < 1e-12)
        #expect(abs(StarterEstablishing.factor(celsius: 2) - 9) < 1e-12)
        #expect(abs(StarterEstablishing.factor(celsius: 32) - 1.0 / 3) < 1e-12)
    }

    @Test(arguments: [
        (0.0, EstablishingPhase.fresh), (1.9, .fresh), (2.0, .falseRise), (2.9, .falseRise),
        (3.0, .quiet), (4.9, .quiet), (5.0, .stabilizing), (13.9, .stabilizing), (14.0, .overdue), (40.0, .overdue),
    ])
    func phasesAtTwentyTwoDegrees(days: Double, expected: EstablishingPhase) {
        #expect(StarterEstablishing.phase(days: days, celsius: 22) == expected)
    }

    // 12 °C: factor 3, so the false rise from 2 × 3 = 6 days, the quiet phase
    // from 3 × 3 = 9, stabilizing from 5 × 3 = 15, overdue from 14 × 3 = 42.
    @Test(arguments: [
        (5.9, EstablishingPhase.fresh), (6.0, .falseRise), (8.9, .falseRise), (9.0, .quiet),
        (14.9, .quiet), (15.0, .stabilizing), (41.9, .stabilizing), (42.0, .overdue),
    ])
    func phasesAtTwelveDegrees(days: Double, expected: EstablishingPhase) {
        #expect(StarterEstablishing.phase(days: days, celsius: 12) == expected)
    }

    @Test func warmerItGoesFaster() {
        // 32 °C: factor 1/3, the false rise from 2/3 day: at 0.6 days not yet, at 0.7 it has begun.
        #expect(StarterEstablishing.phase(days: 0.6, celsius: 32) == .fresh)
        #expect(StarterEstablishing.phase(days: 0.7, celsius: 32) == .falseRise)
    }

    @Test func dayOneIsTheDayOfMixing() throws {
        let starter = young()
        #expect(try #require(starter.establishing(at: t0)).day == 1)
        #expect(try #require(starter.establishing(at: t0.addingTimeInterval(day - 60))).day == 1)
        #expect(try #require(starter.establishing(at: t0.addingTimeInterval(day))).day == 2)
        // Before the mix (a clock set back) it is still day 1.
        #expect(try #require(starter.establishing(at: t0.addingTimeInterval(-60))).day == 1)
    }

    @Test func dayFourWithOneDoubling() throws {
        // Fed after day 1 (some) and day 2 (doubled); 3.5 days after mixing.
        let starter = young([.some, .doubled])
        #expect(starter.isEstablishing)
        #expect(starter.readySince == nil)
        let now = t0.addingTimeInterval(3.5 * day)
        let status = try #require(starter.establishing(at: now))
        #expect(status.day == 4)
        #expect(status.phase == .quiet)
        #expect(status.doublingsInARow == 1)
        // The last feeding was at 2 days, so feed by 3 days.
        #expect(status.feedBy == t0.addingTimeInterval(3 * day))
        #expect(status.usuallyReadyBy == t0.addingTimeInterval(10 * day))
        // No estimate between feedings yet.
        #expect(starter.status(at: now) == nil)
        #expect(starter.condition(at: now) == .establishing(status))
    }

    @Test func colderItIsUsuallyReadyLater() throws {
        // 12 °C: 10 × 3 = 30 days.
        let status = try #require(young(celsius: 12).establishing(at: t0))
        #expect(abs(status.usuallyReadyBy.timeIntervalSince(t0) - 30 * day) < 1e-6)
    }

    @Test func readyAfterTwoDoublingsInARow() throws {
        let starter = young([.none, .doubled, .doubled])
        // The second doubling in a row was observed at the feeding after day 3.
        #expect(starter.readySince == t0.addingTimeInterval(3 * day))
        #expect(!starter.isEstablishing)
        let now = t0.addingTimeInterval(3.5 * day)
        #expect(starter.establishing(at: now) == nil)
        let status = try #require(starter.status(at: now))
        #expect(starter.condition(at: now) == .fed(status))
    }

    @Test func aRiseThatFallsShortStartsTheCountAgain() throws {
        let starter = young([.doubled, .some, .doubled])
        #expect(starter.isEstablishing)
        #expect(try #require(starter.establishing(at: t0.addingTimeInterval(3 * day))).doublingsInARow == 1)
        // Nothing doubled yet: none in a row.
        #expect(try #require(young([.some]).establishing(at: t0)).doublingsInARow == 0)
    }

    @Test func onceReadyItStaysReady() {
        // A weaker rise later does not send it back to the establishing phase.
        let starter = young([.doubled, .doubled, .none])
        #expect(starter.readySince == t0.addingTimeInterval(2 * day))
        #expect(!starter.isEstablishing)
    }

    @Test func feedingsCountByDateNotByPosition() {
        var starter = young([.doubled, .doubled])
        starter.feedings.reverse()
        #expect(starter.readySince == t0.addingTimeInterval(2 * day))
    }

    @Test func otherStartersHaveNoEstablishingPhase() {
        for origin in [StarterOrigin.existing, .inoculated] {
            let starter = young([.doubled, .doubled], origin: origin)
            #expect(starter.readySince == nil)
            #expect(!starter.isEstablishing)
            #expect(starter.establishing(at: t0) == nil)
        }
    }

    @Test func withoutFeedingsTheDeadlineCountsFromMixing() throws {
        let starter = Starter(name: "J", flour: .rye, createdAt: t0, inFridge: false, origin: .spontaneous)
        let status = try #require(starter.establishing(at: t0))
        #expect(status.feedBy == t0.addingTimeInterval(day))
        #expect(status.doublingsInARow == 0)
    }

    @Test func aStarterNeverFedHasNoCondition() {
        #expect(Starter(name: "A", flour: .rye, createdAt: t0).condition(at: t0) == .notFed)
        #expect(Starter(name: "A", flour: .rye, createdAt: t0, origin: .existing).condition(at: t0) == .notFed)
    }
}
