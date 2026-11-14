import Foundation
import Testing
@testable import SourdoughKit

// Expected values are worked out by hand, never taken from a program run.
// The minutes are those of the tips pages "Kneten" (hand and hook) and
// "Küchenmaschine" (blade), typed in from there.

private let hook = EquipmentItem(kind: .kneader, name: "Bosch")
private let blade = EquipmentItem(kind: .kneader, name: "Thermomix", kneadingTool: .blade)
private let wheat = FlourMix([.wheat550: 80, .wheat1050: 20])
private let spelt = FlourMix([.spelt1050: 70, .speltWholeGrain: 30])

struct KneadingTests {
    @Test func theWayFollowsTheTool() {
        #expect(Kneading.way(nil) == .hand)
        #expect(Kneading.way(hook) == .hook)
        #expect(Kneading.way(blade) == .blade)
        #expect(Kneading.Way.allCases == [.hand, .hook, .blade])
        #expect(Kneading.Gluten.allCases == [.wheat, .spelt])
    }

    @Test func wheatTakesItsTimeByHandAndWithAHook() {
        let hand = Kneading(kneader: nil, mix: wheat)
        #expect(hand.way == .hand && hand.gluten == .wheat && !hand.mixOnly)
        #expect(hand.minutes == 10...15)
        #expect(Kneading(kneader: hook, mix: wheat).minutes == 8...12)
        #expect(!hand.isDelicate)
    }

    @Test func speltKneadsAboutHalfAsLong() {
        #expect(Kneading(kneader: nil, mix: spelt).minutes == 5...8)
        #expect(Kneading(kneader: hook, mix: spelt).minutes == 4...6)
        #expect(Kneading(kneader: hook, mix: spelt).gluten == .spelt)
        #expect(!Kneading(kneader: hook, mix: spelt).isDelicate)
    }

    @Test func aBladeTakesOnlyMinutesAndSpeltWithItIsDelicate() {
        #expect(Kneading(kneader: blade, mix: wheat).minutes == 2...3)
        #expect(!Kneading(kneader: blade, mix: wheat).isDelicate)
        let delicate = Kneading(kneader: blade, mix: spelt)
        #expect(delicate.minutes == 1...2)
        #expect(delicate.isDelicate)
    }

    @Test func speltCarriesTheDoughOnlyWhenThereIsMoreOfItThanWheat() {
        // 50 wheat against 50 spelt: not more spelt, so wheat.
        let even = FlourMix([.wheat550: 50, .spelt630: 50])
        #expect(Kneading(kneader: nil, mix: even).gluten == .wheat)
        // Buckwheat-spelt bread: 75 spelt, no wheat.
        #expect(Kneading(kneader: nil, mix: BreadType.buckwheatSpeltBread.preset).gluten == .spelt)
    }

    @Test func fromThirtyPercentRyeTheShortEndOfTheRange() {
        // Wheat mixed bread, 30 % rye: hook 8–12 becomes 8.
        let mixed = Kneading(kneader: hook, mix: BreadType.wheatMixedBread.preset)
        #expect(mixed.minutes == 8...8)
        #expect(!mixed.mixOnly)
        // 29 % rye still gets the whole range.
        let below = FlourMix([.wheat550: 71, .rye1150: 29])
        #expect(Kneading(kneader: hook, mix: below).minutes == 8...12)
    }

    @Test func fromFiftyPercentRyeTheDoughIsOnlyMixed() {
        // Rye mixed bread 50: 25 + 25 rye.
        let rye = Kneading(kneader: blade, mix: BreadType.ryeMixedBread50.preset)
        #expect(rye.mixOnly)
        #expect(rye.minutes == nil)
        // Its 50 spelt against no wheat would be delicate, but mixing is not kneading.
        #expect(rye.gluten == .spelt)
        #expect(!rye.isDelicate)
        #expect(Kneading(kneader: nil, mix: FlourMix([.rye1150: 49, .wheat550: 51])).mixOnly == false)
    }

    @Test func bothKneadingStepsLinkToTheMachinePage() {
        for text in [BakeProcess.Text.kneadFold, .kneadRye] {
            #expect(BakeProcess.markdown(text).contains("[Küchenmaschine](tip:kneader)"))
        }
    }

