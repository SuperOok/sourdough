import Foundation

/// Where the dough rests, and so how warm it is.
public enum Place: String, Codable, CaseIterable, Sendable {
    /// About 27 °C: the oven with only its lamp on, or a warm corner.
    case warm
    case room
    /// A cool spot between room and fridge: cellar, hallway, a windowsill in
    /// winter. Where it is and how cool is up to the user.
    case cool
    case fridge
}

/// The temperatures of the user's kitchen; warm is fixed.
public struct Temperatures: Codable, Equatable, Sendable {
    public static let warmCelsius = 27.0
    /// The dough should come out of kneading at about this temperature.
    public static let doughTargetCelsius = 26.0
    public static let defaultCoolCelsius = 16.0

    public var roomCelsius: Double
    public var fridgeCelsius: Double
    /// Temperature of the cool spot, if the user has one (`usesCoolPlace`).
    public var coolCelsius: Double
    /// Whether the plan may use a cool spot at all.
    public var usesCoolPlace: Bool

    public init(roomCelsius: Double = Starter.defaultRoomCelsius, fridgeCelsius: Double = 5,
                coolCelsius: Double = defaultCoolCelsius, usesCoolPlace: Bool = true) {
        self.roomCelsius = roomCelsius
        self.fridgeCelsius = fridgeCelsius
        self.coolCelsius = coolCelsius
        self.usesCoolPlace = usesCoolPlace
    }

    private enum CodingKeys: String, CodingKey {
        case roomCelsius, fridgeCelsius, coolCelsius, usesCoolPlace
    }

    /// Temperatures saved before there was a cool spot have none of its keys
    /// and get the defaults.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roomCelsius = try container.decode(Double.self, forKey: .roomCelsius)
        fridgeCelsius = try container.decode(Double.self, forKey: .fridgeCelsius)
        coolCelsius = try container.decodeIfPresent(Double.self, forKey: .coolCelsius) ?? Self.defaultCoolCelsius
        usesCoolPlace = try container.decodeIfPresent(Bool.self, forKey: .usesCoolPlace) ?? true
    }

    /// A cool spot only makes sense if it is cooler than the room.
    public var hasCoolPlace: Bool { usesCoolPlace && coolCelsius < roomCelsius }

    public func celsius(_ place: Place) -> Double {
        switch place {
        case .warm: Self.warmCelsius
        case .room: roomCelsius
        case .cool: coolCelsius
        case .fridge: fridgeCelsius
        }
    }

    /// The water temperature that brings the dough to `target`: flour and
    /// water weigh in about equally, so water = 2 × target − flour, where the
    /// flour has room temperature.
    public func waterCelsius(target: Double = doughTargetCelsius) -> Double {
        2 * target - roomCelsius
    }
}

/// The rests of a bake. The cooling at the end is no rest of the dough and
/// has its own rule (`ScheduleRules.coolingHours`).
public enum RestKind: String, Codable, CaseIterable, Sendable {
    /// The sourdough stage ripens.
    case sourdough
    /// The whole dough rises in the bowl ("Stockgare").
    case bulk
    /// The shaped loaf rises ("Stückgare").
    case proof

    /// The places this rest can take, the usual one first; the cool spot
    /// only if the kitchen has one.
    public func places(for temperatures: Temperatures) -> [Place] {
        let all: [Place] = switch self {
        case .sourdough, .bulk: [.room, .cool, .warm]
        case .proof: [.room, .cool, .fridge, .warm]
        }
        return all.filter { $0 != .cool || temperatures.hasCoolPlace }
    }

    /// Shortest and longest sensible time at `place`, as factors of the
    /// nominal time. Narrow on purpose: at the same temperature the dough
    /// ripens by the clock, so a much longer or shorter rest should come from
    /// another place (`ScheduleRules.place`), not from a wide range. The
    /// fridge is the exception: at 5 °C the dough is so slow that anything
    /// from about 7 to 15 hours does the same, which is how a proof is led
    /// over night.
    public func factorRange(at place: Place) -> ClosedRange<Double> {
        if place == .fridge { return 0.7...1.5 }
        return self == .sourdough ? 0.8...1.25 : 0.85...1.2
    }
}

