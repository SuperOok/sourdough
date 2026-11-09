import SwiftUI
import SourdoughKit

/// The start screen: a hero picture and the ways into the app.
struct StartView: View {
    let store: EquipmentStore
    let starterStore: StarterStore
    let kitchenStore: KitchenStore
    let runStore: BakeRunStore
    /// "Now" for planning a bake; `nil` is the real time.
    var now: Date?
    @State private var showTips = false
    @State private var path: [Destination] = []

    enum Destination: Hashable {
        case bake, run(BakeRun.ID), log, equipment, starters
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    if let active = runStore.active {
                        option("Brot backen", subtitle: "Läuft: \(active.bread.germanName)",
                               symbol: "birthday.cake", destination: .run(active.id), id: "start-bake")
                    } else {
                        option("Brot backen", subtitle: "Brot planen, Mengen und Zeitplan",
                               symbol: "birthday.cake", destination: .bake, id: "start-bake")
                    }
                    option("Backprotokoll", subtitle: runStore.startSubtitle,
                           symbol: "book", destination: .log, id: "start-log")
                    option("Meine Backutensilien", subtitle: store.startSubtitle,
                           symbol: "frying.pan", destination: .equipment, id: "start-equipment")
                    option("Sauerteigstarter", subtitle: starterStore.startSubtitle,
                           symbol: "drop", destination: .starters, id: "start-starters")
                    Button { showTips = true } label: {
                        card("Tipps und Tricks", subtitle: "Hilfe zu Utensilien und mehr",
                             symbol: "lightbulb")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("start-tips")
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("Sourdough")
            // Back into the bake in progress when the app starts.
            .task {
                if let active = runStore.active, path.isEmpty { path = [.run(active.id)] }
            }
            .sheet(isPresented: $showTips) { TipsView(initial: nil) }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .bake:
                    BakePlanView(starterStore: starterStore, equipmentStore: store,
                                 kitchenStore: kitchenStore, now: now ?? Date()) { run in
                        runStore.start(run)
                        path = [.run(run.id)]
                    }
                case .run(let id):
                    BakeRunView(store: runStore, id: id) { path = [] }
                case .log:
                    BakeLogView(store: runStore)
                case .equipment: EquipmentOverviewView(store: store)
                case .starters: StarterListView(store: starterStore, kitchenStore: kitchenStore)
                }
            }
        }
    }

    /// Placeholder for a picture of a sourdough loaf.
    private var hero: some View {
        ZStack {
            LinearGradient(colors: [.orange.opacity(0.7), .brown.opacity(0.8)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                Text("Hier kommt ein Foto von einem Sauerteigbrot hin")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding()
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Platzhalter für ein Foto von einem Sauerteigbrot")
        .accessibilityIdentifier("start-hero")
    }

    private func option(_ title: String, subtitle: String, symbol: String,
                        destination: Destination, id: String) -> some View {
        NavigationLink(value: destination) {
            card(title, subtitle: subtitle, symbol: symbol)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func card(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    StartView(store: EquipmentStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
              starterStore: StarterStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
              kitchenStore: KitchenStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
              runStore: BakeRunStore(directory: URL.temporaryDirectory.appendingPathComponent("preview")))
}
