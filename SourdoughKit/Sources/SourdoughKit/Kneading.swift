import Foundation

/// How long and how a dough is kneaded: by hand, with a hook or with a blade,
/// for the flour that carries it. Rules of thumb ("Richtwerte"), as on the
/// tips pages "Kneten" and "Küchenmaschine":
///
/// - The gluten that carries the dough is spelt if there is more spelt than
///   wheat, else wheat. Spelt's softer gluten takes about half the time.
/// - Minutes by hand and with a hook are those of the page "Kneten" (wheat
///   10–15 and 8–12, spelt 5–8 and 4–6). A hook kneads on a low speed.
/// - A blade in dough mode (Thermomix, Monsieur Cuisine) kneads in a few
///   minutes; longer runs overknead and warm the dough. Wheat 2–3 minutes,
///   spelt 1–2 and rather too short. Derived from the recipes of such
///   machines (VB-005), not measured.
/// - From `shorterFromRye` rye on the dough is kneaded somewhat shorter: the
///   lower end of the range. From `BakeRules.freeStandingRyeMax` it is only
///   mixed, as in the step "Hauptteig mischen".
public struct Kneading: Equatable, Sendable {
    public enum Way: String, CaseIterable, Sendable {
        case hand, hook, blade
    }

    /// The gluten that carries the dough.
    public enum Gluten: String, CaseIterable, Sendable {
        case wheat, spelt
    }

    /// From this rye share on, the dough is kneaded at the short end of the range.
    public static let shorterFromRye = 30.0

    public let way: Way
    public let gluten: Gluten
    /// Only mixed, not kneaded: rye from `BakeRules.freeStandingRyeMax`.
    public let mixOnly: Bool
    /// The minutes to knead; `nil` when the dough is only mixed.
    public let minutes: ClosedRange<Double>?

    /// Spelt with a blade: the case to stop rather too early.
    public var isDelicate: Bool { way == .blade && gluten == .spelt && !mixOnly }

    /// The minutes for kneading `gluten` the `way`, before any rye shortens them.
    public static func minutes(_ way: Way, _ gluten: Gluten) -> ClosedRange<Double> {
        switch (way, gluten) {
        case (.hand, .wheat): 10...15
        case (.hand, .spelt): 5...8
        case (.hook, .wheat): 8...12
        case (.hook, .spelt): 4...6
        case (.blade, .wheat): 2...3
        case (.blade, .spelt): 1...2
        }
    }

    /// The way of kneading with `kneader`; `nil` is by hand.
    public static func way(_ kneader: EquipmentItem?) -> Way {
        guard let kneader else { return .hand }
        return switch kneader.kneadingTool {
        case .hook: .hook
        case .blade: .blade
        }
    }

    /// Kneading `mix` with `kneader` (`nil`: by hand).
    public init(kneader: EquipmentItem?, mix: FlourMix) {
        way = Self.way(kneader)
        gluten = mix.share(of: .spelt) > mix.share(of: .wheat) ? .spelt : .wheat
        let rye = mix.ryeShare
        // The same comparison as the choice of the step text in `BakeProcess`.
        mixOnly = rye >= BakeRules.freeStandingRyeMax
        if mixOnly {
            minutes = nil
        } else {
            let range = Self.minutes(way, gluten)
            minutes = rye >= Self.shorterFromRye ? range.lowerBound...range.lowerBound : range
        }
    }
}

/// How much dough a kneading machine takes.
public enum KneaderCapacity {
    /// Dough per litre of bowl, a cautious rule of thumb ("Richtwert"): makers
    /// and test sites name 0.27 to 0.59 kg of bread dough per litre (VB-005),
    /// most of them about 0.45; and a dough that rests in the bowl doubles,
    /// which needs about 2 l per kg.
    public static let gramsPerBowlLiter = 400.0

    /// The most dough `kneader` takes: what its maker says, else the bowl
    /// times `gramsPerBowlLiter`; `nil` if neither is known.
    public static func maxDoughGrams(_ kneader: EquipmentItem) -> Double? {
        if let grams = kneader.maxDoughGrams { return grams }
        return kneader.bowlLiters.map { $0 * gramsPerBowlLiter }
    }
}

/// A dough too large for the kneading machine: a hint, not a block.
public struct KneaderOverload: Equatable, Sendable {
    public let kneader: EquipmentItem
    public let doughGrams: Double
    public let maxGrams: Double

    /// Whether the limit is the maker's, not the estimate from the bowl.
    public var isMakersLimit: Bool { kneader.maxDoughGrams != nil }
}

extension BakeSetup {
    /// The overload of the kneading machine by `doughGrams` of dough; `nil`
    /// when kneading by hand, without a known limit, or when the dough fits.
    public func kneaderOverload(doughGrams: Double) -> KneaderOverload? {
        guard let kneader, let max = KneaderCapacity.maxDoughGrams(kneader), doughGrams > max else { return nil }
        return KneaderOverload(kneader: kneader, doughGrams: doughGrams, maxGrams: max)
    }
}
