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
                              feedings: [feeding(at: t0)], inFridge: false, fridgeCelsius: 7, roomCelsius: 19)
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
