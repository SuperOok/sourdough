import SwiftUI
import SourdoughKit

/// Four steps, one question each. Nothing is saved before "Speichern";
/// "Abbrechen" throws the draft away.
struct EquipmentWizardView: View {
    @State private var model: EquipmentWizardModel
    private let onSave: (Equipment) -> Void
    @Environment(\.dismiss) private var dismiss

    init(starting equipment: Equipment, onSave: @escaping (Equipment) -> Void) {
        _model = State(initialValue: EquipmentWizardModel(starting: equipment))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(model.progressText) {
                    stepContent
                }
            }
            .navigationTitle(model.step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .accessibilityIdentifier("wizard-cancel")
                }
                ToolbarItem(placement: .primaryAction) {
                    TipsButton(topic: model.step.tip, identifier: "wizard-tips")
                }
            }
            .safeAreaInset(edge: .bottom) { navigation }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .kneader:
            Toggle("Küchenmaschine mit Knetfunktion", isOn: $model.draft.hasKneadingMachine)
                .accessibilityIdentifier("toggle-kneader")
        case .pot:
            Toggle("Ich habe einen Bräter oder Römertopf", isOn: $model.hasPot)
                .accessibilityIdentifier("toggle-pot")
            if model.hasPot {
                Toggle("Mit Silikoneinlage", isOn: $model.potHasLiner)
                    .accessibilityIdentifier("toggle-pot-liner")
            }
        case .loafPan:
            Toggle("Ich habe eine Kastenform", isOn: $model.hasLoafPan)
                .accessibilityIdentifier("toggle-pan")
            if model.hasLoafPan {
                Picker("Material", selection: $model.panMaterial) {
                    ForEach(Equipment.LoafPan.Material.allCases, id: \.self) { material in
                        Text(material.germanName).tag(material)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("pan-material")
                Toggle("Mit Deckel", isOn: $model.panHasLid)
                    .accessibilityIdentifier("toggle-pan-lid")
                Toggle("Mit Silikoneinlage", isOn: $model.panHasLiner)
                    .accessibilityIdentifier("toggle-pan-liner")
            }
        case .basket:
            Toggle("Ich habe ein Gärkörbchen", isOn: $model.draft.hasProvingBasket)
                .accessibilityIdentifier("toggle-basket")
        }
    }

    private var navigation: some View {
        HStack {
            Button("Zurück") { model.back() }
                .disabled(model.isFirstStep)
                .accessibilityIdentifier("wizard-back")
            Spacer()
            if model.isLastStep {
                Button("Speichern") {
                    onSave(model.draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("wizard-save")
            } else {
                Button("Weiter") { model.next() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("wizard-next")
            }
        }
        .padding()
        .background(.bar)
    }
}

#Preview {
    EquipmentWizardView(starting: Equipment()) { _ in }
}
