import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

struct LaunchSetupTests {
    private func makeStores() -> (EquipmentStore, StarterStore) {
        let name = "LaunchSetupTests-\(UUID().uuidString)"
        return (EquipmentStore(defaults: UserDefaults(suiteName: name)!),
                StarterStore(defaults: UserDefaults(suiteName: name + "-s")!))
    }

    @Test func withoutParametersNothingChanges() {
        let (equipment, starters) = makeStores()
        equipment.add(EquipmentItem(kind: .basket, name: "B"))
        starters.add(Starter(name: "A", flour: .rye, createdAt: Date()))
        LaunchSetup.apply(LaunchOptions(arguments: []), equipment: equipment, starters: starters)
        #expect(equipment.items.map(\.name) == ["B"])
        #expect(starters.starters.map(\.name) == ["A"])
    }

    @Test func resetForgetsEquipmentAndStarters() {
        let (equipment, starters) = makeStores()
        equipment.add(EquipmentItem(kind: .basket, name: "B"))
        starters.add(Starter(name: "A", flour: .rye, createdAt: Date()))
        LaunchSetup.apply(LaunchOptions(arguments: ["-resetData"]), equipment: equipment,
                          starters: starters)
        #expect(equipment.items.isEmpty)
        #expect(starters.starters.isEmpty)
    }

    @Test func seedsEquipmentAfterTheReset() {
        let (equipment, starters) = makeStores()
        equipment.add(EquipmentItem(kind: .basket, name: "B"))
        LaunchSetup.apply(LaunchOptions(arguments: ["-resetData", "-seedEquipment", "all"]),
                          equipment: equipment, starters: starters)
        #expect(equipment.items.map(\.name) == [
            "Thermomix", "Römertopf", "Gusseisenform", "Kastenform", "Gärkörbchen"])
    }

    @Test func seedsTheDemoStartersRelativeToNow() {
        let (equipment, starters) = makeStores()
        let now = Date(timeIntervalSince1970: 5_000_000)
        LaunchSetup.apply(LaunchOptions(arguments: ["-resetData", "-seedStarters", "demo"]),
                          equipment: equipment, starters: starters, now: now)
        #expect(starters.starters.map(\.name) == ["Roggensauerteig", "Weizensauerteig"])
        #expect(starters.starters[0].lastFeeding?.date == now - 3600)
    }

    @Test func applyingTwiceSeedsTwiceSoItMustRunOnlyOnce() {
        // Documents why the setup lives in the app and not in a view's init.
        let (equipment, starters) = makeStores()
        let options = LaunchOptions(arguments: ["-seedStarters", "demo"])
        LaunchSetup.apply(options, equipment: equipment, starters: starters)
        LaunchSetup.apply(options, equipment: equipment, starters: starters)
        #expect(starters.starters.count == 4)
    }
}
