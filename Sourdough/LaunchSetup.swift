import Foundation

/// Brings the stores into the state the start parameters ask for. Runs once at
/// launch from `SourdoughApp`: a view's `init` runs again whenever SwiftUI
/// rebuilds it, which would reset and reseed (with new ids) again and again.
enum LaunchSetup {
    static func apply(_ options: LaunchOptions, equipment: EquipmentStore,
                      starters: StarterStore, now: Date = Date()) {
        if options.resetData {
            equipment.reset()
            starters.reset()
        }
        if options.seedEquipment { EquipmentDemo.items().forEach(equipment.add) }
        if options.seedDemoStarters { StarterDemo.starters(now: now).forEach(starters.add) }
    }
}
