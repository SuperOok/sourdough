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
            // Also before the first piece: then every kind is missing.
            if !store.missingKinds.isEmpty {
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
                        Button { editor = .add(kind) } label: {
                            Label(kind.germanName, image: EquipmentIcon.name(for: kind))
                        }
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

    /// A piece: tapping the text edits it, the symbols lead to its tips and
    /// to a new piece of the same kind.
    private func row(_ item: EquipmentItem) -> some View {
        HStack {
            Button { editor = .edit(item) } label: {
                HStack(spacing: 12) {
                    CustomIcon(name: EquipmentIcon.name(item))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.headline)
                        Text(item.detailText).font(.footnote).foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .accessibilityIdentifier("equipment-row-\(item.name)")
            TipsIconButton(topic: item.kind.tip, identifier: "equipment-tip-\(item.name)")
            addButton(item.kind, identifier: "equipment-plus-\(item.name)")
        }
    }

    private func missingRow(_ kind: EquipmentKind) -> some View {
        HStack(spacing: 12) {
            CustomIcon(name: EquipmentIcon.name(for: kind))
                .accessibilityHidden(true)
            Text(kind.germanName)
                .accessibilityIdentifier("missing-\(kind.rawValue)")
            Spacer()
            TipsIconButton(topic: kind.tip, identifier: "missing-tip-\(kind.rawValue)")
            addButton(kind, identifier: "missing-add-\(kind.rawValue)")
        }
    }

    /// Opens the form for a new piece of `kind`.
    private func addButton(_ kind: EquipmentKind, identifier: String) -> some View {
        Button { editor = .add(kind) } label: {
            Image(systemName: "plus.circle")
        }
        // Without this a whole list row would be the button.
        .buttonStyle(.borderless)
        .padding(.leading, 8)
        .accessibilityLabel("\(kind.germanName) hinzufügen")
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    NavigationStack {
        EquipmentOverviewView(
            store: EquipmentStore(defaults: UserDefaults(suiteName: "preview") ?? .standard))
    }
}
