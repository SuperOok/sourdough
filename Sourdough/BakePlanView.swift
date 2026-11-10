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
        NumberForm(fields: ["plan-total"]) { focus in
            if !issues.isEmpty {
                Section {
                    ForEach(Array(issues.enumerated()), id: \.offset) { index, issue in
                        Text(BakeText.issue(issue, bread: model.bread))
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("plan-issue-\(index)")
                    }
                }
            }
            breadSection
            starterSection
            flourSection(focus)
            addInSection
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
                        Label("\(starter.name) (\(starter.flour.germanName))",
                              image: IngredientIcon.name(starter.flour))
                            .tag(Starter.ID?.some(starter.id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("plan-starter")
            }
        } footer: {
            Text("Ab \(BakeText.percent(BakeRules.ryeStarterFrom)) Roggen braucht der Teig einen Roggensauerteig.")
        }
    }

    private func flourSection(_ focus: FocusState<String?>.Binding) -> some View {
        Section {
            NumberField(title: "Mehl gesamt (g)", text: $model.totalText, id: "plan-total", focus: focus)
            ForEach(model.effectiveMix.flours, id: \.self) { flour in
                HStack {
                    Button { editing = EditedFlour(flour: flour) } label: { flourRow(flour) }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("plan-flour-\(flour.rawValue)")
                    TipsIconButton(topic: TipsTopic.id(for: flour.grain),
                                   identifier: "plan-flour-tip-\(flour.rawValue)")
                        .padding(.leading, 8)
                }
            }
            Menu {
                ForEach(model.addableFlours, id: \.self) { flour in
                    Button { model.add(flour) } label: {
                        Label(flour.germanName, image: IngredientIcon.name(flour))
                    }
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
            // Below the field, not above the form: a section appearing above
            // while typing moves the form and takes the focus away.
            VStack(alignment: .leading, spacing: 4) {
                if let error = model.errorText {
                    Text(error)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("plan-error")
                }
                Text(BakeText.mixSummary(model.effectiveMix, bread: model.bread))
                    .accessibilityIdentifier("plan-mix-summary")
            }
        }
    }

    /// Seeds, nuts and the like, each with its share of the flour.
    private var addInSection: some View {
        Section {
            ForEach(model.addIns.addIns, id: \.self) { addIn in
                addInRow(addIn)
            }
            if !model.addIns.addable.isEmpty {
                Menu {
                    ForEach(model.addIns.addable, id: \.self) { addIn in
                        Button { model.addIns.add(addIn) } label: {
                            Label(addIn.germanName, image: IngredientIcon.name(addIn))
                        }
                            .accessibilityIdentifier("plan-add-addin-\(addIn.rawValue)")
                    }
                } label: {
                    Label("Zusatz hinzufügen", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("plan-add-addin")
            }
        } header: {
            Text("Zusätze")
        } footer: {
            Text("Anteile vom Mehl. Wasser zum Einweichen rechnet die App zur Teigmenge dazu.")
        }
    }

    private func addInRow(_ addIn: AddIn) -> some View {
        let share = model.addIns.share(of: addIn)
        return HStack {
            CustomIcon(name: IngredientIcon.name(addIn))
                .padding(.trailing, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(addIn.germanName)
                Text(BakeText.addInAmount(share: share, totalGrams: model.totalGrams))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("plan-addin-\(addIn.rawValue)")
            Spacer()
            Stepper("Anteil", value: Binding(get: { share }, set: { model.addIns.set(addIn, to: $0) }),
                    in: addIn.shareRange, step: 1)
                .labelsHidden()
                .accessibilityIdentifier("plan-addin-stepper-\(addIn.rawValue)")
            TipsIconButton(topic: TipsTopic.id(for: addIn), identifier: "plan-addin-tip-\(addIn.rawValue)")
                .padding(.leading, 8)
        }
        .swipeActions {
            Button("Entfernen", role: .destructive) { model.addIns.remove(addIn) }
                .accessibilityIdentifier("plan-addin-remove-\(addIn.rawValue)")
        }
    }

    private func flourRow(_ flour: Flour) -> some View {
        HStack {
            CustomIcon(name: IngredientIcon.name(flour))
                .padding(.trailing, 4)
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
            NumberForm(fields: ["flour-limit"]) { focus in
                Section("Mehlsorte") {
                    Picker("Mehl", selection: Binding(
                        get: { flour },
                        set: { new in
                            model.replace(flour, with: new)
                            flour = new
                        })) {
                        ForEach(Flour.allCases, id: \.self) {
                            Label($0.germanName, image: IngredientIcon.name($0)).tag($0)
                        }
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
                        set: { model.setLimitText(flour, $0) }), id: "flour-limit", focus: focus)
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
                ToolbarItem(placement: .primaryAction) {
                    TipsButton(topic: TipsTopic.id(for: flour.grain), identifier: "flour-tips")
                }
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
