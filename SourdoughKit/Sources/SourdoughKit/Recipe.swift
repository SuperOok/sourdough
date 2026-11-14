import Foundation

/// The amounts of a bake in grams: the sourdough stage and the main dough.
///
/// - With 30 % rye or more (`BakeRules.ryeStarterFrom`), 35 % of the rye is
///   soured, taken from the darkest rye flours first.
/// - Otherwise 20 % of all flour is soured, taken from the flours of the
///   starter's grain first, the darkest first, then from the darkest others.
/// - The sourdough stage has as much water as flour (100 %) and 20 % of its
///   flour as starter ("Anstellgut"). The starter is on top: it is small and
///   counts towards neither flour nor water.
/// - The main dough gets the rest of each flour and of the water, and the salt.
/// - Add-ins are percent of the flour. Those that soak (`AddIn.soaks`) do so
///   in their water from the time the sourdough is mixed; the water of the
///   others goes into the main dough.
public struct Recipe: Equatable, Sendable {
    public static let souredRyePercent = 35.0
    public static let souredFlourPercent = 20.0
    public static let starterPercent = 20.0

    public struct Portion: Equatable, Sendable {
        public let flour: Flour
        public let grams: Double
    }

    /// An add-in in grams with the water it gets.
    public struct AddInPortion: Equatable, Sendable {
        public let addIn: AddIn
        public let grams: Double
        public let waterGrams: Double

        public init(addIn: AddIn, grams: Double, waterGrams: Double) {
            self.addIn = addIn
            self.grams = grams
            self.waterGrams = waterGrams
        }
    }

    public let sourdoughFlour: [Portion]
    public let starterGrams: Double
    public let mainFlour: [Portion]
    public let mainWater: Double
    public let salt: Double
    public let addIns: [AddInPortion]

    /// For `totalGrams` of flour mixed as `mix`, made with a starter of
    /// `starterFlour` (`nil`: not known yet), with `addIns`.
    public init(mix: FlourMix, totalGrams: Double, starterFlour: FlourType?, addIns: AddIns = AddIns()) {
        let candidates: [Flour]
        let soured: Double
        if mix.ryeShare >= BakeRules.ryeStarterFrom - FlourMix.tolerance {
            candidates = Self.darkestFirst(mix.flours.filter { $0.grain == .rye })
            soured = mix.ryeShare / 100 * totalGrams * Self.souredRyePercent / 100
        } else {
            let own = Self.darkestFirst(mix.flours.filter { $0.grain == starterFlour })
            candidates = own + Self.darkestFirst(mix.flours.filter { !own.contains($0) })
            soured = totalGrams * Self.souredFlourPercent / 100
        }
        var left = soured
        var taken: [Flour: Double] = [:]
        for flour in candidates where left > FlourMix.tolerance {
            let grams = min(left, mix.grams(of: flour, totalGrams: totalGrams))
            taken[flour] = grams
            left -= grams
        }
        sourdoughFlour = candidates.compactMap { flour in taken[flour].map { Portion(flour: flour, grams: $0) } }
        starterGrams = soured * Self.starterPercent / 100
        mainFlour = mix.flours.compactMap { flour in
            let grams = mix.grams(of: flour, totalGrams: totalGrams) - (taken[flour] ?? 0)
            return grams > FlourMix.tolerance ? Portion(flour: flour, grams: grams) : nil
        }
        self.addIns = addIns.addIns.map { addIn in
            let grams = totalGrams * addIns.share(of: addIn) / 100
            return AddInPortion(addIn: addIn, grams: grams, waterGrams: grams * addIn.waterPerGram)
        }
        let unsoaked = self.addIns.filter { !$0.addIn.soaks }.reduce(0) { $0 + $1.waterGrams }
        mainWater = totalGrams * mix.hydration / 100 - soured + unsoaked
        salt = totalGrams * DoughAmount.saltPercent / 100
    }

    /// The add-ins that soak ahead, with their water.
    public var soaked: [AddInPortion] { addIns.filter(\.addIn.soaks) }

    /// Flour of the sourdough stage, which is also its water.
    public var sourdoughWater: Double {
        sourdoughFlour.reduce(0) { $0 + $1.grams }
    }

    /// The whole sourdough stage: flour, water and starter.
    public var sourdoughGrams: Double {
        2 * sourdoughWater + starterGrams
    }

    /// The whole dough that goes into the bowl: the sourdough stage, the
    /// flour, water and salt of the main dough, and the add-ins with all
    /// their water.
    public var doughGrams: Double {
        sourdoughGrams + mainFlour.reduce(0) { $0 + $1.grams } + mainWater + salt
            + addIns.reduce(0) { $0 + $1.grams } + soaked.reduce(0) { $0 + $1.waterGrams }
    }

    private static func darkestFirst(_ flours: [Flour]) -> [Flour] {
        flours.sorted { $0.waterUptake > $1.waterUptake }
    }
}
