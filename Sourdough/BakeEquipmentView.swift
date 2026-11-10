import SwiftUI
import SourdoughKit

/// Planning a bake, step two: the equipment, the amount of dough it takes and
/// the recipe in grams.
struct BakeEquipmentView: View {
    let model: BakePlanModel
    let equipmentStore: EquipmentStore
    let starterStore: StarterStore
    let kitchenStore: KitchenStore
    let now: Date
    let onStart: (BakeRun) -> Void

    @State private var linkedTip: TipsTopic.ID?

    private var items: [EquipmentItem] { equipmentStore.items }

    var body: some View {
        let issues = model.issues(starters: starterStore.starters)
        Form {
            if !issues.isEmpty {
                Section {
                    ForEach(Array(issues.enumerated()), id: \.offset) { index, issue in
                        HStack {
                            Text(BakeText.issue(issue, bread: model.bread))
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("setup-issue-\(index)")
                            if issue == .tooMuchRyeToStandFree {
                                TipsIconButton(topic: .freeStanding, identifier: "setup-issue-tip-\(index)")
                                    .padding(.leading, 8)
                            }
                        }
                    }
                }
            }
            if let setup = model.setup {
                vesselSection(setup)
                amountSection(setup)
            }
            if let recipe = model.recipe(starters: starterStore.starters) {
                recipeSections(recipe)
            }
            Section {
                NavigationLink("Weiter: Zeitplan") {
                    BakeScheduleView(model: model, starterStore: starterStore, kitchenStore: kitchenStore,
                                     now: now, onStart: onStart)
                }
                .accessibilityIdentifier("setup-next")
            }
        }
        .navigationTitle("Utensilien und Menge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { TipsButton(topic: model.setup?.vessel == .loafPan ? .pan : .pot) }
        // The links of the footer open their page over this screen.
        .environment(\.openURL, OpenURLAction { TipsText.open($0) { linkedTip = $0 } })
        .sheet(item: $linkedTip) { TipsView(initial: $0) }
        .onAppear { model.proposeSetup(from: items) }
    }

    /// The vessels the user can bake in: those they have, and the tray.
    private var vessels: [BakeSetup.Vessel] {
        BakeSetup.Vessel.allCases.filter { vessel in
            switch vessel {
            case .loafPan: items.contains { $0.kind == .pan }
            case .pot: items.contains { $0.kind == .pot }
            case .tray: true
            }
        }
    }

    private func vesselSection(_ setup: BakeSetup) -> some View {
        Section {
            Picker("Backen in", selection: Binding(
                get: { setup.vessel },
                set: { model.chooseVessel($0, from: items) })) {
                ForEach(vessels, id: \.self) { Text($0.germanName).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("setup-vessel")
            switch setup.vessel {
            case .loafPan:
                itemPicker("Kastenform", kind: .pan, selection: setup.pan, none: nil, id: "setup-pan") { item in
                    model.changeSetup { $0.pan = item }
                }
            case .pot:
                itemPicker("Bräter", kind: .pot, selection: setup.pot, none: nil, id: "setup-pot") { item in
                    model.changeSetup { $0.pot = item }
                }
            case .tray:
                EmptyView()
            }
            if setup.vessel.isFreeStanding {
                itemPicker("Gare im", kind: .basket, selection: setup.basket, none: "Schüssel",
                           id: "setup-basket") { item in
                    model.changeSetup { $0.basket = item }
                }
            }
            itemPicker("Kneten", kind: .kneader, selection: setup.kneader, none: "von Hand",
                       id: "setup-kneader") { item in
                model.changeSetup { $0.kneader = item }
            }
        } header: {
            Text("Backweg")
        } footer: {
            Text(TipsText.attributed(setup.vessel.isFreeStanding
                 ? "[Freigeschoben](tip:freeStanding) hält ein Brot bis etwa \(BakeText.percent(BakeRules.freeStandingRyeMax)) Roggen seine Form."
                 : "In der Kastenform gärt und backt der Teig."))
        }
    }

    /// A picker over the pieces of `kind`; `none` names the choice of none
    /// (`nil`: there is no such choice).
    private func itemPicker(_ title: String, kind: EquipmentKind, selection: EquipmentItem?, none: String?,
                            id: String, choose: @escaping (EquipmentItem?) -> Void) -> some View {
        Picker(title, selection: Binding(
            get: { selection?.id },
            set: { new in choose(items.first { $0.id == new }) })) {
            if let none {
                Text(none).tag(EquipmentItem.ID?.none)
            }
            ForEach(items.filter { $0.kind == kind }) { item in
                Text(item.name).tag(EquipmentItem.ID?.some(item.id))
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier(id)
    }

    private func amountSection(_ setup: BakeSetup) -> some View {
        Section {
            LabeledContent("Teig") {
                Text(BakeText.grams(DoughAmount.grams(for: setup)))
                    .accessibilityIdentifier("setup-dough")
            }
            if let total = model.totalGrams {
                LabeledContent("Mehl gesamt") {
                    Text(BakeText.grams(total))
                        .accessibilityIdentifier("setup-flour")
                }
            }
        } header: {
            Text("Menge")
        } footer: {
            Text(BakeText.doughSource(setup))
                .accessibilityIdentifier("setup-dough-source")
        }
    }

    @ViewBuilder
    private func recipeSections(_ recipe: Recipe) -> some View {
        Section {
            ForEach(recipe.sourdoughFlour, id: \.flour) { portion in
                amountRow(portion.flour.germanName, portion.grams, id: "recipe-sour-\(portion.flour.rawValue)")
            }
            amountRow("Wasser", recipe.sourdoughWater, id: "recipe-sour-water")
            amountRow("Anstellgut", recipe.starterGrams, id: "recipe-starter")
        } header: {
            Text("Sauerteigstufe")
        } footer: {
            Text("Zusammen \(BakeText.grams(recipe.sourdoughGrams)).")
                .accessibilityIdentifier("recipe-sourdough")
        }
        if !recipe.soaked.isEmpty {
            Section {
                ForEach(recipe.soaked, id: \.addIn) { portion in
                    LabeledContent(portion.addIn.germanName) {
                        Text(BakeText.soakAmount(portion))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("recipe-soak-\(portion.addIn.rawValue)")
                }
            } header: {
                Text("Einweichen")
            } footer: {
                Text("Zusammen mit der Sauerteigstufe ansetzen.")
            }
        }
        Section("Hauptteig") {
            ForEach(recipe.mainFlour, id: \.flour) { portion in
                amountRow(portion.flour.germanName, portion.grams, id: "recipe-main-\(portion.flour.rawValue)")
            }
            amountRow("Wasser", recipe.mainWater, id: "recipe-main-water")
            amountRow("Salz", recipe.salt, id: "recipe-salt")
            ForEach(recipe.addIns, id: \.addIn) { portion in
                amountRow(portion.addIn.germanName, portion.grams, id: "recipe-addin-\(portion.addIn.rawValue)")
            }
        }
    }

    private func amountRow(_ title: String, _ grams: Double, id: String) -> some View {
        LabeledContent(title) {
            Text(BakeText.grams(grams))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}

#Preview {
    let defaults = UserDefaults(suiteName: "preview") ?? .standard
    NavigationStack {
        BakeEquipmentView(model: BakePlanModel(), equipmentStore: EquipmentStore(defaults: defaults),
                          starterStore: StarterStore(defaults: defaults), kitchenStore: KitchenStore(defaults: defaults),
                          now: Date()) { _ in }
    }
}
