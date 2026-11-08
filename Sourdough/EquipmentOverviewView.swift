import SwiftUI

/// Shows the saved equipment and opens the wizard to set it up or change it.
struct EquipmentOverviewView: View {
    let store: EquipmentStore
    @State private var showWizard = false

    var body: some View {
        let lines = store.equipment.lines
        let missing = store.equipment.missingLines
        Form {
            Section("Deine Backutensilien") {
                if lines.isEmpty {
                    Text(store.isConfigured ? "Du hast keine Utensilien angegeben."
                                            : "Noch nichts eingerichtet.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("equipment-empty")
                } else {
                    ForEach(lines) { row($0, prefix: "equipment") }
                }
            }
            // Before the first setup nothing is known to be missing.
            if store.isConfigured && !missing.isEmpty {
                Section("Nicht vorhanden, aber sinnvoll") {
                    ForEach(missing) { row($0, prefix: "missing") }
                }
            }
            Section {
                Button(store.isConfigured ? "Ändern" : "Einrichten") { showWizard = true }
                    .accessibilityIdentifier("equipment-edit")
            }
        }
        .navigationTitle("Backutensilien")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { TipsButton() } }
        .sheet(isPresented: $showWizard) {
            EquipmentWizardView(starting: store.equipment) { store.save($0) }
        }
    }
}

extension EquipmentOverviewView {
    /// An item with the symbol that leads to its tips page.
    fileprivate func row(_ line: EquipmentLine, prefix: String) -> some View {
        HStack {
            Text(line.text)
                .accessibilityIdentifier("\(prefix)-\(line.id)")
            Spacer()
            TipsIconButton(topic: line.topic, identifier: "\(prefix)-tip-\(line.id)")
        }
    }
}

#Preview {
    NavigationStack {
        EquipmentOverviewView(
            store: EquipmentStore(defaults: UserDefaults(suiteName: "preview") ?? .standard))
    }
}
