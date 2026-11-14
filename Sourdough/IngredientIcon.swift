import SwiftUI
import SourdoughKit

/// Which own icon (see `CustomIcon`) stands for a grain, a flour or an add-in.
/// A flour shows the ear of its grain: whole-grain flours look like the others.
enum IngredientIcon {
    static func name(_ grain: FlourType) -> String {
        switch grain {
        case .wheat: "WheatIcon"
        case .spelt: "SpeltIcon"
        case .rye: "RyeIcon"
        // Until a drawing of its own is approved: the seeds.
        case .buckwheat: "BuckwheatIcon"
        }
    }

    static func name(_ flour: Flour) -> String { name(flour.grain) }

    static func name(_ addIn: AddIn) -> String {
        switch addIn {
        case .seeds: "SeedsIcon"
        case .nuts: "NutsIcon"
        case .driedFruit: "DriedFruitIcon"
        case .roastedOnions: "RoastedOnionsIcon"
        case .herbs: "HerbsIcon"
        }
    }

    /// Every asset name this enum and `TipsIcon` can return.
    static let allNames = ["WheatIcon", "SpeltIcon", "RyeIcon", "SeedsIcon", "NutsIcon",
                           "DriedFruitIcon", "RoastedOnionsIcon", "HerbsIcon",
                           "FlourSackIcon", "StarterJarIcon",
                           "KneadingIcon", "ProofingIcon", "FreeStandingIcon", "BuckwheatIcon",
                           "ScheduleIcon"]
}

/// What stands in front of a page in the contents of the tips: an own icon
/// from the asset catalog or, where there is none, a system symbol.
enum TipsGlyph: Equatable {
    case asset(String)
    case symbol(String)
}

/// The icon in front of a page in the contents of the tips.
enum TipsIcon {
    static func glyph(_ topic: TipsTopic.ID) -> TipsGlyph {
        switch topic {
        case .kneader: .asset(EquipmentIcon.name(for: .kneader))
        case .pot: .asset(EquipmentIcon.name(for: .pot))
        case .pan: .asset(EquipmentIcon.name(for: .pan))
        case .basket: .asset(EquipmentIcon.name(for: .basket))
        case .starter: .asset("StarterJarIcon")
        case .flours: .asset("FlourSackIcon")
        case .wheat: .asset(IngredientIcon.name(FlourType.wheat))
        case .rye: .asset(IngredientIcon.name(FlourType.rye))
        case .spelt: .asset(IngredientIcon.name(FlourType.spelt))
        case .buckwheat: .asset(IngredientIcon.name(FlourType.buckwheat))
        case .seeds: .asset(IngredientIcon.name(AddIn.seeds))
        case .nuts: .asset(IngredientIcon.name(AddIn.nuts))
        case .driedFruit: .asset(IngredientIcon.name(AddIn.driedFruit))
        case .roastedOnions: .asset(IngredientIcon.name(AddIn.roastedOnions))
        case .herbs: .asset(IngredientIcon.name(AddIn.herbs))
        // The proofing page borrows the dough, the free-standing page the loaf,
        // until drawings of their own are approved.
        case .kneading: .asset("KneadingIcon")
        case .proofing: .asset("ProofingIcon")
        case .freeStanding: .asset("FreeStandingIcon")
        case .temperature: .symbol("thermometer.medium")
        case .schedule: .asset("ScheduleIcon")
        // The pages about the screens of the app: the icons of their start
        // cards and the pages they belong to, plus system symbols. No drawings
        // of their own.
        case .start: .symbol("house")
        case .planFlours: .asset("FlourSackIcon")
        case .planSetup: .symbol("scalemass")
        case .planSchedule: .asset("ScheduleIcon")
        case .run: .asset("BreadIcon")
        case .log: .symbol("book")
        case .logDetail: .symbol("doc.text")
        case .equipmentList: .asset("PotIcon")
        case .starterNew, .starterCare: .asset("StarterJarIcon")
        case .starterFeed: .symbol("drop")
        }
    }
}

/// A `TipsGlyph` drawn at the size of the own icons.
struct TipsGlyphView: View {
    let glyph: TipsGlyph

    var body: some View {
        switch glyph {
        case .asset(let name):
            CustomIcon(name: name)
        case .symbol(let name):
            Image(systemName: name)
                .frame(width: 28, height: 28)
                // Decoration, like `CustomIcon`: the title beside it says what it is.
                .accessibilityHidden(true)
        }
    }
}