/// A logarithmic scale from hours to a position between 0 and 1, for the bars
/// that show a sensible range of a rest. Equal factors take equal widths: a
/// rest that is three times as long is as far to the right whatever its
/// length, as in the rule that every 10 °C colder takes three times as long.
public struct RangeScale: Equatable, Sendable {
    /// The factor by which the scale reaches beyond the ranges it covers, at
    /// both ends.
    public static let margin = 1.15

    /// The hours at position 0 and at position 1; both above 0.
    public let lowerBound: Double
    public let upperBound: Double

    public init(lowerBound: Double, upperBound: Double) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    /// The scale that holds all of `ranges`, with `margin` on both ends.
    public init(covering ranges: [ClosedRange<Double>], margin: Double = Self.margin) {
        lowerBound = ranges.map(\.lowerBound).min()! / margin
        upperBound = ranges.map(\.upperBound).max()! * margin
    }

    /// Where `hours` lies: 0 at `lowerBound`, 1 at `upperBound`, in between
    /// by the logarithm; beyond the ends it stays at 0 or 1.
    public func position(of hours: Double) -> Double {
        let fraction = log(hours / lowerBound) / log(upperBound / lowerBound)
        return min(max(fraction, 0), 1)
    }
}

/// What the user does at the dough.
public enum ActionKind: String, Codable, CaseIterable, Sendable {
    case mixSourdough, knead, shape, preheat, bake
}

/// The rules of thumb for the times of a bake, all in one place. Like the
/// starter model they are estimates, not measurements.
///
/// A rest takes `referenceHours` at 22 °C and, as with the starter, three
/// times as long for every 10 °C colder (`StarterModel.q10`).
public enum ScheduleRules {
    public static let referenceCelsius = 22.0

    /// Hours at 22 °C. The bulk rest is shorter the more rye there is: rye
    /// has no gluten to develop.
    public static func referenceHours(_ rest: RestKind, ryeShare: Double) -> Double {
        switch rest {
        case .sourdough: 8
        case .bulk: 3 - 2.5 * ryeShare / 100
        case .proof: 1.5
        }
    }

    /// Hours of `rest` at `celsius`.
    public static func hours(_ rest: RestKind, ryeShare: Double, celsius: Double) -> Double {
        referenceHours(rest, ryeShare: ryeShare) * pow(StarterModel.q10, (referenceCelsius - celsius) / 10)
    }

    /// Shortest and longest sensible hours of `rest` at `place`.
    public static func range(_ rest: RestKind, ryeShare: Double, place: Place,
                             temperatures: Temperatures) -> ClosedRange<Double> {
        let nominal = hours(rest, ryeShare: ryeShare, celsius: temperatures.celsius(place))
        let factors = rest.factorRange(at: place)
        return nominal * factors.lowerBound...nominal * factors.upperBound
    }

    /// The temperature at which `rest` takes `hours`: the rule above turned
    /// around, `22 °C − 10 °C × log₃(hours / hours at 22 °C)`.
    public static func celsius(_ rest: RestKind, ryeShare: Double, hours: Double) -> Double {
        referenceCelsius - 10 * log(hours / referenceHours(rest, ryeShare: ryeShare)) / log(StarterModel.q10)
    }

    /// The scale for the range bars of `rest`: one for all its places, so that
    /// the coloured range moves when the place changes (`RangeScale`).
    public static func scale(_ rest: RestKind, ryeShare: Double, temperatures: Temperatures) -> RangeScale {
        RangeScale(covering: rest.places(for: temperatures).map {
            range(rest, ryeShare: ryeShare, place: $0, temperatures: temperatures)
        })
    }

    /// The place at which `hours` of `rest` is sensible: `current` if its
    /// range holds them, else the first place whose range does. If none does
    /// (the hours are shorter or longer than any place gives), the place whose
    /// nominal time is closest, measured as a ratio.
    public static func place(forHours hours: Double, rest: RestKind, ryeShare: Double,
                             temperatures: Temperatures, current: Place) -> Place {
        let places = rest.places(for: temperatures)
        func holds(_ place: Place) -> Bool {
            range(rest, ryeShare: ryeShare, place: place, temperatures: temperatures).contains(hours)
        }
        if places.contains(current), holds(current) { return current }
        if let fitting = places.first(where: holds) { return fitting }
        func distance(_ place: Place) -> Double {
            abs(log(hours / self.hours(rest, ryeShare: ryeShare, celsius: temperatures.celsius(place))))
        }
        return places.min { distance($0) < distance($1) }!
    }

