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
    /// In the fridge: resting, fine to keep.
    case resting
    /// In the fridge: time to refresh it.
    case refreshRecommended
    /// In the fridge so long that it wants two refreshes before baking.
    case refreshTwice
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
    /// Feed or use the starter by this date at the latest; in the fridge,
    /// refresh it from this date on.
    public let feedBy: Date
    /// In the fridge: from this date on, refresh it twice before baking;
    /// `nil` at room temperature.
    public let refreshTwiceFrom: Date?
}

/// Rules of thumb for a starter in the fridge, all in one place. In the
/// fridge the question is not when it is best to use but when to refresh it.
/// From practice (VB-003, with sources): refreshing once a week is usual, and
/// a healthy starter keeps two to three weeks and then wants two refreshes
/// before baking.
///
/// - At 4 °C: refresh recommended from 7 days after the last feeding, refresh
///   twice before baking from 21 days.
/// - Warmer it is shorter, colder longer: 3 times per 10 °C (`StarterModel.q10`;
///   below 10 °C not measured). At 15 °C, the warmest fridge, refreshing comes
///   after ≈ 2.1 days, close to where the room-temperature model calls a
///   starter neglected, so the two rules meet.
/// - The amounts of the last feeding do not count: in the fridge it hardly
///   grows.
public enum StarterFridge {
    public static let referenceCelsius = 4.0
    public static let refreshDays = 7.0
    public static let refreshTwiceDays = 21.0

    /// How much longer than at 4 °C everything lasts at `celsius`.
    public static func factor(celsius: Double) -> Double {
        pow(StarterModel.q10, (referenceCelsius - celsius) / 10)
    }

    /// Hours from the last feeding to "refresh recommended" at `celsius`.
    public static func refreshHours(celsius: Double) -> Double {
        refreshDays * 24 * factor(celsius: celsius)
    }

    /// Hours from the last feeding to "refresh twice before baking" at `celsius`.
    public static func refreshTwiceHours(celsius: Double) -> Double {
        refreshTwiceDays * 24 * factor(celsius: celsius)
    }
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
/// - In the fridge the states are those of `StarterFridge` instead: resting,
///   refresh recommended, refresh twice before baking.
public enum StarterModel {
    public static let referenceCelsius = 22.0
    public static let referenceDoublingHours = 3.0
    public static let q10 = 3.0
    /// Dilution assumed for a feeding whose amounts say nothing about it: the
    /// first mix, which has no starter to dilute, and the estimated last
    /// feeding of a received starter (as if fed 1 : 1 : 1).
    public static let assumedDilution = 3.0

    public static let peakStart = 0.75
    public static let peakEnd = 1.5
    public static let hungryAt = 2.5
    public static let neglectedAt = 4.0

    public static func doublingHours(celsius: Double, flour: FlourType) -> Double {
        referenceDoublingHours * flour.timeFactor * pow(q10, (referenceCelsius - celsius) / 10)
    }

    public static func dilution(of feeding: Feeding) -> Double {
        feeding.starterGrams > 0 && !feeding.isEstimate
            ? (feeding.starterGrams + feeding.flourGrams + feeding.waterGrams) / feeding.starterGrams
            : assumedDilution
    }

