import SwiftUI

/// Shows the saved equipment and opens the wizard to set it up or change it.
struct EquipmentOverviewView: View {
    let store: EquipmentStore
    @State private var showWizard = false

    var body: some View {
        let lines = store.equipment.lines
        Form {
            Section("Deine Backutensilien") {
                if lines.isEmpty {
                    Text(store.isConfigured ? "Du hast keine Utensilien angegeben."
                                            : "Noch nichts eingerichtet.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("equipment-empty")
                } else {
                    ForEach(lines) { line in
                        Text(line.text)
                            .accessibilityIdentifier("equipment-\(line.id)")
                    }
                }
            }
            Section {
                Button(store.isConfigured ? "Ändern" : "Einrichten") { showWizard = true }
                    .accessibilityIdentifier("equipment-edit")
            }
        }
        .navigationTitle("Backutensilien")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWizard) {
            EquipmentWizardView(starting: store.equipment) { store.save($0) }
        }
    }
}

#Preview {
    NavigationStack {
        EquipmentOverviewView(
            store: EquipmentStore(defaults: UserDefaults(suiteName: "preview") ?? .standard))
    }
}
