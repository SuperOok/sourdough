import Foundation
import Testing
@testable import SourdoughKit

struct AddInTests {
    @Test func everyAddInHasItsPresetWithinItsRange() {
        #expect(AddIn.allCases == [.seeds, .nuts, .driedFruit, .roastedOnions, .herbs])
        #expect(AddIn.allCases.map(\.presetShare) == [15, 15, 15, 8, 3])
        for addIn in AddIn.allCases {
            #expect(addIn.shareRange.contains(addIn.presetShare))
        }
        #expect(AddIn.allCases.map(\.shareRange) == [5...30, 5...30, 5...30, 2...15, 1...6])
    }

    @Test func waterSoakingAndWhenTheyGoIn() {
        #expect(AddIn.allCases.map(\.waterPerGram) == [1, 0, 0.5, 0.5, 0])
        #expect(AddIn.allCases.filter(\.soaks) == [.seeds, .driedFruit])
        #expect(AddIn.allCases.filter(\.goesInFirst) == [.seeds])
    }

    @Test func addingSettingAndRemoving() {
        var addIns = AddIns()
        #expect(addIns.isEmpty)
        #expect(addIns.addable == AddIn.allCases)
        addIns.add(.herbs)
        addIns.add(.seeds)
        #expect(addIns.addIns == [.seeds, .herbs])
        #expect(addIns.share(of: .seeds) == 15)
        #expect(addIns.addable == [.nuts, .driedFruit, .roastedOnions])
        // Adding again keeps the share; setting stays within the range.
        addIns.set(.seeds, to: 20)
        addIns.add(.seeds)
        #expect(addIns.share(of: .seeds) == 20)
        addIns.set(.seeds, to: 40)
        #expect(addIns.share(of: .seeds) == 30)
        addIns.set(.herbs, to: 0)
        #expect(addIns.share(of: .herbs) == 1)
        // Only add-ins in the dough have a share to set.
        addIns.set(.nuts, to: 10)
        #expect(addIns.share(of: .nuts) == 0)
        addIns.remove(.seeds)
        #expect(addIns.addIns == [.herbs])
    }

    @Test func theDoughWeighsTheAddInsAndTheirWater() {
        // Seeds 15 % with as much water: 0.15 × 2 = 0.30; herbs 3 % without: 0.03.
        let addIns = AddIns([.seeds: 15, .herbs: 3])
        #expect(abs(addIns.gramsPerFlourGram - 0.33) < 1e-9)
        #expect(AddIns().gramsPerFlourGram == 0)
    }

    @Test func addInsTakeTheirShareOfTheDough() {
        // 1000 g dough at 70 % water, 2 % salt and seeds 15 % with 15 % water:
        // flour × (1 + 0.70 + 0.02 + 0.30) = flour × 2.02, so 1000 / 2.02 = 495.05 g.
        let flour = DoughAmount.flourGrams(doughGrams: 1000, hydration: 70, addIns: AddIns([.seeds: 15]))
        #expect(abs(flour - 1000 / 2.02) < 1e-9)
        #expect(abs(flour - 495.05) < 0.01)
    }

    @Test func theRecipeListsTheAddInsAndSoaksSome() {
        // 500 g Weizen 550 (66 % water) with a wheat starter: 20 % soured is
        // 100 g, with 100 g water. Seeds 10 % = 50 g soak in 50 g water;
        // onions 8 % = 40 g take 20 g water in the main dough:
        // 500 × 0.66 − 100 + 20 = 250 g.
        let recipe = Recipe(mix: FlourMix([.wheat550: 100]), totalGrams: 500, starterFlour: .wheat,
                            addIns: AddIns([.roastedOnions: 8, .seeds: 10]))
        #expect(recipe.addIns == [
            Recipe.AddInPortion(addIn: .seeds, grams: 50, waterGrams: 50),
            Recipe.AddInPortion(addIn: .roastedOnions, grams: 40, waterGrams: 20),
        ])
        #expect(recipe.soaked.map(\.addIn) == [.seeds])
        #expect(abs(recipe.mainWater - 250) < 1e-9)
        // Without add-ins: 330 − 100 = 230 g.
        let plain = Recipe(mix: FlourMix([.wheat550: 100]), totalGrams: 500, starterFlour: .wheat)
        #expect(plain.addIns.isEmpty)
        #expect(abs(plain.mainWater - 230) < 1e-9)
    }
}
