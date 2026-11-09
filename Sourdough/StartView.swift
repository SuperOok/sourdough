import SwiftUI

/// The start screen: a hero picture and the ways into the app.
struct StartView: View {
    let store: EquipmentStore
    let starterStore: StarterStore
    @State private var showTips = false

    enum Destination: Hashable {
        case equipment, starters
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hero
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
            .sheet(isPresented: $showTips) { TipsView(initial: nil) }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .equipment: EquipmentOverviewView(store: store)
                case .starters: StarterListView(store: starterStore)
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
              starterStore: StarterStore(defaults: UserDefaults(suiteName: "preview") ?? .standard))
}
