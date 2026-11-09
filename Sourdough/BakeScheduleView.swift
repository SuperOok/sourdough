import Charts
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
        Form {
            if let error = model.temperatureError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("schedule-error")
                }
            }
            if let schedule, !schedule.conflicts.isEmpty {
                Section {
                    ForEach(Array(schedule.steps.filter(\.outsideWindow).enumerated()), id: \.offset) { index, step in
                        Text(ScheduleText.conflict(step, vessel: schedule.vessel, window: model.window,
                                                   calendar: calendar))
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("schedule-conflict-\(index)")
                    }
                }
            }
            Section {
                Button { pickingTarget = true } label: {
                    LabeledContent("Anschnittfertig") {
                        Text(model.target.map { ScheduleText.day($0, calendar: calendar) } ?? "—")
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier("schedule-target")
                NumberField(title: "Raumtemperatur (°C)", text: Binding(
                    get: { model.roomText }, set: { model.roomText = $0 }), id: "schedule-room")
                NumberField(title: "Kühlschrank (°C)", text: Binding(
                    get: { model.fridgeText }, set: { model.fridgeText = $0 }), id: "schedule-fridge")
            } footer: {
                Text("Handgriffe liegen zwischen \(model.window.startHour) und \(model.window.endHour) Uhr.")
            }
            if let schedule {
                Section {
                    ScheduleStrip(schedule: schedule, calendar: calendar)
                        .frame(height: 64)
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
                Text(ScheduleText.time(step.start, calendar: calendar))
                    .monospacedDigit()
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
            .accessibilityIdentifier("schedule-step-\(index)")
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

/// The overview: one bar from the first action to the target, rests in the
/// colour of their place, actions on top, midnight as a line with the day.
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

    private var midnights: [Date] {
        var days: [Date] = []
        var day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: schedule.start))!
        while day < schedule.target {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return days
    }

    var body: some View {
        Chart {
            ForEach(Array(schedule.steps.enumerated()), id: \.offset) { _, step in
                BarMark(xStart: .value("Beginn", step.start), xEnd: .value("Ende", step.end),
                        y: .value("Art", step.isAction ? "Handgriff" : "Ruhe"))
                    .foregroundStyle(Self.color(step.kind))
            }
            ForEach(midnights, id: \.self) { midnight in
                RuleMark(x: .value("Mitternacht", midnight))
                    .foregroundStyle(.primary)
                    .annotation(position: .top, alignment: .leading) {
                        Text(ScheduleText.time(midnight, calendar: calendar).prefix(2))
                            .font(.caption2)
                    }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Übersicht des Zeitplans")
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
