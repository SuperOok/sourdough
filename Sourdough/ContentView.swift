import SwiftUI

/// The root: the splash animation over the start screen.
struct ContentView: View {
    private let store: EquipmentStore
    private let starterStore: StarterStore
    private let kitchenStore: KitchenStore
    private let now: Date?
    private let splashDuration: Duration
    @State private var showSplash: Bool

    init(options: LaunchOptions, store: EquipmentStore, starterStore: StarterStore, kitchenStore: KitchenStore) {
        self.store = store
        self.starterStore = starterStore
        self.kitchenStore = kitchenStore
        now = options.now
        splashDuration = options.splashDuration
        _showSplash = State(initialValue: !options.skipSplash)
    }

    var body: some View {
        ZStack {
            StartView(store: store, starterStore: starterStore, kitchenStore: kitchenStore, now: now)
            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .task {
            if showSplash {
                try? await Task.sleep(for: splashDuration)
                withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
            }
        }
    }
}

#Preview {
    ContentView(options: LaunchOptions(arguments: ["-skipSplash"]),
                store: EquipmentStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
                starterStore: StarterStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
                kitchenStore: KitchenStore(defaults: UserDefaults(suiteName: "preview") ?? .standard))
}
