import Foundation

/// The timeline of a bake laid out as one row per calendar day, each showing
/// only the hours `firstHour` to `lastHour`: the night between two days is left
/// out, so a row reads like a day. Positions are fractions of a row (0 at
/// `firstHour`, 1 at `lastHour`).
///
/// - A step that reaches into the night is cut at the edge of the row and
///   marked as continuing (`continuesBefore`, `continuesAfter`); it shows in
///   both rows when it spans a night.
/// - A step that lies completely in the night (an action at 23:07, a rest from
///   22:30 to 06:30) has no visible part. It becomes a mark of zero length at
///   the edge of the row of the day it starts in (`inTheNight`): the right edge
///   if it starts in the evening, the left edge if it starts in the early morning.
public struct ScheduleDays: Equatable, Sendable {
    public static let firstHour = 7
    public static let lastHour = 22

    /// One step in one row.
    public struct Segment: Equatable, Sendable {
        /// The index in `Schedule.steps`.
        public let stepIndex: Int
        public let kind: ScheduleStep.Kind
        public let outsideWindow: Bool
        public let from: Double
        public let to: Double
        public let continuesBefore: Bool
        public let continuesAfter: Bool
        public let inTheNight: Bool
    }

    public struct Day: Equatable, Sendable, Identifiable {
        /// Midnight at the start of the day.
        public let start: Date
        public let segments: [Segment]
        /// Where the bread can be cut, if that is on this day (clamped to the row).
        public let target: Double?

        public var id: Date { start }
    }

    public let days: [Day]

    public init(_ schedule: Schedule, calendar: Calendar) {
        func time(_ hour: Int, of day: Date) -> Date {
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        }
        let first = calendar.startOfDay(for: schedule.start)
        let last = calendar.startOfDay(for: schedule.target)
        var starts: [Date] = []
        var day = first
        while day <= last {
            starts.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        var segments = starts.map { _ in [Segment]() }
        var shown = Set<Int>()
        for (row, day) in starts.enumerated() {
            let open = time(Self.firstHour, of: day)
            let close = time(Self.lastHour, of: day)
            let span = close.timeIntervalSince(open)
            for (index, step) in schedule.steps.enumerated() {
                let from = max(step.start, open)
                let to = min(step.end, close)
                guard from < to else { continue }
                shown.insert(index)
                segments[row].append(Segment(
                    stepIndex: index, kind: step.kind, outsideWindow: step.outsideWindow,
                    from: from.timeIntervalSince(open) / span, to: to.timeIntervalSince(open) / span,
                    continuesBefore: step.start < open, continuesAfter: step.end > close, inTheNight: false))
            }
        }
        // What lies completely in the night still has to show.
        for (index, step) in schedule.steps.enumerated() where !shown.contains(index) {
            let startDay = calendar.startOfDay(for: step.start)
            guard let row = starts.firstIndex(of: startDay) else { continue }
            let evening = step.start >= time(Self.lastHour, of: startDay)
            let edge = evening ? 1.0 : 0.0
            segments[row].append(Segment(
                stepIndex: index, kind: step.kind, outsideWindow: step.outsideWindow,
                from: edge, to: edge, continuesBefore: false, continuesAfter: false, inTheNight: true))
        }

        let target = schedule.target
        days = starts.enumerated().map { row, day in
            let open = time(Self.firstHour, of: day)
            let span = time(Self.lastHour, of: day).timeIntervalSince(open)
            let onThisDay = calendar.startOfDay(for: target) == day
            return Day(start: day, segments: segments[row].sorted { $0.stepIndex < $1.stepIndex },
                       target: onThisDay ? min(max(target.timeIntervalSince(open) / span, 0), 1) : nil)
        }
    }
}