    /// Minutes the user is busy.
    public static func minutes(_ action: ActionKind, vessel: BakeSetup.Vessel) -> Double {
        switch action {
        case .mixSourdough: 10
        case .knead: 20
        case .shape: 15
        case .preheat: 45
        case .bake:
            switch vessel {
            case .loafPan: 60
            case .pot: 50
            case .tray: 45
            }
        }
    }

    /// Hours the bread cools before it can be cut: more rye needs longer.
    public static func coolingHours(ryeShare: Double) -> Double {
        ryeShare < 50 ? 2 : ryeShare < 80 ? 6 : 24
    }
}

/// The hours of the day in which the user works at the dough.
public struct InteractionWindow: Codable, Equatable, Sendable {
    public var startHour: Int
    public var endHour: Int

    public init(startHour: Int = 8, endHour: Int = 21) {
        self.startHour = startHour
        self.endHour = endHour
    }

    /// Whether `start ... end` lies within the window of one day.
    public func contains(_ start: Date, _ end: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: start)
        return start >= time(startHour, of: day, calendar) && end <= time(endHour, of: day, calendar)
    }

    func time(_ hour: Int, of day: Date, _ calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    /// The `end` of an action of `length` seconds closest to `target`
    /// within `lowest ... highest`, so that the action lies in the window;
    /// `nil` if there is none.
    func closestEnd(to target: Date, length: TimeInterval, in lowest: Date, _ highest: Date,
                    calendar: Calendar) -> Date? {
        var best: Date?
        var day = calendar.startOfDay(for: lowest)
        while day <= highest {
            let from = max(lowest, time(startHour, of: day, calendar) + length)
            let to = min(highest, time(endHour, of: day, calendar))
            if from <= to {
                let candidate = min(max(target, from), to)
                if best.map({ abs(candidate.timeIntervalSince(target)) < abs($0.timeIntervalSince(target)) }) ?? true {
                    best = candidate
                }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return best
    }
}

/// A rest as the user fixed it: place and hours.
public struct RestChoice: Codable, Equatable, Sendable {
    public var place: Place
    public var hours: Double

    public init(place: Place, hours: Double) {
        self.place = place
        self.hours = hours
    }
}

/// Which end of a bake the user fixes: the time the bread can be cut
/// (`ready`; the plan goes backwards from it) or the time the sourdough is
/// mixed (`start`; the plan goes forwards and "ready" is its result).
public enum ScheduleAnchor: String, Codable, CaseIterable, Sendable {
    case ready
    case start
}

/// One entry of the timeline.
public struct ScheduleStep: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case action(ActionKind)
        case rest(RestKind, Place)
        case cooling
    }

    public let kind: Kind
    public let start: Date
    public let end: Date
    /// For a rest: the shortest and longest sensible hours at its place.
    public let hourRange: ClosedRange<Double>?
    /// An action outside the interaction window.
    public let outsideWindow: Bool
    /// For a rest: the temperature at which its planned hours match the rule
    /// (`ScheduleRules.celsius`), the one to aim for. At the nominal time it
    /// is the temperature of the place.
    public let celsius: Double?

    init(kind: Kind, start: Date, end: Date, hourRange: ClosedRange<Double>? = nil, outsideWindow: Bool = false,
         celsius: Double? = nil) {
        self.kind = kind
        self.start = start
        self.end = end
        self.hourRange = hourRange
        self.outsideWindow = outsideWindow
        self.celsius = celsius
    }

    public var hours: Double { end.timeIntervalSince(start) / 3600 }

    /// Where a rest takes place; `nil` for actions and cooling.
    public var place: Place? {
        if case .rest(_, let place) = kind { return place }
        return nil
    }
}

