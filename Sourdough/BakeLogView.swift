import SwiftUI
import SourdoughKit

/// All bakes, newest first.
struct BakeLogView: View {
    let store: BakeRunStore

    var body: some View {
        List {
            if store.runs.isEmpty {
                Text("Noch kein Brot gebacken.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("log-empty")
            }
            ForEach(Array(store.runs.enumerated()), id: \.element.id) { index, run in
                // A link with its destination: the start screen's path holds
                // its own destinations, not ids.
                NavigationLink {
                    BakeLogDetailView(store: store, id: run.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(run.bread.germanName)
                        Text("\(ScheduleText.day(run.startedAt, calendar: run.calendar)) · \(BakeRunText.status(run.status))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("log-row-\(index)")
            }
        }
        .navigationTitle("Backprotokoll")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { TipsButton(topic: .log) }
    }
}

/// One bake with everything that went into it.
struct BakeLogDetailView: View {
    let store: BakeRunStore
    let id: BakeRun.ID
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        if let run = store.run(id) {
            content(run)
        }
    }

    private func content(_ run: BakeRun) -> some View {
        let recipe = run.recipe
        let calendar = run.calendar
        return Form {
            Section("Brot") {
                row("Brotart", run.bread.germanName, id: "log-bread")
                row("Status", BakeRunText.status(run.status), id: "log-status")
                row("Begonnen", ScheduleText.day(run.startedAt, calendar: calendar), id: "log-started")
                row("Anschnittfertig geplant", ScheduleText.day(run.target, calendar: calendar), id: "log-target")
                row("Starter", BakeLogText.starter(run.starter), id: "log-starter")
                row("Utensilien", BakeLogText.equipment(run.setup), id: "log-equipment")
                row("Temperaturen", BakeLogText.temperatures(run.temperatures), id: "log-temperatures")
            }
            Section("Mehl") {
                ForEach(run.mix.flours, id: \.self) { flour in
                    row(flour.germanName,
                        "\(BakeText.percent(run.mix.share(of: flour))) · \(BakeText.grams(run.mix.grams(of: flour, totalGrams: run.totalGrams)))",
                        id: "log-flour-\(flour.rawValue)")
                }
                row("Hydration", BakeText.percent(run.mix.hydration), id: "log-hydration")
                row("Sauerteigstufe", BakeText.grams(recipe.sourdoughGrams), id: "log-sourdough")
                row("Salz", BakeText.grams(recipe.salt), id: "log-salt")
                row("Zusätze", BakeLogText.addIns(recipe), id: "log-addins")
            }
            Section("Ablauf") {
                ForEach(Array(run.entries.enumerated()), id: \.offset) { index, entry in
                    row(BakeRunText.title(run, entry.step, round: entry.round), BakeLogText.times(run, entry),
                        id: "log-step-\(index)")
                }
            }
            Section {
                Button("Durchgang löschen", role: .destructive) { confirmDelete = true }
                    .accessibilityIdentifier("log-delete")
            }
        }
        .navigationTitle(run.bread.germanName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { TipsButton(topic: .logDetail) }
        .alert("Durchgang löschen?", isPresented: $confirmDelete) {
            Button("Löschen", role: .destructive) {
                store.remove(id)
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der Durchgang verschwindet aus dem Backprotokoll.")
        }
    }

    private func row(_ title: String, _ value: String, id: String) -> some View {
        LabeledContent(title) {
            Text(value).multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}

/// German texts of the log.
enum BakeLogText {
    /// "50 g Saaten, 40 g Röstzwiebeln", or "keine".
    static func addIns(_ recipe: Recipe) -> String {
        guard !recipe.addIns.isEmpty else { return "keine" }
        return recipe.addIns.map { "\(BakeText.grams($0.grams)) \($0.addIn.germanName)" }.joined(separator: ", ")
    }

    /// "Opa (Roggen)", or "keiner".
    static func starter(_ starter: Starter?) -> String {
        starter.map { "\($0.name) (\($0.flour.germanName))" } ?? "keiner"
    }

    /// "Römertopf, Gärkörbchen, Thermomix"; bowl, tray and hands by name.
    static func equipment(_ setup: BakeSetup) -> String {
        let vessel = setup.vesselItem?.name ?? "Blech"
        let proof = setup.vessel.isFreeStanding ? [setup.basket?.name ?? "Schüssel"] : []
        let kneader = setup.kneader?.name ?? "von Hand"
        return ([vessel] + proof + [kneader]).joined(separator: ", ")
    }

    /// "Raum 22 °C, Kühlschrank 5 °C"
    static func temperatures(_ temperatures: Temperatures) -> String {
        "Raum \(StarterText.number(temperatures.roomCelsius)) °C, Kühlschrank \(StarterText.number(temperatures.fridgeCelsius)) °C"
    }

    /// "geplant Sa 08:10 · erledigt Sa 08:12", "· Über dem Rand" for an
    /// answer, "· Ruhe bei etwa 16 °C" for a step a rest follows (not for
    /// the rounds within it).
    static func times(_ run: BakeRun, _ entry: BakeRun.Entry) -> String {
        let step = entry.step
        let planned = BakeProcess.plannedTime(step, round: entry.round, in: run.schedule)
        var parts = ["geplant \(ScheduleText.time(planned, calendar: run.calendar))"]
        if let done = run.doneAt(entry) { parts.append("erledigt \(ScheduleText.time(done, calendar: run.calendar))") }
        if let answer = run.answers[step] { parts.append(BakeRunText.answer(answer)) }
        if entry.round == nil, let rest = BakeProcess.followingRest(step) {
            parts.append("Ruhe \(BakeRunText.restTemperature(run.celsius(rest)))")
        }
        return parts.joined(separator: " · ")
    }
}
