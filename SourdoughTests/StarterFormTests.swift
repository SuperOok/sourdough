import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

struct NumberInputTests {
    @Test(arguments: [("", 0.0), (" ", 0.0), ("12", 12.0), ("12,5", 12.5), ("12.5", 12.5), (" 7 ", 7.0)])
    func parsesValidInput(text: String, expected: Double) {
        #expect(NumberInput.parse(text) == expected)
    }

    @Test(arguments: ["abc", "1.2.3", "-5", "inf", "nan"])
    func rejectsInvalidInput(text: String) {
        #expect(NumberInput.parse(text) == nil)
    }
}

struct StarterFormModelTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    @Test func startsWithSensibleDefaults() {
        let model = StarterFormModel(now: now)
        #expect(model.flour == .rye)
        #expect(model.createdAt == now)
        #expect(model.flourText == "50")
        #expect(model.waterText == "50")
        #expect(model.inFridge)
        #expect(model.fridgeText == "5")
        #expect(model.roomText == "22")
        #expect(model.isValid)
        #expect(model.errorText == nil)
    }

    @Test func theNameDefaultsToTheFlourOfTheStarter() {
        let model = StarterFormModel(now: now)
        #expect(model.resolvedName == "Roggensauerteig")
        model.flour = .spelt
        #expect(model.resolvedName == "Dinkelsauerteig")
        model.name = "  Opas Starter  "
        #expect(model.resolvedName == "Opas Starter")
        model.name = "   "
        #expect(model.resolvedName == "Dinkelsauerteig")
    }

    @Test func fridgeTemperatureNeedsToBeFromZeroToFifteen() {
        #expect(StarterFormModel.parseFridge("0") == 0)
        #expect(StarterFormModel.parseFridge("15") == 15)
        #expect(StarterFormModel.parseFridge("4,5") == 4.5)
        #expect(StarterFormModel.parseFridge("15.1") == nil)
        #expect(StarterFormModel.parseFridge("-1") == nil)
        #expect(StarterFormModel.parseFridge("kalt") == nil)
    }

    @Test func rejectsTextInTheAmounts() {
        let model = StarterFormModel(now: now)
        model.flourText = "x"
        #expect(model.errorText == StarterFormModel.numbersOnly)
        model.flourText = "50"
        model.waterText = "y"
        #expect(model.errorText == StarterFormModel.numbersOnly)
        #expect(!model.isValid)
    }

    @Test func rejectsAFirstMixWithoutFood() {
        let model = StarterFormModel(now: now)
        model.flourText = "0"
        model.waterText = ""
        #expect(model.errorText == StarterFormModel.needsFood)
        model.waterText = "10"
        #expect(model.isValid)
    }

    @Test func checksTheFridgeTemperatureOnlyInTheFridge() {
        let model = StarterFormModel(now: now)
        model.fridgeText = "30"
        #expect(model.errorText == StarterFormModel.fridgeRange)
        model.inFridge = false
        #expect(model.errorText == nil)
    }

    @Test func checksTheRoomTemperatureOnlyOutsideTheFridge() {
        let model = StarterFormModel(now: now)
        model.roomText = "5"
        #expect(model.errorText == nil)
        model.inFridge = false
        #expect(model.errorText == StarterFormModel.roomRange)
    }

    @Test func eachMessageBelongsToItsSection() {
        let model = StarterFormModel(now: now)
        model.flourText = "0"
        model.waterText = "0"
        model.fridgeText = "30"
        #expect(model.foodError == StarterFormModel.needsFood)
        #expect(model.storageError == StarterFormModel.fridgeRange)
        // Saving waits for the first of them.
        #expect(model.errorText == StarterFormModel.needsFood)
        model.flourText = "10"
        #expect(model.foodError == nil)
        #expect(model.errorText == StarterFormModel.fridgeRange)
    }

    @Test func aCoolPlaceNeedsToBeFromEightToEighteen() {
        #expect(StarterFormModel.parseCool("8") == 8)
        #expect(StarterFormModel.parseCool("18") == 18)
        #expect(StarterFormModel.parseCool("12,5") == 12.5)
        #expect(StarterFormModel.parseCool("7.9") == nil)
        #expect(StarterFormModel.parseCool("18.1") == nil)
        #expect(StarterFormModel.parseCool("kühl") == nil)
    }

    @Test func roomTemperatureNeedsToBeFromTenToThirtyFive() {
        #expect(StarterFormModel.parseRoom("10") == 10)
        #expect(StarterFormModel.parseRoom("35") == 35)
        #expect(StarterFormModel.parseRoom("19,5") == 19.5)
        #expect(StarterFormModel.parseRoom("9.9") == nil)
        #expect(StarterFormModel.parseRoom("36") == nil)
        #expect(StarterFormModel.parseRoom("warm") == nil)
    }

    @Test func startsWithTheTemperaturesUsedLast() {
        let model = StarterFormModel(now: now, temperatures: Temperatures(roomCelsius: 19.5, fridgeCelsius: 4))
        #expect(model.roomText == "19,5")
        #expect(model.fridgeText == "4")
    }

    @Test func buildsTheStarterWithItsFirstFeeding() throws {
        let model = StarterFormModel(now: now)
        model.name = "Opa"
        model.flour = .wheat
        model.flourText = "40,5"
        model.waterText = "30"
        model.fridgeText = "7"
        let id = UUID()
        let starter = try #require(model.makeStarter(id: id))
        #expect(starter.id == id)
        #expect(starter.name == "Opa")
        #expect(starter.flour == .wheat)
        #expect(starter.createdAt == now)
        #expect(starter.inFridge)
        #expect(starter.fridgeCelsius == 7)
        #expect(starter.feedings.count == 1)
        let first = try #require(starter.feedings.first)
        #expect(first.date == now)
        #expect(first.starterGrams == 0)
        #expect(first.flourGrams == 40.5)
        #expect(first.waterGrams == 30)
    }

    @Test func aStarterAtRoomTemperatureKeepsTheDefaultFridgeValue() throws {
        let model = StarterFormModel(now: now)
        model.inFridge = false
        model.fridgeText = "kaputt"
        model.roomText = "19"
        let starter = try #require(model.makeStarter())
        #expect(!starter.inFridge)
        #expect(starter.fridgeCelsius == 5)
        #expect(starter.roomCelsius == 19)
    }

    @Test func aStarterInTheFridgeKeepsTheDefaultRoomValue() throws {
        let model = StarterFormModel(now: now)
        model.roomText = "kaputt"
        let starter = try #require(model.makeStarter())
        #expect(starter.roomCelsius == 22)
    }

    @Test func anInvalidFormMakesNoStarter() {
        let model = StarterFormModel(now: now)
        model.flourText = "x"
        #expect(model.makeStarter() == nil)
    }
}

