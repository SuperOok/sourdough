import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

struct EquipmentStoreTests {
    /// A defaults suite of its own, so the real data is never touched.
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "EquipmentStoreTests-\(UUID().uuidString)")!
    }

    private func pan(_ name: String) -> EquipmentItem {
        EquipmentItem(kind: .pan, name: name, material: .castIron, hasLid: true,
                      dimensions: Dimensions(shape: .rectangular, lengthCm: 30, widthCm: 10, heightCm: 8))
    }

    @Test func startsEmpty() {
        let store = EquipmentStore(defaults: makeDefaults())
        #expect(store.items.isEmpty)
    }

    @Test func addedItemsKeepTheirOrderAndAreReadBackByANewStore() {
        let defaults = makeDefaults()
        let store = EquipmentStore(defaults: defaults)
        let first = pan("A")
        let second = EquipmentItem(kind: .kneader, name: "B")
        store.add(first)
        store.add(second)
        #expect(store.items == [first, second])
        #expect(EquipmentStore(defaults: defaults).items == [first, second])
    }

    @Test func severalItemsOfOneKindAreAllowed() {
        let store = EquipmentStore(defaults: makeDefaults())
        store.add(pan("A"))
        store.add(pan("B"))
        #expect(store.items.map(\.name) == ["A", "B"])
    }

    @Test func anItemIsFoundById() {
        let store = EquipmentStore(defaults: makeDefaults())
        let item = pan("A")
        store.add(item)
        #expect(store.item(item.id) == item)
        #expect(store.item(UUID()) == nil)
    }

    @Test func updateReplacesTheItemWithTheSameIdAndKeepsItsPlace() {
        let defaults = makeDefaults()
        let store = EquipmentStore(defaults: defaults)
        var first = pan("A")
        store.add(first)
        store.add(pan("B"))
        first.name = "A2"
        store.update(first)
        #expect(store.items.map(\.name) == ["A2", "B"])
        #expect(EquipmentStore(defaults: defaults).items.map(\.name) == ["A2", "B"])
    }

    @Test func updateIgnoresUnknownIds() {
        let store = EquipmentStore(defaults: makeDefaults())
        store.add(pan("A"))
        store.update(pan("other"))
        #expect(store.items.map(\.name) == ["A"])
    }

    @Test func removeDeletesOnlyThatItem() {
        let defaults = makeDefaults()
        let store = EquipmentStore(defaults: defaults)
        let first = pan("A")
        store.add(first)
        store.add(pan("B"))
        store.remove(first.id)
        #expect(store.items.map(\.name) == ["B"])
        #expect(EquipmentStore(defaults: defaults).items.map(\.name) == ["B"])
    }

    @Test func resetForgetsEverything() {
        let defaults = makeDefaults()
        let store = EquipmentStore(defaults: defaults)
        store.add(pan("A"))
        store.reset()
        #expect(store.items.isEmpty)
        #expect(EquipmentStore(defaults: defaults).items.isEmpty)
    }

    @Test func unreadableDataCountsAsNoEquipment() {
        let defaults = makeDefaults()
        defaults.set(Data("kein JSON".utf8), forKey: EquipmentStore.key)
        #expect(EquipmentStore(defaults: defaults).items.isEmpty)
    }

    @Test func theKeyIsVersionTwoSoTheOldSingleRecordIsLeftAlone() {
        #expect(EquipmentStore.key == "equipment.v2")
    }

    @Test func missingKindsFollowTheItems() {
        let store = EquipmentStore(defaults: makeDefaults())
        #expect(store.missingKinds == [.kneader, .pot, .pan, .basket])
        store.add(pan("A"))
        #expect(store.missingKinds == [.kneader, .pot, .basket])
    }

    @Test func startSubtitleFollowsTheCount() {
        let store = EquipmentStore(defaults: makeDefaults())
        #expect(store.startSubtitle == "Noch nichts angelegt")
        store.add(pan("A"))
        #expect(store.startSubtitle == "1 angelegt")
        store.add(pan("B"))
        #expect(store.startSubtitle == "2 angelegt")
    }
}
