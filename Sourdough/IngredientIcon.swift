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

/// The icon in front of a page in the contents of the tips.
enum TipsIcon {
    static func name(_ topic: TipsTopic.ID) -> String {
        switch topic {
        case .kneader: EquipmentIcon.name(for: .kneader)
        case .pot: EquipmentIcon.name(for: .pot)
        case .pan: EquipmentIcon.name(for: .pan)
        case .basket: EquipmentIcon.name(for: .basket)
        case .starter: "StarterJarIcon"
        case .flours: "FlourSackIcon"
        case .wheat: IngredientIcon.name(FlourType.wheat)
        case .rye: IngredientIcon.name(FlourType.rye)
        case .spelt: IngredientIcon.name(FlourType.spelt)
        case .buckwheat: IngredientIcon.name(FlourType.buckwheat)
        case .seeds: IngredientIcon.name(AddIn.seeds)
        case .nuts: IngredientIcon.name(AddIn.nuts)
        case .driedFruit: IngredientIcon.name(AddIn.driedFruit)
        case .roastedOnions: IngredientIcon.name(AddIn.roastedOnions)
        case .herbs: IngredientIcon.name(AddIn.herbs)
        // The proofing page borrows the dough, the free-standing page the loaf,
        // until drawings of their own are approved.
        case .kneading: "KneadingIcon"
        case .proofing: "ProofingIcon"
        case .freeStanding: "FreeStandingIcon"
        // Temperature and time borrow the schedule's icon: `CustomIcon` draws
        // assets only, and a system symbol (`thermometer.medium`) would need a
        // change in `StartView.swift`.
        case .temperature, .schedule: "ScheduleIcon"
        }
    }
}