/// The timeline of a bake, planned backwards from the time the bread can be
/// cut or forwards from the time the sourdough is mixed (`ScheduleAnchor`).
///
/// Going back from the target: the bread cools at least
/// `ScheduleRules.coolingHours`, longer if that puts preheating and baking
/// into the interaction window. Then each rest, last first, takes the first
/// of its places (`RestKind.places`) at which a time within its range puts
/// the action before it into the window, the time closest to the nominal one.
/// If no place works, it takes the nominal time at the usual place and the
/// action is marked as outside the window. A rest in `choices` takes the
/// place and hours given there instead, clamped to the range.
///
/// Going forward from the start, each rest likewise takes the first place at
/// which a time within its range puts the action after it into the window
/// (after the proof: preheating and baking), and the bread cools exactly
/// `ScheduleRules.coolingHours`; a target in the night is no conflict. A
/// longer or shorter rest moves every step after it.
public struct Schedule: Equatable, Sendable {
    public let steps: [ScheduleStep]
    /// What the bread bakes in; it decides some step titles.
    public let vessel: BakeSetup.Vessel

    /// The rests, each with the action before it, in their order.
    private static let pairs: [(ActionKind, RestKind)] = [(.mixSourdough, .sourdough), (.knead, .bulk),
                                                            (.shape, .proof)]

    /// Plans backwards from `time` for `.ready`, forwards from it for `.start`.
    public init(anchor: ScheduleAnchor, time: Date, ryeShare: Double, vessel: BakeSetup.Vessel,
                temperatures: Temperatures, window: InteractionWindow = InteractionWindow(),
                choices: [RestKind: RestChoice] = [:], calendar: Calendar) {
        switch anchor {
        case .ready:
            self.init(target: time, ryeShare: ryeShare, vessel: vessel, temperatures: temperatures,
                      window: window, choices: choices, calendar: calendar)
        case .start:
            self.init(start: time, ryeShare: ryeShare, vessel: vessel, temperatures: temperatures,
                      window: window, choices: choices, calendar: calendar)
        }
    }

    /// The place and hours of `rest`, and whether the action next to it lies
    /// outside the window. That action (with preheating: the block of
    /// actions) takes `length` seconds and ends at `base` + `direction` ×
    /// hours: backwards the action before the rest, forwards the one after it.
    private static func place(_ rest: RestKind, ryeShare: Double, temperatures: Temperatures,
                              choice: RestChoice?, window: InteractionWindow, calendar: Calendar,
                              base: Date, direction: Double, length: TimeInterval)
    -> (place: Place, hours: Double, outside: Bool) {
        func blockEnd(_ hours: Double) -> Date { base + direction * hours * 3600 }
        func range(_ place: Place) -> ClosedRange<Double> {
            ScheduleRules.range(rest, ryeShare: ryeShare, place: place, temperatures: temperatures)
        }
        func nominal(_ place: Place) -> Double {
            ScheduleRules.hours(rest, ryeShare: ryeShare, celsius: temperatures.celsius(place))
        }
        let places = rest.places(for: temperatures)
        if let choice, places.contains(choice.place) {
            let hours = min(max(choice.hours, range(choice.place).lowerBound), range(choice.place).upperBound)
            let end = blockEnd(hours)
            return (choice.place, hours, !window.contains(end - length, end, calendar: calendar))
        }
        for place in places {
            let span = range(place)
            let bounds = [blockEnd(span.lowerBound), blockEnd(span.upperBound)].sorted()
            if let end = window.closestEnd(to: blockEnd(nominal(place)), length: length, in: bounds[0], bounds[1],
                                           calendar: calendar) {
                return (place, direction * end.timeIntervalSince(base) / 3600, false)
            }
        }
        return (places[0], nominal(places[0]), true)
    }

    private static func restStep(_ rest: RestKind, place: Place, start: Date, end: Date, ryeShare: Double,
                                 temperatures: Temperatures) -> ScheduleStep {
        ScheduleStep(kind: .rest(rest, place), start: start, end: end,
                     hourRange: ScheduleRules.range(rest, ryeShare: ryeShare, place: place, temperatures: temperatures),
                     celsius: ScheduleRules.celsius(rest, ryeShare: ryeShare,
                                                    hours: end.timeIntervalSince(start) / 3600))
    }

