import Foundation

/// Where the dough rests, and so how warm it is.
public enum Place: String, Codable, CaseIterable, Sendable {
    /// About 27 °C: the oven with only its lamp on, or a warm corner.
    case warm
    case room
    case fridge
}

/// The temperatures of the user's kitchen; warm is fixed.
public struct Temperatures: Codable, Equatable, Sendable {
    public static let warmCelsius = 27.0
    /// The dough should come out of kneading at about this temperature.
    public static let doughTargetCelsius = 26.0

    public var roomCelsius: Double
    public var fridgeCelsius: Double

    public init(roomCelsius: Double = Starter.defaultRoomCelsius, fridgeCelsius: Double = 5) {
        self.roomCelsius = roomCelsius
        self.fridgeCelsius = fridgeCelsius
    }

    public func celsius(_ place: Place) -> Double {
        switch place {
        case .warm: Self.warmCelsius
        case .room: roomCelsius
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

    /// The places this rest can take, the usual one first.
    public var places: [Place] {
        switch self {
        case .sourdough, .bulk: [.room, .warm]
        case .proof: [.room, .fridge, .warm]
        }
    }

    /// Shortest and longest sensible time, as factors of the nominal time.
    public var factorRange: ClosedRange<Double> {
        switch self {
        case .sourdough: 0.6...1.6
        case .bulk, .proof: 0.7...1.5
        }
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

    public var hours: Double { end.timeIntervalSince(start) / 3600 }
}

/// The timeline of a bake, planned backwards from the time the bread can be cut.
///
/// Going back from the target: the bread cools at least
/// `ScheduleRules.coolingHours`, longer if that puts preheating and baking
/// into the interaction window. Then each rest, last first, takes the first
/// of its places (`RestKind.places`) at which a time within its range puts
/// the action before it into the window, the time closest to the nominal one.
/// If no place works, it takes the nominal time at the usual place and the
/// action is marked as outside the window. A rest in `choices` takes the
/// place and hours given there instead, clamped to the range.
public struct Schedule: Equatable, Sendable {
    public let steps: [ScheduleStep]
    /// What the bread bakes in; it decides some step titles.
    public let vessel: BakeSetup.Vessel

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
        reversed.append(ScheduleStep(kind: .cooling, start: bakeEnd, end: target, hourRange: nil, outsideWindow: false))
        reversed.append(ScheduleStep(kind: .action(.bake), start: bakeStart, end: bakeEnd, hourRange: nil,
                                     outsideWindow: fitted == nil))
        reversed.append(ScheduleStep(kind: .action(.preheat), start: bakeStart - minutes(.preheat), end: bakeStart,
                                     hourRange: nil, outsideWindow: fitted == nil))

        // The rests, each with the action before it.
        var end = bakeStart
        let pairs: [(RestKind, ActionKind)] = [(.proof, .shape), (.bulk, .knead), (.sourdough, .mixSourdough)]
        for (rest, action) in pairs {
            let length = minutes(action)
            func range(_ place: Place) -> ClosedRange<Double> {
                let nominal = ScheduleRules.hours(rest, ryeShare: ryeShare, celsius: temperatures.celsius(place))
                return nominal * rest.factorRange.lowerBound...nominal * rest.factorRange.upperBound
            }
            func nominal(_ place: Place) -> Double {
                ScheduleRules.hours(rest, ryeShare: ryeShare, celsius: temperatures.celsius(place))
            }
            var chosen: (place: Place, start: Date, outside: Bool)?
            if let choice = choices[rest] {
                let hours = min(max(choice.hours, range(choice.place).lowerBound), range(choice.place).upperBound)
                let start = end - hours * 3600
                chosen = (choice.place, start, !window.contains(start - length, start, calendar: calendar))
            } else {
                for place in rest.places {
                    let span = range(place)
                    if let start = window.closestEnd(to: end - nominal(place) * 3600, length: length,
                                                     in: end - span.upperBound * 3600, end - span.lowerBound * 3600,
                                                     calendar: calendar) {
                        chosen = (place, start, false)
                        break
                    }
                }
            }
            let place = chosen?.place ?? rest.places[0]
            let start = chosen?.start ?? end - nominal(place) * 3600
            let outside = chosen?.outside ?? true
            reversed.append(ScheduleStep(kind: .rest(rest, place), start: start, end: end,
                                         hourRange: range(place), outsideWindow: false))
            reversed.append(ScheduleStep(kind: .action(action), start: start - length, end: start,
                                         hourRange: nil, outsideWindow: outside))
            end = start - length
        }
        steps = reversed.reversed()
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

    /// The rest of `kind`.
    public func rest(_ kind: RestKind) -> ScheduleStep? {
        steps.first { step in
            if case .rest(kind, _) = step.kind { return true }
            return false
        }
    }
}
