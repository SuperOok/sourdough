import Foundation

/// Brings the stores into the state the start parameters ask for. Runs once at
/// launch from `SourdoughApp`: a view's `init` runs again whenever SwiftUI
/// rebuilds it, which would reset and reseed (with new ids) again and again.
enum LaunchSetup {
    static func apply(_ options: LaunchOptions, equipment: EquipmentStore, starters: StarterStore,
                      kitchen: KitchenStore, runs: BakeRunStore, now: Date = Date(),
                      calendar: Calendar = .current) {
        if options.resetData {
            equipment.reset()
            starters.reset()
            kitchen.reset()
            runs.reset()
        }
        if options.seedEquipment { EquipmentDemo.items().forEach(equipment.add) }
        if options.seedDemoStarters { StarterDemo.starters(now: now).forEach(starters.add) }
        let planned = options.now ?? now
        switch options.seedRun {
        case .active:
            runs.start(BakeRunDemo.run(now: planned, starters: starters.starters, items: equipment.items,
                                       calendar: calendar))
        case .finished:
            runs.start(BakeRunDemo.finished(now: planned, starters: starters.starters, items: equipment.items,
                                            calendar: calendar))
        case nil:
            break
        }
    }
}