    /// Plans backwards from `target`, the time the bread can be cut.
    public init(target: Date, ryeShare: Double, vessel: BakeSetup.Vessel,
                temperatures: Temperatures, window: InteractionWindow = InteractionWindow(),
                choices: [RestKind: RestChoice] = [:], calendar: Calendar) {
        func minutes(_ action: ActionKind) -> TimeInterval {
            ScheduleRules.minutes(action, vessel: vessel) * 60
        }
        var reversed: [ScheduleStep] = []

        // Cooling, baking and preheating.
        let bakeBlock = minutes(.bake) + minutes(.preheat)
        let latestBakeEnd = target - ScheduleRules.coolingHours(ryeShare: ryeShare) * 3600
        let fitted = window.closestEnd(to: latestBakeEnd, length: bakeBlock,
                                       in: latestBakeEnd - 3 * 86400, latestBakeEnd, calendar: calendar)
        let bakeEnd = fitted ?? latestBakeEnd
        let bakeStart = bakeEnd - minutes(.bake)
        reversed.append(ScheduleStep(kind: .cooling, start: bakeEnd, end: target))
        reversed.append(ScheduleStep(kind: .action(.bake), start: bakeStart, end: bakeEnd,
                                     outsideWindow: fitted == nil))
        reversed.append(ScheduleStep(kind: .action(.preheat), start: bakeStart - minutes(.preheat), end: bakeStart,
                                     outsideWindow: fitted == nil))

        // The rests, last first, each with the action before it.
        var end = bakeStart
        for (action, rest) in Self.pairs.reversed() {
            let length = minutes(action)
            let chosen = Self.place(rest, ryeShare: ryeShare, temperatures: temperatures, choice: choices[rest],
                                    window: window, calendar: calendar, base: end, direction: -1, length: length)
            let start = end - chosen.hours * 3600
            reversed.append(Self.restStep(rest, place: chosen.place, start: start, end: end, ryeShare: ryeShare,
                                          temperatures: temperatures))
            reversed.append(ScheduleStep(kind: .action(action), start: start - length, end: start,
                                         outsideWindow: chosen.outside))
            end = start - length
        }
        steps = reversed.reversed()
        self.vessel = vessel
    }

    /// Plans forwards from `start`, the time the sourdough is mixed.
    public init(start: Date, ryeShare: Double, vessel: BakeSetup.Vessel,
                temperatures: Temperatures, window: InteractionWindow = InteractionWindow(),
                choices: [RestKind: RestChoice] = [:], calendar: Calendar) {
        func minutes(_ action: ActionKind) -> TimeInterval {
            ScheduleRules.minutes(action, vessel: vessel) * 60
        }
        var steps: [ScheduleStep] = []
        var actionStart = start
        var outside = !window.contains(start, start + minutes(.mixSourdough), calendar: calendar)

        // Each action with the rest after it. What follows the rest is the
        // next action; after the proof it is preheating, which overlaps the
        // end of the proof, and baking.
        for (action, rest) in Self.pairs {
            let actionEnd = actionStart + minutes(action)
            steps.append(ScheduleStep(kind: .action(action), start: actionStart, end: actionEnd,
                                      outsideWindow: outside))
            let after = minutes(rest == .sourdough ? .knead : rest == .bulk ? .shape : .bake)
            let before = rest == .proof ? minutes(.preheat) : 0
            let chosen = Self.place(rest, ryeShare: ryeShare, temperatures: temperatures, choice: choices[rest],
                                    window: window, calendar: calendar, base: actionEnd + after, direction: 1,
                                    length: before + after)
            let restEnd = actionEnd + chosen.hours * 3600
            steps.append(Self.restStep(rest, place: chosen.place, start: actionEnd, end: restEnd,
                                       ryeShare: ryeShare, temperatures: temperatures))
            actionStart = restEnd
            outside = chosen.outside
        }

        let bakeEnd = actionStart + minutes(.bake)
        steps.append(ScheduleStep(kind: .action(.preheat), start: actionStart - minutes(.preheat), end: actionStart,
                                  outsideWindow: outside))
        steps.append(ScheduleStep(kind: .action(.bake), start: actionStart, end: bakeEnd, outsideWindow: outside))
        steps.append(ScheduleStep(kind: .cooling, start: bakeEnd,
                                  end: bakeEnd + ScheduleRules.coolingHours(ryeShare: ryeShare) * 3600))
        self.steps = steps
        self.vessel = vessel
    }