    @Test func theRangesOfAllWays() {
        #expect(Kneading.minutes(.hand, .wheat) == 10...15)
        #expect(Kneading.minutes(.hand, .spelt) == 5...8)
        #expect(Kneading.minutes(.hook, .wheat) == 8...12)
        #expect(Kneading.minutes(.hook, .spelt) == 4...6)
        #expect(Kneading.minutes(.blade, .wheat) == 2...3)
        #expect(Kneading.minutes(.blade, .spelt) == 1...2)
    }
}

struct KneaderCapacityTests {
    @Test func theBowlGivesFourHundredGramsPerLitre() {
        // 4.8 l × 0.4 kg/l = 1.92 kg.
        let mixer = EquipmentItem(kind: .kneader, name: "KitchenAid", bowlLiters: 4.8)
        #expect(abs(KneaderCapacity.maxDoughGrams(mixer)! - 1920) < 1e-9)
    }

    @Test func theMakersLimitWinsOverTheBowl() {
        // Kenwood kMix: 5 l bowl, 1350 g bread dough by the maker.
        let kMix = EquipmentItem(kind: .kneader, name: "kMix", bowlLiters: 5, maxDoughGrams: 1350)
        #expect(KneaderCapacity.maxDoughGrams(kMix) == 1350)
        #expect(KneaderCapacity.maxDoughGrams(EquipmentItem(kind: .kneader, name: "x", maxDoughGrams: 900)) == 900)
    }

    @Test func withoutBowlAndLimitNothingIsKnown() {
        #expect(KneaderCapacity.maxDoughGrams(hook) == nil)
    }

    @Test func aDoughOverTheLimitIsAnOverload() {
        let mixer = EquipmentItem(kind: .kneader, name: "KitchenAid", bowlLiters: 4.8)
        let setup = BakeSetup(vessel: .tray, kneader: mixer)
        // 2.3 kg against 1.92 kg.
        let overload = setup.kneaderOverload(doughGrams: 2300)
        #expect(overload?.kneader == mixer)
        #expect(overload?.doughGrams == 2300)
        #expect(abs((overload?.maxGrams ?? 0) - 1920) < 1e-9)
        #expect(overload?.isMakersLimit == false)
        // 1.9 kg fits.
        #expect(setup.kneaderOverload(doughGrams: 1900) == nil)
    }

    @Test func theMakersLimitIsNamedAsSuch() {
        let kMix = EquipmentItem(kind: .kneader, name: "kMix", bowlLiters: 5, maxDoughGrams: 1350)
        // 1.4 kg is over the maker's 1.35 kg, though the bowl alone would allow 2 kg.
        let overload = BakeSetup(vessel: .tray, kneader: kMix).kneaderOverload(doughGrams: 1400)
        #expect(overload?.isMakersLimit == true)
        #expect(overload?.maxGrams == 1350)
    }

    @Test func byHandOrWithoutALimitThereIsNoOverload() {
        #expect(BakeSetup(vessel: .tray).kneaderOverload(doughGrams: 5000) == nil)
        #expect(BakeSetup(vessel: .tray, kneader: hook).kneaderOverload(doughGrams: 5000) == nil)
    }
}

struct RecipeDoughTests {
    @Test func theDoughIsAllThatGoesIntoTheBowl() {
        // 1000 g wheat bread flour, hydration 0.8 × 66 + 0.2 × 72 = 67.2 %:
        // 1000 + 672 water + 20 salt = 1692 g, and the starter on top, 20 % of
        // the 200 g soured flour: 40 g. Together 1732 g.
        let recipe = Recipe(mix: wheat, totalGrams: 1000, starterFlour: .wheat)
        #expect(abs(recipe.doughGrams - 1732) < 1e-9)
    }

    @Test func addInsCountWithAllTheirWater() {
        // As above, with 15 % seeds (150 g), soaked in their own weight of
        // water (150 g): 1732 + 300 = 2032 g.
        var addIns = AddIns()
        addIns.add(.seeds)
        let recipe = Recipe(mix: wheat, totalGrams: 1000, starterFlour: .wheat, addIns: addIns)
        #expect(abs(recipe.doughGrams - 2032) < 1e-9)
    }
}
