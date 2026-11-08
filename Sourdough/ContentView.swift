import SwiftUI

/// The root: the splash animation over the start screen.
struct ContentView: View {
    private let store: EquipmentStore
    private let splashDuration: Duration
    @State private var showSplash: Bool

    init(options: LaunchOptions = LaunchOptions(arguments: ProcessInfo.processInfo.arguments),
         store: EquipmentStore = EquipmentStore()) {
        if options.resetData { store.reset() }
        if let seed = options.seedEquipment { store.save(seed) }
        self.store = store
        splashDuration = options.splashDuration
        _showSplash = State(initialValue: !options.skipSplash)
    }

    var body: some View {
        ZStack {
            StartView(store: store)
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
                store: EquipmentStore(defaults: UserDefaults(suiteName: "preview") ?? .standard))
}
