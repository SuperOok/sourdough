import Foundation

/// The kinds of bread a bake can start from, each with a preset flour mix.
/// The presets follow the table of the baking notes (`docs/`); "light" rye
/// and spelt are Rye 1150 and Spelt 1050 there. The wheat breads follow the
/// usual German names: a wheat bread is at least 90 % wheat, a wheat mixed
/// bread more than half wheat and the rest rye.
public enum BreadType: String, Codable, CaseIterable, Sendable {
    case wheatBread
    case wheatWholeGrainBread
    case wheatMixedBread
    case speltBread
    case speltMixedBread
    case ryeMixedBread50
    case ryeMixedBread70
    case ryeBread80
    case ryeWholeGrainBread
    case buckwheatRyeBread
    case buckwheatSpeltBread

    public var preset: FlourMix {
        switch self {
        case .wheatBread:
            FlourMix([.wheat550: 80, .wheat1050: 20])
        case .wheatWholeGrainBread:
            FlourMix([.wheatWholeGrain: 100])
        case .wheatMixedBread:
            FlourMix([.wheat550: 50, .wheat1050: 20, .rye1150: 30])
        case .speltBread:
            FlourMix([.spelt1050: 70, .speltWholeGrain: 30])
        case .speltMixedBread:
            FlourMix([.rye1150: 20, .ryeWholeGrain: 10, .spelt1050: 50, .speltWholeGrain: 20])
        case .ryeMixedBread50:
            FlourMix([.rye1150: 25, .ryeWholeGrain: 25, .spelt1050: 30, .speltWholeGrain: 20])
        case .ryeMixedBread70:
            FlourMix([.rye1150: 35, .ryeWholeGrain: 35, .spelt1050: 30])
        case .ryeBread80:
            FlourMix([.rye1150: 40, .ryeWholeGrain: 40, .spelt1050: 20])
        case .ryeWholeGrainBread:
            FlourMix([.rye1150: 20, .ryeWholeGrain: 80])
        case .buckwheatRyeBread:
            // Rye and buckwheat both have no gluten: a little spelt for structure.
            FlourMix([.rye1150: 45, .ryeWholeGrain: 25, .buckwheat: 20, .spelt1050: 10])
        case .buckwheatSpeltBread:
            // A quarter buckwheat in a dough that still has its gluten.
            FlourMix([.spelt1050: 50, .spelt630: 25, .buckwheat: 25])
        }
    }

    /// The rye share the bread type allows: the preset's, give or take
    /// `BakeRules.ryeTolerance`, within 0 … 100 %.
    public var ryeRange: ClosedRange<Double> {
        let rye = preset.ryeShare
        return max(0, rye - BakeRules.ryeTolerance)...min(100, rye + BakeRules.ryeTolerance)
    }
}

/// The rules a planned bake has to keep. Rules of thumb from the baking
/// notes, all in one place.
public enum BakeRules {
    /// How far the rye share may leave the bread type's preset, in percentage points.
    public static let ryeTolerance = 10.0
    /// From this rye share on, the dough needs a rye starter: only the acid of
    /// a rye sourdough keeps rye dough from turning gummy.
    public static let ryeStarterFrom = 30.0
    /// A free-standing loaf (banneton, bowl) holds its shape up to this rye
    /// share; above it, the dough belongs in a loaf pan.
    public static let freeStandingRyeMax = 50.0
    /// Buckwheat has no gluten and swells: above this share the crumb turns
    /// dense and gummy and the loaf loses volume.
    public static let buckwheatMax = 30.0

    /// Something about a planned bake that does not fit.
    public enum Issue: Equatable, Sendable {
        /// Less rye than the bread type allows.
        case tooLittleRye(minimum: Double)
        /// More rye than the bread type allows.
        case tooMuchRye(maximum: Double)
        /// The rye share needs a rye starter, and the chosen one is not.
        case needsRyeStarter
        /// More buckwheat than `buckwheatMax`.
        case tooMuchBuckwheat(maximum: Double)
        /// The flour is above its limit in grams and nothing could take its share.
        case overLimit(Flour)
        /// A free-standing loaf with more rye than `freeStandingRyeMax`.
        case tooMuchRyeToStandFree
        /// The chosen way of baking needs a piece of this kind, and none is chosen.
        case missingEquipment(EquipmentKind)
        /// The chosen starter is still in its establishing phase: it cannot
        /// raise a dough reliably yet.
        case starterEstablishing
    }

    /// Everything that does not fit about `mix` for `bread`, made with a
    /// starter of `starterFlour` (`nil`: none chosen yet), for `totalGrams` of
    /// flour with limits in grams per flour. `starterEstablishing`: the chosen
    /// starter is still in its establishing phase.
    public static func issues(mix: FlourMix, bread: BreadType, starterFlour: FlourType?,
                              starterEstablishing: Bool = false,
                              totalGrams: Double, limits: [Flour: Double]) -> [Issue] {
        var issues = ryeIssues(mix: mix, bread: bread) + buckwheatIssues(mix: mix)
        if let starterFlour, !suits(starterFlour, mix: mix) {
            issues.append(.needsRyeStarter)
        }
        if starterEstablishing { issues.append(.starterEstablishing) }
        issues += mix.floursOverLimit(totalGrams: totalGrams, limits: limits).map(Issue.overLimit)
        return issues
    }

    static func ryeIssues(mix: FlourMix, bread: BreadType) -> [Issue] {
        let range = bread.ryeRange
        let rye = mix.ryeShare
        if rye < range.lowerBound - FlourMix.tolerance { return [.tooLittleRye(minimum: range.lowerBound)] }
        if rye > range.upperBound + FlourMix.tolerance { return [.tooMuchRye(maximum: range.upperBound)] }
        return []
    }

    static func buckwheatIssues(mix: FlourMix) -> [Issue] {
        mix.share(of: Flour.buckwheat) > buckwheatMax + FlourMix.tolerance ? [.tooMuchBuckwheat(maximum: buckwheatMax)] : []
    }

    /// Whether a starter of `starterFlour` suits `mix`.
    public static func suits(_ starterFlour: FlourType, mix: FlourMix) -> Bool {
        starterFlour == .rye || mix.ryeShare < ryeStarterFrom - FlourMix.tolerance
    }

    /// The whole percentages `flour` can be set to (see
    /// `FlourMix.setting(_:to:locked:)`, then `FlourMix.limited`) without
    /// leaving the rye range of `bread` or a limit; `nil` if none.
    /// The starter is left out: it is a choice of its own.
    public static func range(of flour: Flour, in mix: FlourMix, bread: BreadType,
                             totalGrams: Double, limits: [Flour: Double]) -> ClosedRange<Double>? {
        let allowed = (0...100).map(Double.init).filter { percent in
            let candidate = mix.setting(flour, to: percent).limited(totalGrams: totalGrams, limits: limits)
            return abs(candidate.share(of: flour) - percent) < 1e-6
                && ryeIssues(mix: candidate, bread: bread).isEmpty
                && buckwheatIssues(mix: candidate).isEmpty
                && candidate.floursOverLimit(totalGrams: totalGrams, limits: limits).isEmpty
        }
        guard let low = allowed.first, let high = allowed.last else { return nil }
        return low...high
    }
}
