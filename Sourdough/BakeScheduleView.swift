import SwiftUI
import SourdoughKit

/// Planning a bake, step three: when the bread should be ready, and the
/// timeline that leads there.
struct BakeScheduleView: View {
    let model: BakePlanModel
    let starterStore: StarterStore
    let kitchenStore: KitchenStore
    /// "Now" for the proposed target; tests fix it.
    let now: Date
    let onStart: (BakeRun) -> Void
    @State private var pickingTarget = false
    private var calendar: Calendar { .current }

    var body: some View {
        let schedule = model.schedule(calendar: calendar)
        NumberForm(fields: ["schedule-room", "schedule-fridge"]) { focus in
            Section {
                Button { pickingTarget = true } label: {
                    LabeledContent("Anschnittfertig") {
                        Text(model.target.map { ScheduleText.day($0, calendar: calendar) } ?? "—")
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier("schedule-target")
                NumberField(title: "Raumtemperatur (°C)", text: Binding(
                    get: { model.roomText }, set: { model.roomText = $0 }), id: "schedule-room", focus: focus)
                NumberField(title: "Kühlschrank (°C)", text: Binding(
                    get: { model.fridgeText }, set: { model.fridgeText = $0 }), id: "schedule-fridge", focus: focus)
            } footer: {
                // Below the fields, so that it does not move them while typing.
                VStack(alignment: .leading, spacing: 4) {
                    if let error = model.temperatureError {
                        Text(error)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("schedule-error")
                    }
                    Text("Handgriffe liegen zwischen \(model.window.startHour) und \(model.window.endHour) Uhr.")
                }
            }
            if let schedule {
                Section {
                    ScheduleStrip(schedule: schedule, calendar: calendar)
                        .accessibilityIdentifier("schedule-chart")
                }
                Section {
                    ForEach(Array(schedule.steps.enumerated()), id: \.offset) { index, step in
                        stepRow(step, index: index, vessel: schedule.vessel)
                    }
                    Button("Vorschlag wiederherstellen") { model.resetChoices() }
                        .disabled(model.choices.isEmpty)
                        .accessibilityIdentifier("schedule-reset")
                } header: {
                    Text("Ablauf")
                } footer: {
                    // The steps outside the window are marked in their rows; the
                    // explanation sits below the list. Above the list it moved
                    // the whole screen whenever it appeared or went away.
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(schedule.steps.filter(\.outsideWindow).enumerated()), id: \.offset) { index, step in
                            Text(ScheduleText.conflict(step, vessel: schedule.vessel, window: model.window,
                                                       calendar: calendar))
                                .accessibilityIdentifier("schedule-conflict-\(index)")
                        }
                    }
                }
            }
            Section {
                let run = model.makeRun(starters: starterStore.starters, now: Date(), calendar: calendar)
                Button("Durchgang starten") { run.map(onStart) }
                    .fontWeight(.semibold)
                    .disabled(run == nil)
                    .accessibilityIdentifier("schedule-start")
            } footer: {
                Text("Danach führt dich die App Schritt für Schritt durch den Plan.")
            }
        }
        .navigationTitle("Zeitplan")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if model.roomText.isEmpty { model.useTemperatures(kitchenStore.temperatures) }
            model.proposeTarget(now: now, calendar: calendar)
        }
        .onChange(of: model.temperatures) { _, new in kitchenStore.temperatures = new }
        .sheet(isPresented: $pickingTarget) { targetSheet }
    }

    @ViewBuilder
    private func stepRow(_ step: ScheduleStep, index: Int, vessel: BakeSetup.Vessel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline) {
                    Text(ScheduleText.time(step.start, calendar: calendar))
                        .monospacedDigit()
                        .foregroundStyle(step.outsideWindow ? Color.orange : Color.primary)
                        .frame(width: 76, alignment: .leading)
                    Text(ScheduleText.title(step.kind, vessel: vessel))
                        .fontWeight(step.isAction ? .semibold : .regular)
                    Spacer()
                    if !step.isAction {
                        Text(ScheduleText.duration(hours: step.hours))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(step.outsideWindow ? "außerhalb des Zeitfensters" : "")
                .accessibilityIdentifier("schedule-step-\(index)")
                // Stockgare and Stückgare are terms to look up; the other
                // rests are named plainly.
                if case .rest(let rest, _) = step.kind, rest != .sourdough {
                    TipsIconButton(topic: .proofing, identifier: "schedule-tip-\(rest.rawValue)")
                        .padding(.leading, 8)
                }
            }
            if case .rest(let rest, let place) = step.kind, let range = step.hourRange {
                restControls(rest, place: place, step: step, range: range)
            }
        }
    }

    @ViewBuilder
    private func restControls(_ rest: RestKind, place: Place, step: ScheduleStep, range: ClosedRange<Double>) -> some View {
        RangeBar(range: range, value: step.hours, color: ScheduleStrip.color(step.kind))
            .frame(height: 6)
        Text("Sinnvoll: \(ScheduleText.range(range))")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("schedule-range-\(rest.rawValue)")
        HStack {
            Picker("Ort", selection: Binding(get: { place }, set: { model.setPlace($0, of: rest) })) {
                ForEach(rest.places, id: \.self) { Text($0.germanName(model.temperatures)).tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityIdentifier("schedule-place-\(rest.rawValue)")
            Spacer()
            Stepper("Dauer",
                    onIncrement: { model.setHours(step.hours + 0.5, of: rest, calendar: calendar) },
                    onDecrement: { model.setHours(step.hours - 0.5, of: rest, calendar: calendar) })
                .labelsHidden()
                .accessibilityIdentifier("schedule-stepper-\(rest.rawValue)")
        }
    }

    private var targetSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Anschnittfertig", selection: Binding(
                    get: { model.chosenTarget }, set: { model.chosenTarget = $0 }),
                           in: now..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .accessibilityIdentifier("schedule-datepicker")
            }
            .navigationTitle("Anschnittfertig")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { pickingTarget = false }
                        .accessibilityIdentifier("schedule-target-done")
                }
            }
        }
    }
}

