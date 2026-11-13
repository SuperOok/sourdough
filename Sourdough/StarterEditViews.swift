import SwiftUI
import SourdoughKit

/// The sheet for a new starter.
struct AddStarterView: View {
    @State private var model: StarterFormModel
    let onSave: (Starter) -> Void
    @Environment(\.dismiss) private var dismiss

    init(temperatures: Temperatures, onSave: @escaping (Starter) -> Void) {
        _model = State(initialValue: StarterFormModel(temperatures: temperatures))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            NumberForm(fields: ["add-flour-grams", "add-water-grams",
                                model.inFridge ? "add-fridge-temp" : "add-room-temp"]) { focus in
                Section("Sauerteig") {
                    // Labelled, so that it reads as a field for the name; the grey
                    // placeholder is the name the starter gets without one.
                    LabeledContent("Name") {
                        TextField(model.flour.starterName, text: $model.name)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("add-name")
                    }
                    Picker("Mehl", selection: $model.flour) {
                        ForEach(FlourType.starterGrains, id: \.self) { flour in
                            Text(flour.germanName).tag(flour)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("add-flour")
                    DatePicker("Angesetzt am", selection: $model.createdAt, in: ...Date(),
                               displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("add-date")
                }
                Section {
                    NumberField(title: "Mehl (g)", text: $model.flourText, id: "add-flour-grams", focus: focus)
                    NumberField(title: "Wasser (g)", text: $model.waterText, id: "add-water-grams", focus: focus)
                } header: {
                    Text("Erste Fütterung")
                } footer: {
                    errorFooter(model.foodError)
                }
                Section {
                    Picker("Ort", selection: $model.inFridge) {
                        Text("Raumtemperatur").tag(false)
                        Text("Kühlschrank").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("add-storage")
                    if model.inFridge {
                        NumberField(title: "Kühlschranktemperatur (°C)", text: $model.fridgeText,
                                    id: "add-fridge-temp", focus: focus)
                    } else {
                        NumberField(title: "Raumtemperatur (°C)", text: $model.roomText,
                                    id: "add-room-temp", focus: focus)
                    }
                } header: {
                    Text("Aufbewahrung")
                } footer: {
                    errorFooter(model.storageError)
                }
            }
            .navigationTitle("Neuer Starter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .accessibilityIdentifier("add-cancel")
                }
                ToolbarItem(placement: .primaryAction) {
                    TipsButton(topic: .starterNew, identifier: "add-tips")
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

extension AddStarterView {
    /// A message below the fields it is about. Above the form it would move
    /// the fields while typing and take the focus away.
    @ViewBuilder
    func errorFooter(_ error: String?) -> some View {
        if let error {
            Text(error).foregroundStyle(.red)
                .accessibilityIdentifier("add-error")
        }
    }
}

/// The sheet for a feeding.
struct FeedView: View {
    @State private var model: FeedFormModel
    private let onSave: (Feeding) -> Void
    @Environment(\.dismiss) private var dismiss

    /// The name of the starter that is fed, shown above the fields.
    private let starterName: String

    init(starterName: String, previous: Feeding?, onSave: @escaping (Feeding) -> Void) {
        _model = State(initialValue: FeedFormModel(previous: previous))
        self.starterName = starterName
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            NumberForm(fields: ["feed-starter", "feed-flour", "feed-water"]) { focus in
                Section {
                    LabeledContent("Starter", value: starterName)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("feed-name")
                }
                Section {
                    NumberField(title: "Behaltener Starter (g)", text: $model.starterText,
                                id: "feed-starter", focus: focus)
                    NumberField(title: "Mehl (g)", text: $model.flourText, id: "feed-flour", focus: focus)
                    NumberField(title: "Wasser (g)", text: $model.waterText, id: "feed-water", focus: focus)
                    DatePicker("Gefüttert am", selection: $model.date, in: ...Date(),
                               displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("feed-date")
                } header: {
                    Text("Was du zugibst")
                } footer: {
                    if let error = model.errorText {
                        Text(error).foregroundStyle(.red)
                            .accessibilityIdentifier("feed-error")
                    }
                }
            }
            .navigationTitle("Füttern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .accessibilityIdentifier("feed-cancel")
                }
                ToolbarItem(placement: .primaryAction) {
                    TipsButton(topic: .starterFeed, identifier: "feed-tips")
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
    AddStarterView(temperatures: Temperatures()) { _ in }
}
