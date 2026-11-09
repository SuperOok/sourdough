import SwiftUI
import SourdoughKit

/// The saved equipment as a list, and the way to add, change and remove
/// pieces. Below it, the kinds the user has nothing of yet.
struct EquipmentOverviewView: View {
    let store: EquipmentStore
    @State private var editor: EquipmentEditor?

    var body: some View {
        List {
            Section("Deine Backutensilien") {
                if store.items.isEmpty {
                    Text("Noch keine Utensilien angelegt.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("equipment-empty")
                } else {
                    ForEach(store.items) { row($0) }
                }
            }
            // Before the first piece nothing is known to be missing.
            if !store.items.isEmpty && !store.missingKinds.isEmpty {
                Section("Nicht vorhanden, aber sinnvoll") {
                    ForEach(store.missingKinds, id: \.self) { missingRow($0) }
                }
            }
        }
        .navigationTitle("Backutensilien")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { TipsButton() }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(EquipmentKind.allCases, id: \.self) { kind in
                        Button(kind.germanName) { editor = .add(kind) }
                            .accessibilityIdentifier("equipment-add-\(kind.rawValue)")
                    }
                } label: {
                    Label("Utensil hinzufügen", systemImage: "plus")
                }
                .accessibilityIdentifier("equipment-add")
            }
        }
        .sheet(item: $editor) { editor in
            switch editor {
            case .add:
                EquipmentFormView(editor: editor) { store.add($0) }
            case .edit(let item):
                EquipmentFormView(editor: editor, onSave: { store.update($0) },
                                  onDelete: { store.remove(item.id) })
            }
        }
    }

    /// A piece: tapping the text edits it, the symbol leads to its tips.
    private func row(_ item: EquipmentItem) -> some View {
        HStack {
            Button { editor = .edit(item) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.headline)
                    Text(item.detailText).font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .accessibilityIdentifier("equipment-row-\(item.name)")
            TipsIconButton(topic: item.kind.tip, identifier: "equipment-tip-\(item.name)")
        }
    }

    private func missingRow(_ kind: EquipmentKind) -> some View {
        HStack {
            Text(kind.germanName)
                .accessibilityIdentifier("missing-\(kind.rawValue)")
            Spacer()
            TipsIconButton(topic: kind.tip, identifier: "missing-tip-\(kind.rawValue)")
        }
    }
}

#Preview {
    NavigationStack {
        EquipmentOverviewView(
            store: EquipmentStore(defaults: UserDefaults(suiteName: "preview") ?? .standard))
    }
}