extension ScheduleStep {
    var isAction: Bool {
        if case .action = kind { return true }
        return false
    }
}

/// The overview: one row per day, from `ScheduleDays.firstHour` to
/// `lastHour`; the night between the rows is left out. In each row the
/// actions are on the upper lane, the rests (in the colour of their place) and
/// the cooling on the lower one. A step that runs into the night fades out at
/// the edge; one that lies in the night is a small mark there.
struct ScheduleStrip: View {
    let schedule: Schedule
    let calendar: Calendar

    static func color(_ kind: ScheduleStep.Kind) -> Color {
        switch kind {
        case .action: .red
        case .rest(_, .warm): .orange
        case .rest(_, .room): .teal
        case .rest(_, .fridge): .blue
        case .cooling: .gray
        }
    }

    private static let laneHeight = 12.0
    private static let rowHeight = 27.0
    private static let labelWidth = 38.0
    private static let moonWidth = 14.0
    /// The hours that get a line and a number.
    private static let hourMarks = Array(stride(from: ScheduleDays.firstHour, through: ScheduleDays.lastHour, by: 3))

    var body: some View {
        let days = ScheduleDays(schedule, calendar: calendar).days
        VStack(alignment: .leading, spacing: 4) {
            axis
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                row(day, hasNight: index < days.count - 1)
            }
            legend
        }
        .accessibilityElement()
        .accessibilityLabel("Übersicht des Zeitplans")
    }

    private func x(_ fraction: Double, in width: Double) -> Double { fraction * width }

    private var axis: some View {
        HStack(spacing: 6) {
            Color.clear.frame(width: Self.labelWidth)
            GeometryReader { geometry in
                ForEach(Self.hourMarks, id: \.self) { hour in
                    let position = Double(hour - ScheduleDays.firstHour) / Double(ScheduleDays.lastHour - ScheduleDays.firstHour)
                    Text("\(hour)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .position(x: min(max(x(position, in: geometry.size.width), 7), geometry.size.width - 7), y: 6)
                }
            }
            .frame(height: 12)
            Color.clear.frame(width: Self.moonWidth)
        }
    }

    private func row(_ day: ScheduleDays.Day, hasNight: Bool) -> some View {
        HStack(spacing: 6) {
            VStack(spacing: 0) {
                Text(ScheduleText.weekday(day.start, calendar: calendar)).font(.caption.weight(.semibold))
                Text(ScheduleText.dayMonth(day.start, calendar: calendar)).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: Self.labelWidth)
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary.opacity(0.5))
                    ForEach(Self.hourMarks, id: \.self) { hour in
                        let position = Double(hour - ScheduleDays.firstHour) / Double(ScheduleDays.lastHour - ScheduleDays.firstHour)
                        Rectangle().fill(.quaternary).frame(width: 1)
                            .offset(x: x(position, in: width) - 0.5)
                    }
                    ForEach(day.segments, id: \.stepIndex) { segment in
                        bar(segment, width: width)
                    }
                    if let target = day.target {
                        Rectangle().fill(.primary).frame(width: 2, height: Self.rowHeight)
                            .offset(x: x(target, in: width) - 1)
                    }
                }
            }
            .frame(height: Self.rowHeight)
            // The night follows this row: it is not drawn.
            Image(systemName: "moon.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(hasNight ? 1 : 0)
                .frame(width: Self.moonWidth)
        }
    }

    @ViewBuilder
    private func bar(_ segment: ScheduleDays.Segment, width: Double) -> some View {
        let isAction = if case .action = segment.kind { true } else { false }
        let top = isAction ? 0.0 : Self.laneHeight + 3
        if segment.inTheNight {
            // A mark in both lanes at the edge: this step is in the night.
            Capsule().fill(.primary).frame(width: 4, height: Self.rowHeight)
                .offset(x: segment.from == 0 ? 0 : width - 4)
        } else {
            let left = x(segment.from, in: width)
            let length = max(x(segment.to - segment.from, in: width), 2)
            RoundedRectangle(cornerRadius: 3)
                .fill(Self.color(segment.kind))
                .overlay {
                    if segment.outsideWindow {
                        RoundedRectangle(cornerRadius: 3).strokeBorder(.primary, lineWidth: 1.5)
                    }
                }
                .mask(fade(before: segment.continuesBefore, after: segment.continuesAfter, length: length))
                .frame(width: length, height: Self.laneHeight)
                .offset(x: left, y: top)
        }
    }

    /// Full everywhere; a cut end fades out over about 14 points.
    private func fade(before: Bool, after: Bool, length: Double) -> some View {
        let edge = min(14 / length, 0.5)
        return LinearGradient(stops: [
            .init(color: .black.opacity(before ? 0 : 1), location: 0),
            .init(color: .black, location: before ? edge : 0),
            .init(color: .black, location: after ? 1 - edge : 1),
            .init(color: .black.opacity(after ? 0 : 1), location: 1),
        ], startPoint: .leading, endPoint: .trailing)
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendItem(.red, "Handgriff")
            legendItem(.teal, "Raum")
            legendItem(.orange, "Warm")
            legendItem(.blue, "Kühlschrank")
            legendItem(.gray, "Auskühlen")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.top, 2)
    }

    private func legendItem(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(title)
        }
    }
}

/// A thin bar: the sensible range coloured, the current value as a mark.
struct RangeBar: View {
    let range: ClosedRange<Double>
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let top = range.upperBound * 1.15
            let x = { (hours: Double) in geometry.size.width * hours / top }
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(color.opacity(0.6))
                    .frame(width: x(range.upperBound) - x(range.lowerBound))
                    .offset(x: x(range.lowerBound))
                Rectangle().fill(.primary)
                    .frame(width: 2, height: 12)
                    .offset(x: x(value) - 1)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    let defaults = UserDefaults(suiteName: "preview") ?? .standard
    let model = BakePlanModel()
    model.proposeSetup(from: [])
    return NavigationStack {
        BakeScheduleView(model: model, starterStore: StarterStore(defaults: defaults),
                         kitchenStore: KitchenStore(defaults: defaults), now: Date()) { _ in }
    }
}
