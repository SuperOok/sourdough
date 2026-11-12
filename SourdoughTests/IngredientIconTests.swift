import SourdoughKit
import Testing
@testable import Sourdough

struct IngredientIconTests {
    @Test func eachGrainShowsItsEar() {
        #expect(FlourType.allCases.map(IngredientIcon.name(_:)) == ["RyeIcon", "WheatIcon", "SpeltIcon", "BuckwheatIcon"])
    }

    @Test func aFlourShowsTheEarOfItsGrain() {
        #expect(IngredientIcon.name(Flour.wheat550) == "WheatIcon")
        #expect(IngredientIcon.name(Flour.wheatWholeGrain) == "WheatIcon")
        #expect(IngredientIcon.name(Flour.spelt630) == "SpeltIcon")
        #expect(IngredientIcon.name(Flour.speltWholeGrain) == "SpeltIcon")
        #expect(IngredientIcon.name(Flour.rye1150) == "RyeIcon")
        #expect(IngredientIcon.name(Flour.ryeWholeGrain) == "RyeIcon")
    }

    @Test func eachAddInShowsItsOwnIcon() {
        #expect(AddIn.allCases.map(IngredientIcon.name(_:))
                == ["SeedsIcon", "NutsIcon", "DriedFruitIcon", "RoastedOnionsIcon", "HerbsIcon"])
    }

    @Test func everyTipsPageHasAnIconOfItsOwnKind() {
        let expected: [TipsTopic.ID: String] = [
            .kneader: "KneaderIcon", .pot: "PotIcon", .pan: "PanOpenIcon", .basket: "BasketRoundIcon",
            .starter: "StarterJarIcon",
            .flours: "FlourSackIcon", .wheat: "WheatIcon", .rye: "RyeIcon", .spelt: "SpeltIcon",
            .buckwheat: "BuckwheatIcon",
            .seeds: "SeedsIcon", .nuts: "NutsIcon", .driedFruit: "DriedFruitIcon",
            .roastedOnions: "RoastedOnionsIcon", .herbs: "HerbsIcon",
            .kneading: "KneadingIcon", .proofing: "ProofingIcon", .freeStanding: "FreeStandingIcon",
            .temperature: "ScheduleIcon", .schedule: "ScheduleIcon",
        ]
        #expect(expected.count == TipsTopic.ID.allCases.count)
        for id in TipsTopic.ID.allCases {
            #expect(TipsIcon.name(id) == expected[id], "\(id.rawValue)")
        }
    }

    @Test func theIconOfAGrainPageIsTheIconOfItsFlours() {
        for flour in Flour.allCases {
            #expect(TipsIcon.name(TipsTopic.id(for: flour.grain)) == IngredientIcon.name(flour))
        }
        for addIn in AddIn.allCases {
            #expect(TipsIcon.name(TipsTopic.id(for: addIn)) == IngredientIcon.name(addIn))
        }
    }
}
