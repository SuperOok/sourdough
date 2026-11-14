import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

struct LaunchSetupTests {
    private let runs = BakeRunStore(
        directory: FileManager.default.temporaryDirectory.appendingPathComponent("LaunchSetupTests-\(UUID().uuidString)"))
    private let kitchen = KitchenStore(defaults: UserDefaults(suiteName: "LaunchSetupTests-\(UUID().uuidString)")!)

    private func makeStores() -> (EquipmentStore, StarterStore) {
        let name = "LaunchSetupTests-\(UUID().uuidString)"
        return (EquipmentStore(defaults: UserDefaults(suiteName: name)!),
                StarterStore(defaults: UserDefaults(suiteName: name + "-s")!))
    }

    @Test func withoutParametersNothingChanges() {
        let (equipment, starters) = makeStores()
        equipment.add(EquipmentItem(kind: .basket, name: "B"))
        starters.add(Starter(name: "A", flour: .rye, createdAt: Date()))
        kitchen.temperatures.roomCelsius = 19
        LaunchSetup.apply(LaunchOptions(arguments: []), equipment: equipment, starters: starters, kitchen: kitchen, runs: runs)
        #expect(equipment.items.map(\.name) == ["B"])
        #expect(starters.starters.map(\.name) == ["A"])
        #expect(kitchen.temperatures.roomCelsius == 19)
    }

    @Test func resetForgetsEquipmentStartersAndTheKitchen() {
        let (equipment, starters) = makeStores()
        equipment.add(EquipmentItem(kind: .basket, name: "B"))
        starters.add(Starter(name: "A", flour: .rye, createdAt: Date()))
        kitchen.temperatures.roomCelsius = 19
        LaunchSetup.apply(LaunchOptions(arguments: ["-resetData"]), equipment: equipment,
                          starters: starters, kitchen: kitchen, runs: runs)
        #expect(equipment.items.isEmpty)
        #expect(starters.starters.isEmpty)
        #expect(kitchen.temperatures == Temperatures())
    }

    @Test func resetForgetsTheBakes() {
        let (equipment, starters) = makeStores()
        runs.start(BakeRunDemo.run(now: Date(), starters: [], items: []))
        LaunchSetup.apply(LaunchOptions(arguments: ["-resetData"]), equipment: equipment,
                          starters: starters, kitchen: kitchen, runs: runs)
        #expect(runs.runs.isEmpty)
    }

    @Test func seedsTheDemoBakeAtTheFixedTimeWithTheSeededThings() {
        let (equipment, starters) = makeStores()
        let options = LaunchOptions(arguments: ["-seedEquipment", "all", "-seedStarters", "demo",
                                                "-seedRun", "active", "-now", "2026-11-13T09:00"])
        LaunchSetup.apply(options, equipment: equipment, starters: starters, kitchen: kitchen, runs: runs)
        #expect(runs.active?.startedAt == options.now)
        #expect(runs.active?.starter?.name == "Roggensauerteig")
        #expect(runs.active?.setup.pot?.name == "Römertopf")
    }

    @Test func seedsAFinishedBake() {
        let (equipment, starters) = makeStores()
        let now = Date(timeIntervalSince1970: 5_000_000)
        LaunchSetup.apply(LaunchOptions(arguments: ["-seedRun", "finished"]), equipment: equipment,
                          starters: starters, kitchen: kitchen, runs: runs, now: now)
        #expect(runs.active == nil)
        #expect(runs.runs.first?.status == .finished)
        #expect(runs.runs.first?.startedAt == now)
    }

    @Test func seedsEquipmentAfterTheReset() {
        let (equipment, starters) = makeStores()
        equipment.add(EquipmentItem(kind: .basket, name: "B"))
        LaunchSetup.apply(LaunchOptions(arguments: ["-resetData", "-seedEquipment", "all"]),
                          equipment: equipment, starters: starters, kitchen: kitchen, runs: runs)
        #expect(equipment.items.map(\.name) == [
            "Thermomix", "Römertopf", "Gusseisenform", "Kastenform", "Gärkörbchen"])
    }

    @Test func seedsTheDemoStartersRelativeToNow() {
        let (equipment, starters) = makeStores()
        let now = Date(timeIntervalSince1970: 5_000_000)
        LaunchSetup.apply(LaunchOptions(arguments: ["-resetData", "-seedStarters", "demo"]),
                          equipment: equipment, starters: starters, kitchen: kitchen, runs: runs, now: now)
        #expect(starters.starters.map(\.name) == ["Roggensauerteig", "Weizensauerteig", "Junger Roggensauerteig"])
        #expect(starters.starters[0].lastFeeding?.date == now - 3600)
    }

    @Test func applyingTwiceSeedsTwiceSoItMustRunOnlyOnce() {
        // Documents why the setup lives in the app and not in a view's init.
        let (equipment, starters) = makeStores()
        let options = LaunchOptions(arguments: ["-seedStarters", "demo"])
        LaunchSetup.apply(options, equipment: equipment, starters: starters, kitchen: kitchen, runs: runs)
        LaunchSetup.apply(options, equipment: equipment, starters: starters, kitchen: kitchen, runs: runs)
        #expect(starters.starters.count == 6)
    }
}
