import SwiftUI
import SourdoughKit

/// Planning a bake, step one: bread type, starter and flours.
struct BakePlanView: View {
    let starterStore: StarterStore
    let equipmentStore: EquipmentStore
    let kitchenStore: KitchenStore
    let now: Date
    /// Starts the bake.
    let onStart: (BakeRun) -> Void
    @State private var model = BakePlanModel()
    @State private var editing: EditedFlour?

    var body: some View {
        let issues = model.issues(starters: starterStore.starters)
        Form {
            if model.errorText != nil || !issues.isEmpty {
                Section {
                    if let error = model.errorText {
                        Text(error)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("plan-error")
                    }
                    ForEach(Array(issues.enumerated()), id: \.offset) { index, issue in
                        Text(BakeText.issue(issue, bread: model.bread))
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("plan-issue-\(index)")
                    }
                }
            }
            breadSection
            starterSection
            flourSection
            waterSection
            Section {
                NavigationLink("Weiter: Utensilien und Menge") {
                    BakeEquipmentView(model: model, equipmentStore: equipmentStore, starterStore: starterStore,
                                      kitchenStore: kitchenStore, now: now, onStart: onStart)
                }
                .disabled(model.errorText != nil)
                .accessibilityIdentifier("plan-next")
            }
        }
        .navigationTitle("Brot backen")
        .toolbar { TipsButton(topic: .flours) }
        .sheet(item: $editing) { edited in
            FlourEditView(model: model, flour: edited.flour)
        }
    }

    private var breadSection: some View {
        Section {
            Picker("Brotart", selection: $model.bread) {
                ForEach(BreadType.allCases, id: \.self) { bread in
                    Text(bread.germanName).tag(bread)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("plan-bread")
        } footer: {
            Text(model.bread.character)
                .accessibilityIdentifier("plan-bread-character")
        }
    }

    @ViewBuilder
    private var starterSection: some View {
        Section {
            if starterStore.starters.isEmpty {
                Text("Noch kein Starter angelegt.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("plan-no-starters")
            } else {
                Picker("Starter", selection: $model.starterID) {
                    Text("Bitte wählen").tag(Starter.ID?.none)
                    ForEach(starterStore.starters) { starter in
                        Text("\(starter.name) (\(starter.flour.germanName))").tag(Starter.ID?.some(starter.id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("plan-starter")
            }
        } footer: {
            Text("Ab \(BakeText.percent(BakeRules.ryeStarterFrom)) Roggen braucht der Teig einen Roggensauerteig.")
        }
    }

    private var flourSection: some View {
        Section {
            NumberField(title: "Mehl gesamt (g)", text: $model.totalText, id: "plan-total")
            ForEach(model.effectiveMix.flours, id: \.self) { flour in
                Button { editing = EditedFlour(flour: flour) } label: { flourRow(flour) }
                    .accessibilityIdentifier("plan-flour-\(flour.rawValue)")
            }
            Menu {
                ForEach(model.addableFlours, id: \.self) { flour in
                    Button(flour.germanName) { model.add(flour) }
                        .accessibilityIdentifier("plan-add-\(flour.rawValue)")
                }
            } label: {
                // The whole row opens the menu, not only its text.
                Label("Mehl hinzufügen", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("plan-add-flour")
        } header: {
            Text("Mehl")
        } footer: {
            Text(BakeText.mixSummary(model.effectiveMix, bread: model.bread))
                .accessibilityIdentifier("plan-mix-summary")
        }
    }

    private func flourRow(_ flour: Flour) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(flour.germanName)
                if let limit = model.limits[flour] {
                    Text("höchstens \(BakeText.grams(limit))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(BakeText.percent(model.effectiveMix.share(of: flour)))
            if let grams = model.grams(of: flour) {
                Text(BakeText.grams(grams))
                    .frame(minWidth: 64, alignment: .trailing)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
    }

    private var waterSection: some View {
        Section("Wasser") {
            LabeledContent("Hydration") {
                Text(BakeText.percent(model.hydration))
                    .accessibilityIdentifier("plan-hydration")
            }
            if let water = model.waterGrams {
                LabeledContent("Wasser") {
                    Text(BakeText.grams(water))
                        .accessibilityIdentifier("plan-water")
                }
            }
        }
    }
}

/// The flour the sheet opens with. The sheet keeps track of a replacement
/// itself, so the sheet's identity stays and it stays open.
struct EditedFlour: Identifiable {
    let id: UUID
    let flour: Flour

    init(flour: Flour) {
        id = UUID()
        self.flour = flour
    }
}

/// One flour of the plan: replace it, change its share, give it a limit.
struct FlourEditView: View {
    let model: BakePlanModel
    @State private var flour: Flour

    init(model: BakePlanModel, flour: Flour) {
        self.model = model
        _flour = State(initialValue: flour)
    }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let range = model.range(of: flour)
        let share = model.effectiveMix.share(of: flour)
        NavigationStack {
            Form {
                Section("Mehlsorte") {
                    Picker("Mehl", selection: Binding(
                        get: { flour },
                        set: { new in
                            model.replace(flour, with: new)
                            flour = new
                        })) {
                        ForEach(Flour.allCases, id: \.self) { Text($0.germanName).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("flour-kind")
                }
                Section {
                    LabeledContent("Anteil") {
                        Text(BakeText.percent(share))
                            .accessibilityIdentifier("flour-share")
                    }
                    if let range, range.lowerBound < range.upperBound {
                        Stepper("Anteil ändern",
                                onIncrement: { step(share.rounded(.down) + 1, in: range) },
                                onDecrement: { step(share.rounded(.up) - 1, in: range) })
                            .accessibilityIdentifier("flour-stepper")
                        Slider(value: Binding(
                            get: { min(max(share, range.lowerBound), range.upperBound) },
                            set: { model.setShare(flour, $0.rounded()) }),
                               in: range, step: 1)
                            .accessibilityIdentifier("flour-slider")
                    }
                } header: {
                    Text("Anteil")
                } footer: {
                    Text(range.map { "Möglich: \(BakeText.range($0))" }
                         ?? "Der Anteil lässt sich nicht ändern, ohne eine Regel zu verletzen.")
                        .accessibilityIdentifier("flour-range")
                }
                Section {
                    NumberField(title: "Höchstens (g)", text: Binding(
                        get: { model.limitText(flour) },
                        set: { model.setLimitText(flour, $0) }), id: "flour-limit")
                } header: {
                    Text("Grenze")
                } footer: {
                    Text("Wenn von diesem Mehl nur wenig da ist: Der Rest geht an die anderen Mehle.")
                }
                Section {
                    Button("Mehl entfernen", role: .destructive) {
                        model.remove(flour)
                        dismiss()
                    }
                    .disabled(range?.contains(0) != true)
                    .accessibilityIdentifier("flour-remove")
                }
            }
            .navigationTitle(flour.germanName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .accessibilityIdentifier("flour-done")
                }
            }
        }
    }

    private func step(_ target: Double, in range: ClosedRange<Double>) {
        model.setShare(flour, min(max(target, range.lowerBound), range.upperBound))
    }
}

#Preview {
    let defaults = UserDefaults(suiteName: "preview") ?? .standard
    NavigationStack {
        BakePlanView(starterStore: StarterStore(defaults: defaults), equipmentStore: EquipmentStore(defaults: defaults),
                     kitchenStore: KitchenStore(defaults: defaults), now: Date()) { _ in }
    }
}
