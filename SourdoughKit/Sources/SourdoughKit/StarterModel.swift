import Foundation

/// Where a starter stands between two feedings.
public enum StarterState: Equatable, Sendable {
    /// Still rising after the feeding.
    case rising
    /// At its peak: the best time to use it.
    case peak
    /// Past the peak, still fine.
    case pastPeak
    /// Hungry: feed or use it now.
    case hungry
    /// Fed so long ago that it needs refreshing first.
    case neglected
}

/// The state of a starter at one moment and the dates that follow from it.
public struct StarterStatus: Equatable, Sendable {
    public let state: StarterState
    public let hoursSinceFeeding: Double
    /// Hours from the feeding to the peak at the current temperature.
    public let peakHours: Double
    /// The best time to use the starter starts here …
    public let bestFrom: Date
    /// … and ends here.
    public let bestUntil: Date
    /// Feed or use the starter by this date at the latest.
    public let feedBy: Date
}

/// A rule-of-thumb model of how fast a starter ripens. It is an estimate, not
/// a measurement: real starters differ with flour, water, culture and kitchen.
///
/// - After a feeding the culture has to multiply until it is as dense as before.
///   Feeding `starter + flour + water` grams from `starter` grams dilutes it by
///   `(starter + flour + water) / starter`, which takes `log2(dilution)`
///   doublings.
/// - One doubling takes 3 hours at 22 °C for wheat; flour scales that
///   (`FlourType.timeFactor`).
/// - Every 10 °C colder it takes 3 times as long (Q10 = 3).
/// - The peak is reached after `doublings × doubling time`. The best window is
///   0.75 to 1.5 times that, the starter is hungry at 2.5 times and neglected
///   at 4 times.
public enum StarterModel {
    public static let referenceCelsius = 22.0
    public static let referenceDoublingHours = 3.0
    public static let q10 = 3.0
    /// Dilution assumed for the first mix, which has no starter to dilute.
    public static let freshBatchDilution = 3.0

    public static let peakStart = 0.75
    public static let peakEnd = 1.5
    public static let hungryAt = 2.5
    public static let neglectedAt = 4.0

    public static func doublingHours(celsius: Double, flour: FlourType) -> Double {
        referenceDoublingHours * flour.timeFactor * pow(q10, (referenceCelsius - celsius) / 10)
    }

    public static func dilution(of feeding: Feeding) -> Double {
        feeding.starterGrams > 0
            ? (feeding.starterGrams + feeding.flourGrams + feeding.waterGrams) / feeding.starterGrams
            : freshBatchDilution
    }

    public static func peakHours(of feeding: Feeding, celsius: Double, flour: FlourType) -> Double {
        log2(dilution(of: feeding)) * doublingHours(celsius: celsius, flour: flour)
    }
}

extension Starter {
    /// The state at `now`, based on the last feeding; `nil` if never fed.
    public func status(at now: Date) -> StarterStatus? {
        guard let last = lastFeeding else { return nil }
        let peak = StarterModel.peakHours(of: last, celsius: celsius, flour: flour)
        let hours = max(0, now.timeIntervalSince(last.date) / 3600)
        let state: StarterState =
            hours >= peak * StarterModel.neglectedAt ? .neglected
            : hours >= peak * StarterModel.hungryAt ? .hungry
            : hours >= peak * StarterModel.peakEnd ? .pastPeak
            : hours >= peak * StarterModel.peakStart ? .peak
            : .rising
        func date(_ factor: Double) -> Date { last.date.addingTimeInterval(peak * factor * 3600) }
        return StarterStatus(state: state, hoursSinceFeeding: hours, peakHours: peak,
                             bestFrom: date(StarterModel.peakStart),
                             bestUntil: date(StarterModel.peakEnd),
                             feedBy: date(StarterModel.hungryAt))
    }
}
