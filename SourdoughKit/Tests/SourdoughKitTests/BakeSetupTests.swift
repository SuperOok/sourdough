import Foundation
import Testing
@testable import SourdoughKit

// Expected values are worked out by hand, never taken from a program run.

private func close(_ a: Double, _ b: Double, _ eps: Double = 1e-9) -> Bool { abs(a - b) < eps }

private let kneader = EquipmentItem(kind: .kneader, name: "Bosch")
private let pot = EquipmentItem(kind: .pot, name: "Bräter",
                                dimensions: Dimensions(shape: .round, lengthCm: 27, heightCm: 7.5))
private let pan = EquipmentItem(kind: .pan, name: "Guss",
                                dimensions: Dimensions(shape: .rectangular, lengthCm: 27, widthCm: 10, heightCm: 11))
private let plainPan = EquipmentItem(kind: .pan, name: "Blechform")
private let basket = EquipmentItem(kind: .basket, name: "Körbchen")

struct BakeSetupTests {
    @Test func onlyTheLoafPanStandsInAForm() {
        #expect(BakeSetup.Vessel.allCases.map(\.isFreeStanding) == [false, true, true])
    }

    @Test func theVesselItemFollowsTheVessel() {
        #expect(BakeSetup(vessel: .loafPan, pan: pan, pot: pot).vesselItem == pan)
        #expect(BakeSetup(vessel: .pot, pan: pan, pot: pot).vesselItem == pot)
        #expect(BakeSetup(vessel: .tray, pan: pan, pot: pot).vesselItem == nil)
    }

    @Test func aPotIsProposedUpToFiftyPercentRye() {
        #expect(BakeSetup.proposal(for: [kneader, pan, pot, basket], ryeShare: 50)
                == BakeSetup(vessel: .pot, pot: pot, basket: basket, kneader: kneader))
    }

    @Test func moreRyeGoesIntoTheFirstLoafPan() {
        #expect(BakeSetup.proposal(for: [kneader, pan, plainPan, pot, basket], ryeShare: 70)
                == BakeSetup(vessel: .loafPan, pan: pan, kneader: kneader))
    }

    @Test func withoutAPotTheLoafPanIsProposed() {
        #expect(BakeSetup.proposal(for: [plainPan], ryeShare: 0) == BakeSetup(vessel: .loafPan, pan: plainPan))
    }

    @Test func withoutPotAndPanTheTrayAndTheBowlRemain() {
        #expect(BakeSetup.proposal(for: [], ryeShare: 0) == BakeSetup(vessel: .tray))
        #expect(BakeSetup.proposal(for: [basket], ryeShare: 80) == BakeSetup(vessel: .tray, basket: basket))
    }

    @Test func issues() {
        #expect(BakeSetup(vessel: .pot, pot: pot).issues(ryeShare: 50).isEmpty)
        #expect(BakeSetup(vessel: .pot, pot: pot).issues(ryeShare: 51) == [.tooMuchRyeToStandFree])
        #expect(BakeSetup(vessel: .tray).issues(ryeShare: 60) == [.tooMuchRyeToStandFree])
        #expect(BakeSetup(vessel: .loafPan, pan: pan).issues(ryeShare: 100).isEmpty)
        #expect(BakeSetup(vessel: .loafPan).issues(ryeShare: 0) == [.missingEquipment(.pan)])
        #expect(BakeSetup(vessel: .pot).issues(ryeShare: 0) == [.missingEquipment(.pot)])
    }

    @Test func survivesAJSONRoundTrip() throws {
        let setup = BakeSetup(vessel: .pot, pot: pot, basket: basket, kneader: kneader)
        let data = try JSONEncoder().encode(setup)
        #expect(try JSONDecoder().decode(BakeSetup.self, from: data) == setup)
    }
}

struct DoughAmountTests {
    @Test func aLoafPanTakesHalfAGramPerMillilitre() {
        // 27 × 10 × 11 = 2970 ml × 0.5 = 1485 g.
        #expect(DoughAmount.grams(for: BakeSetup(vessel: .loafPan, pan: pan)) == 1485)
    }

    @Test func aRoundPotOf27CentimetresTakesAKilo() {
        #expect(close(DoughAmount.grams(for: BakeSetup(vessel: .pot, pot: pot)), 1000))
    }

    @Test func otherPotsGoByTheirFloorArea() {
        // Round 24 cm: 1000 × 24² / 27² = 1000 × 576 / 729 = 790.123…
        let round24 = EquipmentItem(kind: .pot, name: "R", dimensions: Dimensions(shape: .round, lengthCm: 24, heightCm: 10))
        #expect(close(DoughAmount.grams(for: BakeSetup(vessel: .pot, pot: round24)), 790.1234568, 1e-6))
        // Oval 30 × 20: π/4 × 600 against π/4 × 729: 1000 × 600 / 729 = 823.045…
        let oval = EquipmentItem(kind: .pot, name: "O", dimensions: Dimensions(shape: .oval, lengthCm: 30, widthCm: 20, heightCm: 12))
        #expect(close(DoughAmount.grams(for: BakeSetup(vessel: .pot, pot: oval)), 823.0452675, 1e-6))
        // Rectangle 30 × 20 = 600 cm² against π/4 × 729 = 572.555 cm²: 1047.93…
        let box = EquipmentItem(kind: .pot, name: "B", dimensions: Dimensions(shape: .rectangular, lengthCm: 30, widthCm: 20, heightCm: 12))
        #expect(close(DoughAmount.grams(for: BakeSetup(vessel: .pot, pot: box)), 1047.93, 0.01))
    }

