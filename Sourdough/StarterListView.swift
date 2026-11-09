import SwiftUI
import SourdoughKit

/// All starters with their state, and the way to add one.
struct StarterListView: View {
    let store: StarterStore
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
        .navigationDestination(for: Starter.ID.self) { id in
            StarterDetailView(store: store, id: id)
        }
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
            AddStarterView { store.add($0) }
        }
    }

    private func row(_ starter: Starter, now: Date) -> some View {
        let summary = StarterSummary(starter, now: now)
        return NavigationLink(value: starter.id) {
            VStack(alignment: .leading, spacing: 2) {
                Text(starter.name).font(.headline)
                Text("\(starter.flour.germanName) · \(summary.stateTitle)")
                Text("Füttern oder verwenden bis \(summary.feedBy)")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("starter-row-\(starter.name)")
    }
}

#Preview {
    NavigationStack {
        StarterListView(store: StarterStore(defaults: UserDefaults(suiteName: "preview") ?? .standard))
    }
}
