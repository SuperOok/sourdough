import Foundation

/// The share of each flour in a dough, in percent of the total flour.
///
/// Changing one share moves the difference to the other flours, in this
/// order (see `setting(_:to:locked:)`):
///
/// 1. flours of the same grain that are in the mix, in proportion to their
///    shares, so that the rye share stays the same;
/// 2. when share is freed and no flour of the same grain is left: the
///    counterpart among wheat and spelt (`Flour.counterpart`), added if need be;
/// 3. all other flours in the mix, in proportion.
public struct FlourMix: Codable, Equatable, Sendable {
    /// Rough edges of floating point arithmetic; shares within this are equal.
    public static let tolerance = 1e-9

    /// Percent per flour; flours with no share are not stored.
    public private(set) var shares: [Flour: Double]

    public init(_ shares: [Flour: Double]) {
        self.shares = shares.filter { $0.value > Self.tolerance }
    }

    /// The share of `flour`; 0 if it is not in the mix.
    public func share(of flour: Flour) -> Double {
        shares[flour] ?? 0
    }

    /// The flours in the mix, in the order of `Flour.allCases`.
    public var flours: [Flour] {
        Flour.allCases.filter { shares[$0] != nil }
    }

    public var total: Double {
        shares.values.reduce(0, +)
    }

    /// Percent of rye flour of any type.
    public var ryeShare: Double {
        share(of: .rye)
    }

    /// Percent of flour of `grain`.
    public func share(of grain: FlourType) -> Double {
        shares.filter { $0.key.grain == grain }.values.reduce(0, +)
    }

    /// Percent of whole grain flour.
    public var wholeGrainShare: Double {
        shares.filter { $0.key.isWholeGrain }.values.reduce(0, +)
    }

    /// Water per 100 parts of flour, in percent: the water uptakes of the
    /// flours, weighted by their shares.
    public var hydration: Double {
        shares.reduce(0) { $0 + $1.value / 100 * $1.key.waterUptake }
    }

    /// Grams of each flour for `totalGrams` of flour.
    public func grams(of flour: Flour, totalGrams: Double) -> Double {
        share(of: flour) / 100 * totalGrams
    }

    /// The mix with `old` replaced by `new` at the same share.
    public func replacing(_ old: Flour, with new: Flour) -> FlourMix {
        guard old != new, let moved = shares[old] else { return self }
        var result = shares
        result[old] = nil
        result[new, default: 0] += moved
        return FlourMix(result)
    }

    /// The mix with `flour` at `target` percent (clamped to 0 … 100), the
    /// difference moved as described for the type. Flours in `locked` neither
    /// give nor take. If there is not enough to take, `flour` gets as much as
    /// there is; if there is nobody to take a freed share, nothing changes.
    public func setting(_ flour: Flour, to target: Double, locked: Set<Flour> = []) -> FlourMix {
        let current = share(of: flour)
        let target = min(100, max(0, target))
        var result = shares
        let others = flours.filter { $0 != flour && !locked.contains($0) }
        let sameGrain = others.filter { $0.grain == flour.grain }

        if target < current {
            let freed = current - target
            if !sameGrain.isEmpty {
                Self.add(freed, to: sameGrain, in: &result)
            } else if let counterpart = flour.counterpart, !locked.contains(counterpart) {
                result[counterpart, default: 0] += freed
            } else if !others.isEmpty {
                Self.add(freed, to: others, in: &result)
            } else {
                return self
            }
            result[flour] = target
        } else if target > current {
            var needed = target - current
            for donors in [sameGrain, others.filter { $0.grain != flour.grain }] {
                needed -= Self.take(needed, from: donors, in: &result)
            }
            result[flour] = target - needed
        }
        return FlourMix(result)
    }

    /// Adds `amount` to `flours` in proportion to their shares.
    private static func add(_ amount: Double, to flours: [Flour], in shares: inout [Flour: Double]) {
        let sum = flours.reduce(0) { $0 + shares[$1]! }
        for flour in flours {
            shares[flour]! += amount * shares[flour]! / sum
        }
    }

    /// Takes up to `amount` from `flours` in proportion to their shares and
    /// returns how much it took.
    private static func take(_ amount: Double, from flours: [Flour], in shares: inout [Flour: Double]) -> Double {
        let sum = flours.reduce(0) { $0 + shares[$1]! }
        let taken = min(amount, sum)
        guard taken > 0 else { return 0 }
        for flour in flours {
            shares[flour]! -= taken * shares[flour]! / sum
        }
        return taken
    }

    /// The mix with every flour of `limits` (grams per flour) cut down to its
    /// limit for `totalGrams` of flour; the rest goes to the other flours that
    /// have not reached their limit.
    public func limited(totalGrams: Double, limits: [Flour: Double]) -> FlourMix {
        guard totalGrams > 0 else { return self }
        var mix = self
        var locked = Set<Flour>()
        // Each round locks at least one more flour, so this ends.
        while let over = mix.flours.first(where: { flour in
            !locked.contains(flour) && limits[flour].map { mix.grams(of: flour, totalGrams: totalGrams) > $0 + Self.tolerance } == true
        }) {
            mix = mix.setting(over, to: limits[over]! / totalGrams * 100, locked: locked)
            locked.insert(over)
        }
        return mix
    }

    /// The flours over their limit in grams for `totalGrams` of flour.
    public func floursOverLimit(totalGrams: Double, limits: [Flour: Double]) -> [Flour] {
        flours.filter { flour in
            limits[flour].map { grams(of: flour, totalGrams: totalGrams) > $0 + 1e-6 } == true
        }
    }
}