    public static func peakHours(of feeding: Feeding, celsius: Double, flour: FlourType) -> Double {
        log2(dilution(of: feeding)) * doublingHours(celsius: celsius, flour: flour)
    }
}

extension Starter {
    /// The state at `now`, based on the last feeding; `nil` if never fed or
    /// still in the establishing phase.
    public func status(at now: Date) -> StarterStatus? {
        guard !isEstablishing, let last = lastFeeding else { return nil }
        let peak = StarterModel.peakHours(of: last, celsius: celsius, flour: flour)
        let hours = max(0, now.timeIntervalSince(last.date) / 3600)
        func date(_ factor: Double) -> Date { last.date.addingTimeInterval(peak * factor * 3600) }
        if inFridge {
            let refresh = StarterFridge.refreshHours(celsius: celsius)
            let twice = StarterFridge.refreshTwiceHours(celsius: celsius)
            let state: StarterState = hours >= twice ? .refreshTwice : hours >= refresh ? .refreshRecommended : .resting
            return StarterStatus(state: state, hoursSinceFeeding: hours, peakHours: peak,
                                 bestFrom: date(StarterModel.peakStart), bestUntil: date(StarterModel.peakEnd),
                                 feedBy: last.date.addingTimeInterval(refresh * 3600),
                                 refreshTwiceFrom: last.date.addingTimeInterval(twice * 3600))
        }
        let state: StarterState =
            hours >= peak * StarterModel.neglectedAt ? .neglected
            : hours >= peak * StarterModel.hungryAt ? .hungry
            : hours >= peak * StarterModel.peakEnd ? .pastPeak
            : hours >= peak * StarterModel.peakStart ? .peak
            : .rising
        return StarterStatus(state: state, hoursSinceFeeding: hours, peakHours: peak,
                             bestFrom: date(StarterModel.peakStart),
                             bestUntil: date(StarterModel.peakEnd),
                             feedBy: date(StarterModel.hungryAt), refreshTwiceFrom: nil)
    }
}

/// The phase a spontaneous starter is expected to be in, by days since it was
/// mixed (`StarterEstablishing`).
public enum EstablishingPhase: CaseIterable, Equatable, Sendable {
    /// Freshly mixed: little happens yet.
    case fresh
    /// The false rise: other bacteria bubble first; it cannot raise a dough yet.
    case falseRise
    /// The quiet phase: sour and nearly still while the pH falls.
    case quiet
    /// Lactic acid bacteria and yeasts take over; it begins to rise again.
    case stabilizing
    /// Longer than usual: time to look at the pitfalls.
    case overdue
}

/// Where a spontaneous starter stands in its establishing phase.
public struct EstablishingStatus: Equatable, Sendable {
    /// Day 1 is the day it was mixed.
    public let day: Int
    /// The phase expected at this age and temperature; only an expectation:
    /// ready is what the observations say.
    public let phase: EstablishingPhase
    /// Feedings in a row, up to the last, after which it had doubled.
    public let doublingsInARow: Int
    /// Feed it by then: once a day in this phase.
    public let feedBy: Date
    /// By then most starters are ready at this temperature.
    public let usuallyReadyBy: Date
}

/// Rules of thumb for the establishing phase of a spontaneous starter, all in
/// one place. They are not measured on real starters.
///
/// - At 22 °C the false rise is expected from day 2 after mixing, the quiet
///   phase from day 3, stabilizing from day 5; most starters are ready by
///   day 10, and from day 14 it takes longer than usual. These are days since
///   mixing, not day numbers (day 1 is the day of mixing).
/// - Colder, it all takes longer, as everywhere in the app: 3 times as long
///   every 10 °C colder (`StarterModel.q10`).
/// - It is fed once a day.
/// - It is ready after it doubled after two feedings in a row.
public enum StarterEstablishing {
    public static let falseRiseDays = 2.0
    public static let quietDays = 3.0
    public static let stabilizingDays = 5.0
    public static let usuallyReadyDays = 10.0
    public static let overdueDays = 14.0
    public static let feedingHours = 24.0
    public static let doublingsToBeReady = 2

    /// How much longer every phase takes at `celsius` than at 22 °C.
    public static func factor(celsius: Double) -> Double {
        pow(StarterModel.q10, (StarterModel.referenceCelsius - celsius) / 10)
    }

    /// The phase expected after `days` since mixing at `celsius`.
    public static func phase(days: Double, celsius: Double) -> EstablishingPhase {
        let reference = days / factor(celsius: celsius)
        return reference >= overdueDays ? .overdue
            : reference >= stabilizingDays ? .stabilizing
            : reference >= quietDays ? .quiet
            : reference >= falseRiseDays ? .falseRise
            : .fresh
    }
}

/// What can be said about a starter at one moment.
public enum StarterCondition: Equatable, Sendable {
    /// No feeding yet: nothing to estimate from.
    case notFed
    /// A spontaneous starter that is not ready yet.
    case establishing(EstablishingStatus)
    /// The estimate between two feedings.
    case fed(StarterStatus)
}

extension Starter {
    /// The feedings in the order they happened.
    private var feedingsByDate: [Feeding] {
        feedings.sorted { $0.date < $1.date }
    }

    /// The date of the second feeding in a row after which a spontaneous
    /// starter had doubled; `nil` until then and for other starters.
    public var readySince: Date? {
        guard origin == .spontaneous else { return nil }
        var inARow = 0
        for feeding in feedingsByDate {
            inARow = feeding.rise == .doubled ? inARow + 1 : 0
            if inARow == StarterEstablishing.doublingsToBeReady { return feeding.date }
        }
        return nil
    }

    /// A spontaneous starter that is not ready yet.
    public var isEstablishing: Bool {
        origin == .spontaneous && readySince == nil
    }

    /// The establishing phase at `now`; `nil` unless `isEstablishing`.
    public func establishing(at now: Date) -> EstablishingStatus? {
        guard isEstablishing else { return nil }
        let days = age(at: now) / 86_400
        let lastDate = lastFeeding?.date ?? createdAt
        let inARow = feedingsByDate.reversed().prefix { $0.rise == .doubled }.count
        let factor = StarterEstablishing.factor(celsius: celsius)
        return EstablishingStatus(
            day: Int(days) + 1,
            phase: StarterEstablishing.phase(days: days, celsius: celsius),
            doublingsInARow: inARow,
            feedBy: lastDate.addingTimeInterval(StarterEstablishing.feedingHours * 3600),
            usuallyReadyBy: createdAt.addingTimeInterval(StarterEstablishing.usuallyReadyDays * factor * 86_400))
    }

    /// What can be said about the starter at `now`.
    public func condition(at now: Date) -> StarterCondition {
        if let establishing = establishing(at: now) { return .establishing(establishing) }
        if let status = status(at: now) { return .fed(status) }
        return .notFed
    }
}
