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
                    title
                    hero
                    if let active = runStore.active {
                        option("Brot backen", subtitle: "Läuft: \(active.bread.germanName)",
                               icon: CustomIcon(name: "BreadIcon"), destination: .run(active.id), id: "start-bake")
                    } else {
                        option("Brot backen", subtitle: "Brot planen, Mengen und Zeitplan",
                               icon: CustomIcon(name: "BreadIcon"), destination: .bake, id: "start-bake")
                    }
                    option("Backprotokoll", subtitle: runStore.startSubtitle,
                           icon: SystemIcon(name: "book"), destination: .log, id: "start-log")
                    option("Meine Backutensilien", subtitle: store.startSubtitle,
                           icon: CustomIcon(name: "PotIcon"), destination: .equipment, id: "start-equipment")
                    option("Sauerteigstarter", subtitle: starterStore.startSubtitle,
                           icon: SystemIcon(name: "drop"), destination: .starters, id: "start-starters")
                    Button { showTips = true } label: {
                        card("Tipps und Tricks", subtitle: "Hilfe zu Utensilien und mehr",
                             icon: SystemIcon(name: "lightbulb"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("start-tips")
                }
                .padding(.horizontal, 16)
            }
            // The headline below replaces the large title. The title stays
            // for the back button of the pages pushed from here.
            .navigationTitle("Sourdough")
            .toolbar(.hidden, for: .navigationBar)
            // The navigation bar is hidden and takes no toolbar items, so the
            // lightbulb sits in a bar of its own above the content: a safe-area
            // inset keeps the headline from running under it.
            .safeAreaInset(edge: .top) {
                HStack {
                    Spacer()
                    TipsButton(topic: .start, identifier: "start-tips-bulb")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, 16)
            }
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

    /// The headline in one line: set far too large, then shrunk to the width of
    /// the screen, so it fills every device alike.
    private var title: some View {
        Text("Backen mit Sauerteig")
            .font(HeadlineFont.font(size: 120))
            .lineLimit(1)
            .minimumScaleFactor(0.05)
            .multilineTextAlignment(.center)
            // Handwriting overhangs its advance width; without room the last
            // stroke of the "g" is cut off.
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("start-title")
    }

    /// The photo `StartPhoto` over a placeholder. A missing asset draws
    /// nothing, so the placeholder shows through; the photo is only local,
    /// its rights are unclear (see `.gitignore`).
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
        .overlay {
            Image("StartPhoto")
                .resizable()
                .scaledToFill()
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Foto von Sauerteigbroten")
        .accessibilityIdentifier("start-hero")
    }

    private func option(_ title: String, subtitle: String, icon: some View,
                        destination: Destination, id: String) -> some View {
        NavigationLink(value: destination) {
            card(title, subtitle: subtitle, icon: icon)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func card(_ title: String, subtitle: String, icon: some View) -> some View {
        HStack(spacing: 16) {
            icon
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

/// A system symbol as the icon of a start card.
struct SystemIcon: View {
    let name: String

    var body: some View {
        Image(systemName: name).font(.title2)
    }
}

/// An own icon from the asset catalog, drawn as a template in the text colour.
/// The system symbols have no loaf of bread and no casserole.
struct CustomIcon: View {
    let name: String

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
            // Decoration: the text beside it says what it is, not the asset name.
            .accessibilityHidden(true)
    }
}
