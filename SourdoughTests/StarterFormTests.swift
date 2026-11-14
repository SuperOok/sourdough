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
        #expect(NumberInput.grams(text) == 0)
    }

    @Test func gramsOfAValidField() {
        #expect(NumberInput.grams("12,5") == 12.5)
        #expect(NumberInput.grams("") == 0)
    }
}

struct StarterFormModelTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    @Test func startsWithSensibleDefaults() {
        let model = StarterFormModel(now: now)
        #expect(model.origin == .existing)
        #expect(model.flour == .rye)
        #expect(model.createdAt == now)
        #expect(model.lastFedAt == now)
        #expect(model.lastFeedingKnown)
        #expect(model.amountText == "50")
        #expect(model.sampleText == "20")
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
        model.origin = .spontaneous
        model.flourText = "x"
        #expect(model.errorText == StarterFormModel.numbersOnly)
        model.flourText = "50"
        model.waterText = "y"
        #expect(model.errorText == StarterFormModel.numbersOnly)
        #expect(!model.isValid)
    }

    @Test func rejectsAFirstMixWithoutFood() {
        let model = StarterFormModel(now: now)
        model.origin = .inoculated
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
        model.origin = .inoculated
        model.inFridge = true
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
        model.origin = .spontaneous
        model.inFridge = true
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
        #expect(starter.origin == .spontaneous)
        #expect(starter.isEstablishing)
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
        model.amountText = "x"
        #expect(model.makeStarter() == nil)
    }

    @Test func anExistingStarterGetsAnEstimatedLastFeeding() throws {
        let model = StarterFormModel(now: now)
        model.lastFedAt = now - 3600
        model.amountText = "120"
        // A fresh mix's fields do not count for an existing starter.
        model.flourText = "x"
        #expect(model.isValid)
        let starter = try #require(model.makeStarter())
        #expect(starter.origin == .existing)
        // It is "bei dir" from now on, whenever it was first mixed.
        #expect(starter.createdAt == now)
        #expect(starter.feedings == [Feeding.estimate(id: starter.feedings[0].id, date: now - 3600, grams: 120)])
    }

    @Test func anExistingStarterWithoutAKnownFeedingHasNone() throws {
        let model = StarterFormModel(now: now)
        model.lastFeedingKnown = false
        // The amount is not asked then.
        model.amountText = "0"
        #expect(model.amountError == nil)
        let starter = try #require(model.makeStarter())
        #expect(starter.feedings.isEmpty)
        #expect(starter.condition(at: now) == .notFed)
    }

    @Test func anExistingStarterNeedsAnAmount() {
        let model = StarterFormModel(now: now)
        model.amountText = "0"
        #expect(model.errorText == StarterFormModel.needsAmount)
        model.amountText = "abc"
        #expect(model.errorText == StarterFormModel.numbersOnly)
        model.amountText = "80"
        #expect(model.amountError == nil)
        // The other ways ask no amount.
        model.amountText = "0"
        model.origin = .inoculated
        #expect(model.amountError == nil)
    }

    @Test func anInoculatedMixKeepsTheSampleAsItsStarter() throws {
        let model = StarterFormModel(now: now)
        model.origin = .inoculated
        model.createdAt = now - 600
        model.sampleText = "15"
        model.flourText = "45"
        model.waterText = "45"
        let starter = try #require(model.makeStarter())
        #expect(starter.origin == .inoculated)
        #expect(starter.createdAt == now - 600)
        let first = try #require(starter.feedings.first)
        #expect(first.starterGrams == 15)
        // The dilution follows from real numbers: (15 + 45 + 45) / 15 = 7.
        #expect(StarterModel.dilution(of: first) == 7)
        #expect(!first.isEstimate)
    }

    @Test func anInoculatedMixNeedsASample() {
        let model = StarterFormModel(now: now)
        model.origin = .inoculated
        model.sampleText = "0"
        #expect(model.errorText == StarterFormModel.needsSample)
        model.sampleText = "x"
        #expect(model.errorText == StarterFormModel.numbersOnly)
        // A spontaneous mix has no sample.
        model.origin = .spontaneous
        #expect(model.errorText == nil)
    }

    @Test func aSpontaneousMixStartsAtRoomTemperature() {
        let model = StarterFormModel(now: now)
        #expect(model.inFridge)
        model.origin = .spontaneous
        #expect(!model.inFridge)
        // Moving it to the fridge by hand stays possible.
        model.inFridge = true
        model.origin = .spontaneous
        #expect(!model.inFridge)
        model.inFridge = true
        model.origin = .inoculated
        #expect(model.inFridge)
    }

    @Test func aSpontaneousMixColderThanTwentyTwoDegreesGetsAHint() {
        let model = StarterFormModel(now: now)
        model.origin = .spontaneous
        #expect(model.coldHint == nil)          // 22 °C
        model.roomText = "21,5"
        #expect(model.coldHint == StarterFormModel.coldHint)
        model.roomText = "40"
        // A wrong temperature is an error, not a hint.
        #expect(model.coldHint == nil)
        model.inFridge = true                   // 5 °C
        #expect(model.coldHint == StarterFormModel.coldHint)
        // Only for a spontaneous mix.
        model.origin = .inoculated
        #expect(model.coldHint == nil)
    }

    @Test func theFieldsFollowTheWay() {
        let model = StarterFormModel(now: now)
        #expect(model.fields == ["add-amount", "add-fridge-temp"])
        model.lastFeedingKnown = false
        #expect(model.fields == ["add-fridge-temp"])
        model.origin = .inoculated
        #expect(model.fields == ["add-sample", "add-flour-grams", "add-water-grams", "add-fridge-temp"])
        model.origin = .spontaneous
        #expect(model.fields == ["add-flour-grams", "add-water-grams", "add-room-temp"])
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

    @Test func afterAnEstimateTheAmountReceivedIsTheKeptStarter() {
        let model = FeedFormModel(previous: Feeding.estimate(date: now, grams: 120), now: now)
        #expect(model.starterText == "120")
        // Flour and water of the estimate are unknown: the defaults.
        #expect(model.flourText == "50")
        #expect(model.waterText == "50")
    }

    @Test func inTheEstablishingPhaseTheRiseIsRequired() throws {
        let model = FeedFormModel(previous: nil, asksRise: true, now: now)
        #expect(model.rise == nil)
        #expect(model.errorText == FeedFormModel.needsRise)
        #expect(model.amountError == nil)
        #expect(model.makeFeeding() == nil)
        model.rise = .some
        #expect(model.isValid)
        #expect(try #require(model.makeFeeding()).rise == .some)
        // Wrong amounts come first.
        model.flourText = "0"
        model.waterText = "0"
        model.rise = nil
        #expect(model.errorText == StarterFormModel.needsFood)
    }

    @Test func outsideTheEstablishingPhaseNoRiseIsAsked() throws {
        let model = FeedFormModel(previous: nil, now: now)
        #expect(!model.asksRise)
        #expect(model.riseError == nil)
        model.rise = .doubled
        #expect(try #require(model.makeFeeding()).rise == nil)
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
        #expect(starters.map(\.name) == ["Roggensauerteig", "Weizensauerteig", "Junger Roggensauerteig"])
        #expect(starters.map(\.flour) == [.rye, .wheat, .rye])
        #expect(starters.map(\.inFridge) == [true, false, false])
        #expect(starters.map(\.origin) == [.inoculated, .inoculated, .spontaneous])
        #expect(try #require(starters[0].status(at: now)).state == .rising)
        #expect(try #require(starters[1].status(at: now)).state == .neglected)
        // Mixed 84 h = 3.5 days ago: day 4, the quiet phase (from 3 days at 22 °C),
        // one doubling at the last feeding 12 h ago, feed by 24 h after it.
        let young = try #require(starters[2].establishing(at: now))
        #expect(young.day == 4)
        #expect(young.phase == .quiet)
        #expect(young.doublingsInARow == 1)
        #expect(young.feedBy == now + 12 * 3600)
    }
}