    @Test func withoutMeasurementsItIsAKilo() {
        #expect(DoughAmount.grams(for: BakeSetup(vessel: .loafPan, pan: plainPan)) == 1000)
        #expect(DoughAmount.grams(for: BakeSetup(vessel: .tray)) == 1000)
        #expect(DoughAmount.grams(for: BakeSetup(vessel: .loafPan)) == 1000)
    }

    @Test func flourFromDough() {
        // dough = flour × (1 + 0.816 + 0.02) = flour × 1.836: 1836 g → 1000 g,
        // 1485 g → 808.82… g.
        #expect(close(DoughAmount.flourGrams(doughGrams: 1836, hydration: 81.6), 1000))
        #expect(close(DoughAmount.flourGrams(doughGrams: 1485, hydration: 81.6), 808.8235294, 1e-6))
    }
}

struct RecipeTests {
    private func grams(_ portions: [Recipe.Portion]) -> [Flour: Double] {
        Dictionary(uniqueKeysWithValues: portions.map { ($0.flour, $0.grams) })
    }

    @Test func ryeBreadsSourAThirdOfTheRyeFromTheDarkestFirst() {
        // Roggenmischbrot 50, 825 g: rye 412.5 g, 35 % of it = 144.375 g, all
        // from rye whole grain (206.25 g). Water 81.6 % = 673.2 g, of which
        // 144.375 g in the sourdough: 528.825 g. Starter 20 % = 28.875 g. Salt 16.5 g.
        let recipe = Recipe(mix: BreadType.ryeMixedBread50.preset, totalGrams: 825, starterFlour: .rye)
        #expect(recipe.sourdoughFlour.map(\.flour) == [.ryeWholeGrain])
        #expect(close(grams(recipe.sourdoughFlour)[.ryeWholeGrain]!, 144.375))
        #expect(close(recipe.sourdoughWater, 144.375))
        #expect(close(recipe.starterGrams, 28.875))
        #expect(close(recipe.sourdoughGrams, 317.625))
        #expect(recipe.mainFlour.map(\.flour) == [.rye1150, .ryeWholeGrain, .spelt1050, .speltWholeGrain])
        let main = grams(recipe.mainFlour)
        #expect(close(main[.rye1150]!, 206.25))
        #expect(close(main[.ryeWholeGrain]!, 61.875))
        #expect(close(main[.spelt1050]!, 247.5))
        #expect(close(main[.speltWholeGrain]!, 165))
        #expect(close(recipe.mainWater, 528.825))
        #expect(close(recipe.salt, 16.5))
    }

    @Test func whatTheDarkestCannotGiveComesFromTheNext() {
        // Rye 1150 40, whole grain 10, spelt 50, 1000 g: rye 500 g, soured
        // 175 g: 100 g whole grain, then 75 g rye 1150. Whole grain is used up.
        let mix = FlourMix([.rye1150: 40, .ryeWholeGrain: 10, .spelt1050: 50])
        let recipe = Recipe(mix: mix, totalGrams: 1000, starterFlour: .rye)
        #expect(recipe.sourdoughFlour.map(\.flour) == [.ryeWholeGrain, .rye1150])
        #expect(close(grams(recipe.sourdoughFlour)[.rye1150]!, 75))
        #expect(recipe.mainFlour.map(\.flour) == [.rye1150, .spelt1050])
        #expect(close(grams(recipe.mainFlour)[.rye1150]!, 325))
    }

    @Test func otherBreadsSourAFifthFromTheStartersGrain() {
        // Dinkelbrot, 1000 g, spelt starter: 200 g from spelt whole grain (300 g).
        let recipe = Recipe(mix: BreadType.speltBread.preset, totalGrams: 1000, starterFlour: .spelt)
        #expect(recipe.sourdoughFlour.map(\.flour) == [.speltWholeGrain])
        #expect(close(recipe.sourdoughWater, 200))
        #expect(close(grams(recipe.mainFlour)[.speltWholeGrain]!, 100))
        #expect(close(grams(recipe.mainFlour)[.spelt1050]!, 700))
        // Water 72.4 % = 724 g, 200 g of it in the sourdough.
        #expect(close(recipe.mainWater, 524))
        #expect(close(recipe.starterGrams, 40))
    }

    @Test func withoutFlourOfTheStartersGrainTheDarkestOthersAreSoured() {
        // Wheat 1050 80, rye 1150 20, spelt starter: 200 g, the darkest is rye
        // 1150 (85 g water per 100 g against 72), all 200 g of it.
        let recipe = Recipe(mix: FlourMix([.wheat1050: 80, .rye1150: 20]), totalGrams: 1000, starterFlour: .spelt)
        #expect(recipe.sourdoughFlour.map(\.flour) == [.rye1150])
        #expect(close(recipe.sourdoughWater, 200))
        #expect(recipe.mainFlour.map(\.flour) == [.wheat1050])
    }

    @Test func withoutAStarterTheDarkestFloursAreSoured() {
        // Dinkelbrot, no starter yet: spelt whole grain is the darkest anyway.
        let recipe = Recipe(mix: BreadType.speltBread.preset, totalGrams: 1000, starterFlour: nil)
        #expect(recipe.sourdoughFlour.map(\.flour) == [.speltWholeGrain])
    }
}
