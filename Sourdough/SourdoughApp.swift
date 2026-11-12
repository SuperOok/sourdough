import SwiftUI

@main
struct SourdoughApp: App {
    private let options = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
    private let equipmentStore = EquipmentStore()
    private let starterStore = StarterStore()
    private let kitchenStore = KitchenStore()
    private let runStore = BakeRunStore()

    init() {
        HeadlineFont.register()
        LaunchSetup.apply(options, equipment: equipmentStore, starters: starterStore, kitchen: kitchenStore,
                          runs: runStore)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(options: options, store: equipmentStore, starterStore: starterStore,
                        kitchenStore: kitchenStore, runStore: runStore)
        }
    }
}