    /// Hours of the day a proposed target falls on.
    public static let proposedHours = [12, 18]

    /// The first noon or evening (`proposedHours`) of today and the next
    /// six days whose schedule starts after `now` without conflicts; if
    /// there is none, noon a week from today.
    public static func proposedTarget(after now: Date, ryeShare: Double, vessel: BakeSetup.Vessel,
                                      temperatures: Temperatures, window: InteractionWindow = InteractionWindow(),
                                      calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        for day in 0..<7 {
            for hour in proposedHours {
                let date = calendar.date(byAdding: .day, value: day, to: today)!
                let target = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
                let schedule = Schedule(target: target, ryeShare: ryeShare, vessel: vessel,
                                        temperatures: temperatures, window: window, calendar: calendar)
                if schedule.start >= now && schedule.conflicts.isEmpty { return target }
            }
        }
        let week = calendar.date(byAdding: .day, value: 7, to: today)!
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: week)!
    }

    public var start: Date { steps[0].start }
    public var target: Date { steps[steps.count - 1].end }

    /// The actions that lie outside the interaction window.
    public var conflicts: [ActionKind] {
        steps.compactMap { step in
            if case .action(let action) = step.kind, step.outsideWindow { return action }
            return nil
        }
    }

    /// The end that `anchor` fixes: the start or the target.
    public func time(of anchor: ScheduleAnchor) -> Date {
        anchor == .start ? start : target
    }

    /// The target temperature of each rest (`ScheduleStep.celsius`).
    public var restCelsius: [RestKind: Double] {
        Dictionary(uniqueKeysWithValues: steps.compactMap { step in
            if case .rest(let rest, _) = step.kind, let celsius = step.celsius { return (rest, celsius) }
            return nil
        })
    }

    /// Every rest as it is planned, as choices: planned from the other end
    /// with these, the schedule keeps its rests.
    public var restChoices: [RestKind: RestChoice] {
        Dictionary(uniqueKeysWithValues: steps.compactMap { step in
            if case .rest(let rest, let place) = step.kind { return (rest, RestChoice(place: place, hours: step.hours)) }
            return nil
        })
    }

    /// `date` on the nearest whole minute.
    public static func wholeMinute(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / 60).rounded() * 60)
    }

    /// This plan on whole minutes, to fix `anchor` with: the time of that end
    /// and every rest as a choice. The actions take whole minutes, so with
    /// whole-minute rests every step of the new plan lies on a whole minute,
    /// and a date picker, which only knows minutes, leaves it as it is.
    ///
    /// Each rest runs from its start to its end, both rounded to the nearest
    /// minute: no step of the new plan moves by more than half a minute,
    /// where rounding each duration alone could add up to more. A rest that
    /// would leave its range that way (it was at a bound) takes the whole
    /// minute just inside it. A bound a float rest away from a whole minute
    /// (1.5 h × 1.2 is 1.799 999 999 999 999 8 h) counts as that minute.
    public func onWholeMinutes(fixing anchor: ScheduleAnchor) -> (time: Date, choices: [RestKind: RestChoice]) {
        let slack = 1e-6
        let choices = Dictionary(uniqueKeysWithValues: steps.compactMap { step -> (RestKind, RestChoice)? in
            guard case .rest(let rest, let place) = step.kind else { return nil }
            var minutes = Self.wholeMinute(step.end).timeIntervalSince(Self.wholeMinute(step.start)) / 60
            let range = step.hourRange ?? step.hours...step.hours
            minutes = min(max(minutes, (range.lowerBound * 60 - slack).rounded(.up)),
                          (range.upperBound * 60 + slack).rounded(.down))
            return (rest, RestChoice(place: place, hours: minutes / 60))
        })
        return (Self.wholeMinute(time(of: anchor)), choices)
    }

    /// The rest of `kind`.
    public func rest(_ kind: RestKind) -> ScheduleStep? {
        steps.first { step in
            if case .rest(kind, _) = step.kind { return true }
            return false
        }
    }
}
