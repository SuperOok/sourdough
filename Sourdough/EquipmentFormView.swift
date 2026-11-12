import SwiftUI
import SourdoughKit

/// What the form sheet is for: a new piece of a kind, or an existing piece.
enum EquipmentEditor: Identifiable {
    case add(EquipmentKind)
    case edit(EquipmentItem)

    var id: String {
        switch self {
        case .add(let kind): "add-\(kind.rawValue)"
        case .edit(let item): "edit-\(item.id)"
        }
    }
}

/// The sheet to add a piece of equipment or to change one. `onDelete` is
/// given for an existing piece and adds the button to delete it.
struct EquipmentFormView: View {
    @State private var model: EquipmentFormModel
    private let onSave: (EquipmentItem) -> Void
    private let onDelete: (() -> Void)?
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss

    init(editor: EquipmentEditor, onSave: @escaping (EquipmentItem) -> Void,
         onDelete: (() -> Void)? = nil) {
        switch editor {
        case .add(let kind): _model = State(initialValue: EquipmentFormModel(kind: kind))
        case .edit(let item): _model = State(initialValue: EquipmentFormModel(editing: item))
        }
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            NumberForm(fields: model.sizeFields) { focus in
                Section("Name") {
                    HStack(spacing: 12) {
                        CustomIcon(name: model.iconName)
                            .accessibilityHidden(true)
                        TextField(model.kind.germanName, text: $model.name)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("item-name")
                    }
                }
                if model.kind.hasMaterial || model.kind.hasLid || model.kind.hasLiner {
                    Section("Ausführung") {
                        if model.kind.hasMaterial {
                            Picker("Material", selection: $model.material) {
                                ForEach(EquipmentItem.Material.allCases, id: \.self) { material in
                                    Text(material.germanName).tag(material)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("item-material")
                        }
                        if model.kind.hasLid {
                            Toggle("Mit Deckel", isOn: $model.hasLid)
                                .accessibilityIdentifier("item-lid")
                        }
                        if model.kind.hasLiner {
                            Toggle("Mit Silikoneinlage", isOn: $model.hasLiner)
                                .accessibilityIdentifier("item-liner")
                        }
                    }
                }
                if model.kind.hasDimensions { sizeSection(focus) }
                if model.kind.hasShape {
                    Section {
                        Picker("Form", selection: $model.basketShape) {
                            ForEach(Dimensions.Shape.allCases, id: \.self) { shape in
                                Text(shape.germanName).tag(shape)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("item-basket-shape")
                    } header: {
                        Text("Form")
                    } footer: {
                        Text("In ein rundes Körbchen kommt ein runder Laib, in ein ovales oder rechteckiges ein länglicher.")
                    }
                }
                if onDelete != nil {
                    Section {
                        Button("Utensil löschen", role: .destructive) { confirmDelete = true }
                            .accessibilityIdentifier("item-delete")
                    }
                }
            }
            .alert("Utensil löschen?", isPresented: $confirmDelete) {
                Button("Löschen", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("„\(model.resolvedName)“ wird gelöscht.")
            }
            .navigationTitle(model.kind.germanName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .accessibilityIdentifier("item-cancel")
                }
                ToolbarItem(placement: .primaryAction) {
                    TipsButton(topic: model.kind.tip, identifier: "item-tips")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        if let item = model.makeItem() { onSave(item) }
                        dismiss()
                    }
                    .disabled(!model.isValid)
                    .accessibilityIdentifier("item-save")
                }
            }
        }
    }

    private func sizeSection(_ focus: FocusState<String?>.Binding) -> some View {
        Section {
            Picker("Form", selection: $model.shape) {
                ForEach(Dimensions.Shape.allCases, id: \.self) { shape in
                    Text(shape.germanName).tag(shape)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("item-shape")
            let isRound = model.shape == .round
            NumberField(title: isRound ? "Durchmesser (cm)" : "Länge (cm)",
                        text: $model.lengthText, id: "item-length", focus: focus)
            if !isRound {
                NumberField(title: "Breite (cm)", text: $model.widthText, id: "item-width", focus: focus)
            }
            NumberField(title: "Höhe (cm)", text: $model.heightText, id: "item-height", focus: focus)
            if let volume = model.volumeText {
                HStack {
                    Text("Volumen")
                    Spacer()
                    Text(volume).foregroundStyle(.secondary)
                        .accessibilityIdentifier("item-volume")
                }
            }
        } header: {
            Text("Innenmaße (optional)")
        } footer: {
            // Messages stand below the fields: a section appearing above them
            // while typing moved the form and took the focus away.
            VStack(alignment: .leading, spacing: 4) {
                if let error = model.errorText {
                    Text(error).foregroundStyle(.red)
                        .accessibilityIdentifier("item-error")
                } else if let hint = model.hintText {
                    Text(hint).accessibilityIdentifier("item-error")
                }
                Text("Mit allen Maßen rechnet die App das Volumen aus.")
            }
        }
    }
}

#Preview {
    EquipmentFormView(editor: .add(.pan)) { _ in }
}
