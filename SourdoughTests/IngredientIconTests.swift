import SourdoughKit
import Testing
import UIKit
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
        let expected: [TipsTopic.ID: TipsGlyph] = [
            .kneader: .asset("KneaderIcon"), .pot: .asset("PotIcon"), .pan: .asset("PanOpenIcon"),
            .basket: .asset("BasketRoundIcon"),
            .starter: .asset("StarterJarIcon"), .starterFromScratch: .asset("StarterJarIcon"),
            .flours: .asset("FlourSackIcon"), .wheat: .asset("WheatIcon"), .rye: .asset("RyeIcon"),
            .spelt: .asset("SpeltIcon"), .buckwheat: .asset("BuckwheatIcon"),
            .seeds: .asset("SeedsIcon"), .nuts: .asset("NutsIcon"), .driedFruit: .asset("DriedFruitIcon"),
            .roastedOnions: .asset("RoastedOnionsIcon"), .herbs: .asset("HerbsIcon"),
            .kneading: .asset("KneadingIcon"), .proofing: .asset("ProofingIcon"),
            .freeStanding: .asset("FreeStandingIcon"),
            .temperature: .symbol("thermometer.medium"), .schedule: .asset("ScheduleIcon"),
            .start: .symbol("house"), .planFlours: .asset("FlourSackIcon"), .planSetup: .symbol("scalemass"),
            .planSchedule: .asset("ScheduleIcon"), .run: .asset("BreadIcon"), .log: .symbol("book"),
            .logDetail: .symbol("doc.text"),
            .equipmentList: .asset("PotIcon"), .starterNew: .asset("StarterJarIcon"),
            .starterFeed: .symbol("drop"),
        ]
        #expect(expected.count == TipsTopic.ID.allCases.count)
        for id in TipsTopic.ID.allCases {
            #expect(TipsIcon.glyph(id) == expected[id], "\(id.rawValue)")
        }
    }

    @Test func everyGlyphExistsAsAnAssetOrASystemSymbol() {
        for id in TipsTopic.ID.allCases {
            switch TipsIcon.glyph(id) {
            case .asset(let name): #expect(UIImage(named: name) != nil, "\(id.rawValue): \(name)")
            case .symbol(let name): #expect(UIImage(systemName: name) != nil, "\(id.rawValue): \(name)")
            }
        }
    }

    @Test func theIconOfAGrainPageIsTheIconOfItsFlours() {
        for flour in Flour.allCases {
            #expect(TipsIcon.glyph(TipsTopic.id(for: flour.grain)) == .asset(IngredientIcon.name(flour)))
        }
        for addIn in AddIn.allCases {
            #expect(TipsIcon.glyph(TipsTopic.id(for: addIn)) == .asset(IngredientIcon.name(addIn)))
        }
    }
}
