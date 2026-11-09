import SwiftUI
import SourdoughKit

/// One starter: its state and dates, where it is kept, and its feedings.
struct StarterDetailView: View {
    let store: StarterStore
    let id: Starter.ID
    @Environment(\.dismiss) private var dismiss
    @State private var showFeed = false
    @State private var confirmDelete = false
    @State private var fridgeText = ""
    @State private var now = Date()

    var body: some View {
        if let starter = store.starter(id) {
            content(starter, now: now)
        }
    }

    private func content(_ starter: Starter, now: Date) -> some View {
        let summary = StarterSummary(starter, now: now)
        return Form {
            Section {
                Button("Füttern") { showFeed = true }
                    .accessibilityIdentifier("detail-feed")
            }
            Section("Zustand") {
                infoRow("Zustand", summary.stateTitle, id: "detail-state")
                Text(summary.hint).foregroundStyle(.secondary)
                    .accessibilityIdentifier("detail-hint")
                infoRow("Angesetzt vor", summary.age, id: "detail-age")
                infoRow("Füttern oder verwenden bis", summary.feedBy, id: "detail-feedby")
                infoRow("Beste Zeit", summary.bestWindow, id: "detail-window")
            }
            Section("Aufbewahrung") {
                Picker("Ort", selection: storage(starter)) {
                    Text("Raumtemperatur").tag(false)
                    Text("Kühlschrank").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("detail-storage")
                if starter.inFridge {
                    NumberField(title: "Kühlschranktemperatur (°C)", text: $fridgeText,
                                id: "detail-fridge-temp")
                    if StarterFormModel.parseFridge(fridgeText) == nil {
                        Text(StarterFormModel.fridgeRange).foregroundStyle(.red)
                            .accessibilityIdentifier("detail-fridge-error")
                    }
                }
            }
            Section("Fütterungen") {
                let feedings = starter.feedings.sorted { $0.date > $1.date }
                ForEach(Array(feedings.enumerated()), id: \.element.id) { index, feeding in
                    Text(StarterText.feedingLine(feeding))
                        .accessibilityIdentifier("feeding-\(index)")
                }
            }
            Section {
                Button("Starter löschen", role: .destructive) { confirmDelete = true }
                    .accessibilityIdentifier("detail-delete")
            }
        }
        .refreshing($now)
        .navigationTitle(starter.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                TipsButton(topic: .starterStates, identifier: "detail-tips")
            }
        }
        .onAppear { fridgeText = StarterText.number(starter.fridgeCelsius) }
        .onChange(of: fridgeText) { _, text in
            if let celsius = StarterFormModel.parseFridge(text) {
                store.setFridgeCelsius(id, celsius)
            }
        }
        .sheet(isPresented: $showFeed) {
            FeedView(previous: starter.lastFeeding) { store.feed(id, with: $0) }
        }
        .alert("Starter löschen?", isPresented: $confirmDelete) {
            Button("Löschen", role: .destructive) {
                store.remove(id)
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der Starter und alle seine Fütterungen werden gelöscht.")
        }
    }

    private func storage(_ starter: Starter) -> Binding<Bool> {
        Binding(get: { starter.inFridge },
                set: { store.setStorage(id, inFridge: $0, fridgeCelsius: starter.fridgeCelsius) })
    }

    private func infoRow(_ title: String, _ value: String, id: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
                .accessibilityIdentifier(id)
        }
    }
}
