import Foundation

/// The rounds of stretching and folding in the bulk rest: how many, how far
/// apart, and when. Rules of thumb ("Richtwerte") from the research in
/// `verbesserungen/VB-004.md`, confirmed for version 1.2:
///
/// - By the water of the dough (`FlourMix.hydration`): below `firmBelow`
///   2 rounds 45 minutes apart, up to `softAbove` 3 rounds, above it 4, both
///   30 minutes apart.
/// - A dough carried by spelt (more spelt than wheat) takes at most
///   `speltMax` rounds: its gluten takes less strain.
/// - From `fewerFromRye` rye one round fewer, and one fewer again after
///   kneading in a machine; at least one round either way.
/// - From `BakeRules.freeStandingRyeMax` rye there is no folding at all: the
///   dough is only mixed.
/// - The rounds start one interval after kneading and leave the last
///   `freeHoursAtEnd` of the bulk rest alone; rounds that do not fit drop
///   from the back.
///
/// In a bulk rest at a place cooler than the room the rounds come first, at
/// room temperature, and the dough goes to its place after the last one
/// (`ScheduleRules.nominalHours`).
public struct Folding: Codable, Equatable, Sendable {
    public static let firmBelow = 65.0
    public static let softAbove = 75.0
    public static let speltMax = 3
    public static let fewerFromRye = 20.0
    public static let freeHoursAtEnd = 1.0

    /// No folding.
    public static let none = Folding(rounds: 0, intervalMinutes: 30)

    /// The rounds as planned, before the rest says how many fit.
    public let rounds: Int
    public let intervalMinutes: Double

    public init(rounds: Int, intervalMinutes: Double) {
        self.rounds = rounds
        self.intervalMinutes = intervalMinutes
    }

    /// The folding of `mix`, kneaded with `kneader` (`nil`: by hand).
    public init(mix: FlourMix, kneader: EquipmentItem?) {
        let rye = mix.ryeShare
        let hydration = mix.hydration
        intervalMinutes = hydration < Self.firmBelow ? 45 : 30
        guard rye < BakeRules.freeStandingRyeMax else {
            rounds = 0
            return
        }
        var count = hydration < Self.firmBelow ? 2 : hydration <= Self.softAbove ? 3 : 4
        if mix.share(of: .spelt) > mix.share(of: .wheat) { count = min(count, Self.speltMax) }
        if rye >= Self.fewerFromRye { count -= 1 }
        if kneader != nil { count -= 1 }
        rounds = max(count, 1)
    }

    /// Hours from the start of the bulk rest to the last round: the time
    /// spent folding, which a cool bulk rest spends at room temperature.
    public var phaseHours: Double { Double(rounds) * intervalMinutes / 60 }

    /// Hours after the start of a bulk rest of `bulkHours` at which the
    /// rounds that leave its last `freeHoursAtEnd` alone begin.
    public func roundHours(bulkHours: Double) -> [Double] {
        guard rounds > 0 else { return [] }
        return (1...rounds).map { Double($0) * intervalMinutes / 60 }
            .filter { $0 <= bulkHours - Self.freeHoursAtEnd + 1e-9 }
    }
}