struct FeedFormModelTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    @Test func startsWithTheAmountsOfTheLastFeeding() {
        let previous = Feeding(date: now, starterGrams: 30, flourGrams: 40, waterGrams: 12.5)
        let model = FeedFormModel(previous: previous, now: now)
        #expect(model.date == now)
        #expect(model.starterText == "30")
        #expect(model.flourText == "40")
        #expect(model.waterText == "12,5")
    }

    @Test func withoutAPreviousFeedingItUsesDefaults() {
        let model = FeedFormModel(previous: nil, now: now)
        #expect(model.starterText == "20")
        #expect(model.flourText == "50")
        #expect(model.waterText == "50")
    }

    @Test func theFirstMixHasNoStarterAmountToCopy() {
        let first = Feeding(date: now, starterGrams: 0, flourGrams: 60, waterGrams: 60)
        let model = FeedFormModel(previous: first, now: now)
        #expect(model.starterText == "20")
        #expect(model.flourText == "60")
    }

    @Test func validatesTheAmounts() {
        let model = FeedFormModel(previous: nil, now: now)
        #expect(model.isValid)
        model.starterText = "x"
        #expect(model.errorText == StarterFormModel.numbersOnly)
        model.starterText = "20"
        model.flourText = "x"
        #expect(model.errorText == StarterFormModel.numbersOnly)
        model.flourText = "50"
        model.waterText = "x"
        #expect(model.errorText == StarterFormModel.numbersOnly)
        model.flourText = "0"
        model.waterText = "0"
        #expect(model.errorText == StarterFormModel.needsFood)
        #expect(!model.isValid)
    }

    @Test func buildsTheFeeding() throws {
        let model = FeedFormModel(previous: nil, now: now)
        model.starterText = "10"
        model.flourText = "15"
        model.waterText = "15"
        let id = UUID()
        let feeding = try #require(model.makeFeeding(id: id))
        #expect(feeding == Feeding(id: id, date: now, starterGrams: 10, flourGrams: 15, waterGrams: 15))
    }

    @Test func anInvalidFormMakesNoFeeding() {
        let model = FeedFormModel(previous: nil, now: now)
        model.waterText = "?"
        #expect(model.makeFeeding() == nil)
    }
}

struct StarterDemoTests {
    private let now = Date(timeIntervalSince1970: 5_000_000)

    @Test func theDemoStartersAreInKnownStates() throws {
        let starters = StarterDemo.starters(now: now)
        #expect(starters.map(\.name) == ["Roggensauerteig", "Weizensauerteig"])
        #expect(starters.map(\.flour) == [.rye, .wheat])
        #expect(starters.map(\.inFridge) == [true, false])
        #expect(try #require(starters[0].status(at: now)).state == .rising)
        #expect(try #require(starters[1].status(at: now)).state == .neglected)
    }
}
