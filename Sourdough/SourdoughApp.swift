import SwiftUI

@main
struct SourdoughApp: App {
    private let options = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
    private let equipmentStore = EquipmentStore()
    private let starterStore = StarterStore()

    init() {
        LaunchSetup.apply(options, equipment: equipmentStore, starters: starterStore)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(options: options, store: equipmentStore, starterStore: starterStore)
        }
    }
}
