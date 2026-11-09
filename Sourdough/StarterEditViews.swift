import SwiftUI
import SourdoughKit
// UIKit only for `UITextField`: SwiftUI cannot select a field's text.
import UIKit

/// A labelled field for a number of grams or degrees.
struct NumberField: View {
    let title: String
    @Binding var text: String
    let id: String
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent(title) {
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .accessibilityIdentifier(id)
                // Tapping a number selects all of it, so typing replaces it.
                .onReceive(NotificationCenter.default.publisher(
                    for: UITextField.textDidBeginEditingNotification)) { note in
                    DispatchQueue.main.async { (note.object as? UITextField)?.selectAll(nil) }
                }
        }
        // The decimal pad has no return key and covers the fields below.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focused {
                    Spacer()
                    Button("Fertig") { focused = false }
                        .accessibilityIdentifier("keyboard-done")
                }
            }
        }
    }
}

/// The sheet for a new starter.
struct AddStarterView: View {
    @State private var model = StarterFormModel()
    let onSave: (Starter) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let error = model.errorText {
                    Section {
                        Text(error).foregroundStyle(.red)
                            .accessibilityIdentifier("add-error")
                    }
                }
                Section("Sauerteig") {
                    TextField(model.flour.starterName, text: $model.name)
                        .accessibilityIdentifier("add-name")
                    Picker("Mehl", selection: $model.flour) {
                        ForEach(FlourType.allCases, id: \.self) { flour in
                            Text(flour.germanName).tag(flour)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("add-flour")
                    DatePicker("Angesetzt am", selection: $model.createdAt, in: ...Date(),
                               displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("add-date")
                }
                Section("Erste Fütterung") {
                    NumberField(title: "Mehl (g)", text: $model.flourText, id: "add-flour-grams")
                    NumberField(title: "Wasser (g)", text: $model.waterText, id: "add-water-grams")
                }
                Section("Aufbewahrung") {
                    Picker("Ort", selection: $model.inFridge) {
                        Text("Raumtemperatur").tag(false)
                        Text("Kühlschrank").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("add-storage")
                    if model.inFridge {
                        NumberField(title: "Kühlschranktemperatur (°C)", text: $model.fridgeText,
                                    id: "add-fridge-temp")
                    }
                }
            }
            .navigationTitle("Neuer Starter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .accessibilityIdentifier("add-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        if let starter = model.makeStarter() { onSave(starter) }
                        dismiss()
                    }
                    .disabled(!model.isValid)
                    .accessibilityIdentifier("add-save")
                }
            }
        }
    }
}

/// The sheet for a feeding.
struct FeedView: View {
    @State private var model: FeedFormModel
    private let onSave: (Feeding) -> Void
    @Environment(\.dismiss) private var dismiss

    init(previous: Feeding?, onSave: @escaping (Feeding) -> Void) {
        _model = State(initialValue: FeedFormModel(previous: previous))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error = model.errorText {
                    Section {
                        Text(error).foregroundStyle(.red)
                            .accessibilityIdentifier("feed-error")
                    }
                }
                Section("Was du zugibst") {
                    NumberField(title: "Behaltener Starter (g)", text: $model.starterText,
                                id: "feed-starter")
                    NumberField(title: "Mehl (g)", text: $model.flourText, id: "feed-flour")
                    NumberField(title: "Wasser (g)", text: $model.waterText, id: "feed-water")
                    DatePicker("Gefüttert am", selection: $model.date, in: ...Date(),
                               displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("feed-date")
                }
            }
            .navigationTitle("Füttern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .accessibilityIdentifier("feed-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        if let feeding = model.makeFeeding() { onSave(feeding) }
                        dismiss()
                    }
                    .disabled(!model.isValid)
                    .accessibilityIdentifier("feed-save")
                }
            }
        }
    }
}

#Preview {
    AddStarterView { _ in }
}
