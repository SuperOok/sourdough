import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

struct EquipmentStoreTests {
    /// A defaults suite of its own, so the real data is never touched.
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "EquipmentStoreTests-\(UUID().uuidString)")!
    }

    private let sample = Equipment(hasKneadingMachine: true, pot: .init(hasSiliconeLiner: true))

    @Test func startsUnconfiguredAndEmpty() {
        let store = EquipmentStore(defaults: makeDefaults())
        #expect(!store.isConfigured)
        #expect(store.equipment.isEmpty)
    }

    @Test func savedEquipmentIsReadBackByANewStore() {
        let defaults = makeDefaults()
        EquipmentStore(defaults: defaults).save(sample)
        let reopened = EquipmentStore(defaults: defaults)
        #expect(reopened.isConfigured)
        #expect(reopened.equipment == sample)
    }

    @Test func savingNothingStillCountsAsConfigured() {
        let store = EquipmentStore(defaults: makeDefaults())
        store.save(Equipment())
        #expect(store.isConfigured)
        #expect(store.equipment.isEmpty)
    }

    @Test func savingAgainReplacesTheOldValue() {
        let store = EquipmentStore(defaults: makeDefaults())
        store.save(sample)
        store.save(Equipment(hasProvingBasket: true))
        #expect(store.equipment == Equipment(hasProvingBasket: true))
    }

    @Test func resetForgetsEverything() {
        let defaults = makeDefaults()
        let store = EquipmentStore(defaults: defaults)
        store.save(sample)
        store.reset()
        #expect(!store.isConfigured)
        #expect(store.equipment.isEmpty)
        #expect(!EquipmentStore(defaults: defaults).isConfigured)
    }

    @Test func unreadableDataCountsAsNeverSetUp() {
        let defaults = makeDefaults()
        defaults.set(Data("kein JSON".utf8), forKey: EquipmentStore.key)
        let store = EquipmentStore(defaults: defaults)
        #expect(!store.isConfigured)
        #expect(store.equipment.isEmpty)
    }

    @Test func startSubtitleFollowsTheState() {
        let store = EquipmentStore(defaults: makeDefaults())
        #expect(store.startSubtitle == "Noch nicht eingerichtet")
        store.save(sample)
        #expect(store.startSubtitle == "Eingerichtet – ansehen oder ändern")
    }
}
