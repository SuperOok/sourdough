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
            NumberForm(fields: model.fields) { focus in
                Section {
                    // A menu: three long segments do not fit on 393 pt.
                    Picker("Wie entsteht er?", selection: $model.origin) {
                        ForEach(StarterOrigin.allCases, id: \.self) { origin in
                            Text(origin.title).tag(origin)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("add-origin")
                }
                Section("Sauerteig") {
                    // Labelled, so that it reads as a field for the name; the grey
                    // placeholder is the name the starter gets without one.
                    LabeledContent("Name") {
                        TextField(model.flour.starterName, text: $model.name)
                            .inputBox()
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
                    if model.origin != .existing {
                        DatePicker("Angesetzt am", selection: $model.createdAt, in: ...Date(),
                                   displayedComponents: [.date, .hourAndMinute])
                            .accessibilityIdentifier("add-date")
                    }
                }
                switch model.origin {
                case .existing: existingSection(focus)
                case .inoculated, .spontaneous: mixSection(focus)
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
                    if let error = model.storageError {
                        errorFooter(error)
                    } else if let hint = model.coldHint {
                        Text(hint).accessibilityIdentifier("add-cold-hint")
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

    /// A starter that lives already: when it was fed last, and how much there is.
    private func existingSection(_ focus: FocusState<String?>.Binding) -> some View {
        Section {
            Toggle("Letzte Fütterung bekannt", isOn: $model.lastFeedingKnown)
                .accessibilityIdentifier("add-known")
            if model.lastFeedingKnown {
                DatePicker("Zuletzt gefüttert am", selection: $model.lastFedAt, in: ...Date(),
                           displayedComponents: [.date, .hourAndMinute])
                    .accessibilityIdentifier("add-last-fed")
                NumberField(title: "Menge (g)", text: $model.amountText, id: "add-amount", focus: focus)
            }
        } header: {
            Text("Letzte Fütterung")
        } footer: {
            if let error = model.amountError {
                errorFooter(error)
            } else {
                Text(model.lastFeedingKnown
                     ? "Ungefähr reicht. Die App rechnet mit einer Fütterung im Verhältnis 1 : 1 : 1."
                     : "Bis zu deiner ersten Fütterung schätzt die App keinen Zustand.")
                    .accessibilityIdentifier("add-known-hint")
            }
        }
    }

    /// A fresh mix: the sample (with one), flour and water.
    private func mixSection(_ focus: FocusState<String?>.Binding) -> some View {
        Section {
            if model.origin == .inoculated {
                NumberField(title: "Anstellgut (g)", text: $model.sampleText, id: "add-sample", focus: focus)
            }
            NumberField(title: "Mehl (g)", text: $model.flourText, id: "add-flour-grams", focus: focus)
            NumberField(title: "Wasser (g)", text: $model.waterText, id: "add-water-grams", focus: focus)
            if model.origin == .spontaneous {
                HStack {
                    Text("So gelingt der Ansatz")
                    Spacer()
                    TipsIconButton(topic: .starterFromScratch, identifier: "add-scratch-tip")
                }
            }
        } header: {
            Text("Erste Fütterung")
        } footer: {
            if let error = model.foodError { errorFooter(error) }
        }
    }
}

extension AddStarterView {
    /// A message below the fields it is about. Above the form it would move
    /// the fields while typing and take the focus away.
    func errorFooter(_ error: String) -> some View {
        Text(error).foregroundStyle(.red)
            .accessibilityIdentifier("add-error")
    }
}

/// The sheet for a feeding.
struct FeedView: View {
    @State private var model: FeedFormModel
    private let onSave: (Feeding) -> Void
    @Environment(\.dismiss) private var dismiss

    /// The name of the starter that is fed, shown above the fields.
    private let starterName: String

    init(starterName: String, previous: Feeding?, asksRise: Bool = false, onSave: @escaping (Feeding) -> Void) {
        _model = State(initialValue: FeedFormModel(previous: previous, asksRise: asksRise))
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
                    if let error = model.amountError {
                        Text(error).foregroundStyle(.red)
                            .accessibilityIdentifier("feed-error")
                    }
                }
                if model.asksRise {
                    Section {
                        Picker("Aufgegangen", selection: $model.rise) {
                            ForEach(Rise.allCases, id: \.self) { rise in
                                Text(rise.title).tag(Optional(rise))
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("feed-rise")
                    } header: {
                        Text("Seit der letzten Fütterung")
                    } footer: {
                        Text(model.riseError ?? "Nach zwei Mal „Verdoppelt“ hintereinander ist er bereit.")
                            .accessibilityIdentifier("feed-rise-hint")
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
