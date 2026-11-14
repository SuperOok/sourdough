import Foundation

/// One bake from start to finish: the whole plan as it was when it started,
/// and what happened since. Starter and equipment are copies, so a later
/// change to them leaves the record as it was.
public struct BakeRun: Codable, Equatable, Identifiable, Sendable {
    public enum Status: String, Codable, Sendable {
        case active, finished, cancelled
    }

    public let id: UUID
    public let startedAt: Date
    public let bread: BreadType
    public let mix: FlourMix
    public let totalGrams: Double
    /// The limits in grams the plan had.
    public let limits: [Flour: Double]
    /// A copy of the starter as it was at the start; `nil` if none was chosen.
    public let starter: Starter?
    public let setup: BakeSetup
    public let temperatures: Temperatures
    public let window: InteractionWindow
    /// When the bread can be cut, as planned; with `anchor == .start` the
    /// result of planning forwards.
    public let target: Date
    public let choices: [RestKind: RestChoice]
    /// The time zone the plan was made in, so the schedule comes out the same.
    public let timeZone: TimeZone
    /// Optional, so that bakes saved before add-ins existed still load.
    private let addInShares: AddIns?
    /// Optional, so that bakes saved before planning forwards still load:
    /// they were all planned backwards from `target`.
    private let scheduleAnchor: ScheduleAnchor?
    /// The start a forward plan begins with; `nil` for a backward one.
    private let startTime: Date?
    /// The target temperature of each rest as planned; `nil` for bakes saved
    /// before there was one.
    private let restCelsius: [RestKind: Double]?

    public private(set) var status: Status = .active
    public private(set) var endedAt: Date?
    /// When each step was done.
    public private(set) var done: [BakeProcess.StepID: Date] = [:]
    /// The latest answer to each decision.
    public private(set) var answers: [BakeProcess.StepID: BakeProcess.Answer] = [:]

    public init(id: UUID = UUID(), startedAt: Date, bread: BreadType, mix: FlourMix, totalGrams: Double,
                limits: [Flour: Double], starter: Starter?, setup: BakeSetup, temperatures: Temperatures,
                window: InteractionWindow, anchor: ScheduleAnchor = .ready, time: Date,
                choices: [RestKind: RestChoice], timeZone: TimeZone, addIns: AddIns = AddIns()) {
        self.id = id
        self.startedAt = startedAt
        self.bread = bread
        self.mix = mix
        self.totalGrams = totalGrams
        self.limits = limits
        self.starter = starter
        self.setup = setup
        self.temperatures = temperatures
        self.window = window
        self.choices = choices
        self.timeZone = timeZone
        addInShares = addIns
        scheduleAnchor = anchor
        startTime = anchor == .start ? time : nil
        let schedule = Schedule(anchor: anchor, time: time, ryeShare: mix.ryeShare, vessel: setup.vessel,
                                temperatures: temperatures, window: window, choices: choices,
                                calendar: Self.calendar(timeZone))
        target = schedule.target
        restCelsius = schedule.restCelsius
    }

    /// The add-ins of the plan; none for a bake saved before there were any.
    public var addIns: AddIns { addInShares ?? AddIns() }

    /// Which end of the plan was fixed; `.ready` for bakes saved before
    /// planning forwards.
    public var anchor: ScheduleAnchor { scheduleAnchor ?? .ready }

    /// The temperature `rest` aims for, as planned; for a bake saved before
    /// there was one, that of its place in `schedule` (built here if not
    /// given, so pass it where it is at hand), and room temperature should
    /// the plan lack that rest.
    public func celsius(_ rest: RestKind, in schedule: Schedule? = nil) -> Double {
        if let planned = restCelsius?[rest] { return planned }
        let place = (schedule ?? self.schedule).rest(rest)?.place
        return place.map(temperatures.celsius) ?? temperatures.roomCelsius
    }

    public var calendar: Calendar { Self.calendar(timeZone) }

    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    public var schedule: Schedule {
        Schedule(anchor: anchor, time: startTime ?? target, ryeShare: mix.ryeShare, vessel: setup.vessel,
                 temperatures: temperatures, window: window, choices: choices, calendar: calendar)
    }

    public var recipe: Recipe {
        Recipe(mix: mix, totalGrams: totalGrams, starterFlour: starter?.flour, addIns: addIns)
    }

    /// What the branches of the process depend on: setup, rye share and the
    /// answers so far.
    public var context: BakeProcess.Context {
        BakeProcess.Context(setup: setup, ryeShare: mix.ryeShare, answers: answers)
    }

    /// The text each step shows, given the answers so far.
    public func text(_ step: BakeProcess.StepID) -> BakeProcess.Text {
        BakeProcess.variant(step, in: context).text
    }

    /// The answers `step` can be given; empty for a step that is simply done.
    public func possibleAnswers(_ step: BakeProcess.StepID) -> [BakeProcess.Answer] {
        BakeProcess.answers(step, in: context)
    }

    /// The steps of this bake, in their order.
    public var steps: [BakeProcess.StepID] { BakeProcess.steps.map(\.id) }

    /// The first step not done yet; `nil` when all are.
    public var current: BakeProcess.StepID? {
        steps.first { done[$0] == nil }
    }

    /// Marks the current step done at `date`; the last one ends the bake.
    /// Decisions are answered with `answer` instead.
    public mutating func complete(at date: Date) {
        guard status == .active, let step = current, possibleAnswers(step).isEmpty else { return }
        done[step] = date
        if current == nil {
            status = .finished
            endedAt = date
        }
    }

    /// Answers the current decision. An answer that waits keeps the step
    /// open; any other marks it done.
    public mutating func answer(_ answer: BakeProcess.Answer, at date: Date) {
        guard status == .active, let step = current, possibleAnswers(step).contains(answer) else { return }
        answers[step] = answer
        if !answer.waits { done[step] = date }
    }

    /// Whether the current decision was last answered "not yet".
    public var isWaiting: Bool {
        current.flatMap { answers[$0] }?.waits == true
    }

    /// The step `undo` opens again: the last one done. `nil` before the
    /// first step and for a cancelled bake.
    public var previous: BakeProcess.StepID? {
        guard status != .cancelled else { return nil }
        return steps.last { done[$0] != nil }
    }

    /// Opens the last done step again, for a step tapped by mistake: it
    /// forgets when it was done and, for a decision, its answer. Answers of
    /// open steps after it ("not yet") go as well, and a finished bake runs
    /// again.
    public mutating func undo() {
        guard let step = previous else { return }
        done[step] = nil
        answers = answers.filter { done[$0.key] != nil }
        status = .active
        endedAt = nil
    }

    public mutating func cancel(at date: Date) {
        guard status == .active else { return }
        status = .cancelled
        endedAt = date
    }
}
