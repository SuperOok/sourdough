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
    public let target: Date
    public let choices: [RestKind: RestChoice]
    /// The time zone the plan was made in, so the schedule comes out the same.
    public let timeZone: TimeZone

    public private(set) var status: Status = .active
    public private(set) var endedAt: Date?
    /// When each step was done.
    public private(set) var done: [BakeProcess.StepID: Date] = [:]
    /// The latest answer to each decision.
    public private(set) var answers: [BakeProcess.StepID: BakeProcess.Answer] = [:]

    public init(id: UUID = UUID(), startedAt: Date, bread: BreadType, mix: FlourMix, totalGrams: Double,
                limits: [Flour: Double], starter: Starter?, setup: BakeSetup, temperatures: Temperatures,
                window: InteractionWindow, target: Date, choices: [RestKind: RestChoice], timeZone: TimeZone) {
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
        self.target = target
        self.choices = choices
        self.timeZone = timeZone
    }

    public var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    public var schedule: Schedule {
        Schedule(target: target, ryeShare: mix.ryeShare, vessel: setup.vessel, temperatures: temperatures,
                 window: window, choices: choices, calendar: calendar)
    }

    public var recipe: Recipe {
        Recipe(mix: mix, totalGrams: totalGrams, starterFlour: starter?.flour)
    }

    /// The text each step shows, given the answers so far.
    public func text(_ step: BakeProcess.StepID) -> BakeProcess.Text {
        BakeProcess.text(step, setup: setup, ryeShare: mix.ryeShare, answers: answers)
    }

    /// The first step not done yet; `nil` when all are.
    public var current: BakeProcess.StepID? {
        BakeProcess.StepID.allCases.first { done[$0] == nil }
    }

    /// Marks the current step done at `date`; the last one ends the bake.
    /// Decisions are answered with `answer` instead.
    public mutating func complete(at date: Date) {
        guard status == .active, let step = current,
              BakeProcess.answers(step, setup: setup).isEmpty else { return }
        done[step] = date
        if current == nil {
            status = .finished
            endedAt = date
        }
    }

    /// Answers the current decision. An answer that waits keeps the step
    /// open; any other marks it done.
    public mutating func answer(_ answer: BakeProcess.Answer, at date: Date) {
        guard status == .active, let step = current,
              BakeProcess.answers(step, setup: setup).contains(answer) else { return }
        answers[step] = answer
        if !answer.waits { done[step] = date }
    }

    /// Whether the current decision was last answered "not yet".
    public var isWaiting: Bool {
        current.flatMap { answers[$0] }?.waits == true
    }

    public mutating func cancel(at date: Date) {
        guard status == .active else { return }
        status = .cancelled
        endedAt = date
    }
}
