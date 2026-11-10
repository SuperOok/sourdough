import SwiftUI
import SourdoughKit

/// All starters with their state, and the way to add one.
struct StarterListView: View {
    let store: StarterStore
    let kitchenStore: KitchenStore
    @State private var showAdd = false
    @State private var now = Date()

    var body: some View {
        List {
            if store.starters.isEmpty {
                Text("Du hast noch keinen Starter angelegt.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("starters-empty")
            } else {
                ForEach(store.starters) { starter in
                    row(starter, now: now)
                }
            }
        }
        .refreshing($now)
        .navigationTitle("Sauerteigstarter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                TipsButton(topic: .starter)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: {
                    Label("Starter hinzufügen", systemImage: "plus")
                }
                .accessibilityIdentifier("starter-add")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddStarterView(temperatures: kitchenStore.temperatures) { starter in
                store.add(starter)
                kitchenStore.remember(starter)
            }
        }
    }

    private func row(_ starter: Starter, now: Date) -> some View {
        let summary = StarterSummary(starter, now: now)
        // A link with its destination: the start screen's path holds its own
        // destinations, not ids.
        return NavigationLink {
            StarterDetailView(store: store, kitchenStore: kitchenStore, id: starter.id)
        } label: {
            HStack(spacing: 12) {
                CustomIcon(name: IngredientIcon.name(starter.flour))
                VStack(alignment: .leading, spacing: 2) {
                    Text(starter.name).font(.headline)
                    Text("\(starter.flour.germanName) · \(summary.stateTitle)")
                    Text("Füttern oder verwenden bis \(summary.feedBy)")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("starter-row-\(starter.name)")
    }
}

#Preview {
    NavigationStack {
        StarterListView(store: StarterStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
                        kitchenStore: KitchenStore(defaults: UserDefaults(suiteName: "preview") ?? .standard))
    }
}
