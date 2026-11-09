import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

struct StarterStoreTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "StarterStoreTests-\(UUID().uuidString)")!
    }

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func starter(_ name: String) -> Starter {
        Starter(name: name, flour: .rye, createdAt: t0,
                feedings: [Feeding(date: t0, starterGrams: 0, flourGrams: 50, waterGrams: 50)])
    }

    @Test func startsEmpty() {
        let store = StarterStore(defaults: makeDefaults())
        #expect(store.starters.isEmpty)
        #expect(store.startSubtitle == "Noch keiner angelegt")
    }

    @Test func addedStartersAreReadBackByANewStore() {
        let defaults = makeDefaults()
        let store = StarterStore(defaults: defaults)
        store.add(starter("A"))
        store.add(starter("B"))
        #expect(StarterStore(defaults: defaults).starters.map(\.name) == ["A", "B"])
        #expect(store.startSubtitle == "2 angelegt")
    }

    @Test func findsAStarterById() {
        let store = StarterStore(defaults: makeDefaults())
        let a = starter("A")
        store.add(a)
        #expect(store.starter(a.id) == a)
        #expect(store.starter(UUID()) == nil)
    }

    @Test func feedingAppendsAndIsSaved() {
        let defaults = makeDefaults()
        let store = StarterStore(defaults: defaults)
        let a = starter("A")
        store.add(a)
        let feeding = Feeding(date: t0.addingTimeInterval(3600), starterGrams: 20,
                              flourGrams: 50, waterGrams: 50)
        store.feed(a.id, with: feeding)
        #expect(store.starter(a.id)?.feedings.count == 2)
        #expect(StarterStore(defaults: defaults).starter(a.id)?.feedings.last == feeding)
    }

    @Test func feedingAnUnknownStarterChangesNothing() {
        let store = StarterStore(defaults: makeDefaults())
        store.add(starter("A"))
        store.feed(UUID(), with: Feeding(date: t0, starterGrams: 1, flourGrams: 1, waterGrams: 1))
        #expect(store.starters.map(\.feedings.count) == [1])
    }

    @Test func storageChangeIsSaved() {
        let defaults = makeDefaults()
        let store = StarterStore(defaults: defaults)
        let a = starter("A")
        store.add(a)
        store.setStorage(a.id, inFridge: false, fridgeCelsius: 8)
        let reopened = StarterStore(defaults: defaults).starter(a.id)
        #expect(reopened?.inFridge == false)
        #expect(reopened?.fridgeCelsius == 8)
    }

    @Test func theFridgeTemperatureChangesWithoutMovingTheStarter() {
        let defaults = makeDefaults()
        let store = StarterStore(defaults: defaults)
        var a = starter("A")
        a.inFridge = false
        store.add(a)
        store.setFridgeCelsius(a.id, 9)
        store.setFridgeCelsius(UUID(), 1)
        let reopened = StarterStore(defaults: defaults).starter(a.id)
        #expect(reopened?.fridgeCelsius == 9)
        #expect(reopened?.inFridge == false)
    }

    @Test func removeDeletesOnlyThatStarter() {
        let defaults = makeDefaults()
        let store = StarterStore(defaults: defaults)
        let a = starter("A")
        store.add(a)
        store.add(starter("B"))
        store.remove(a.id)
        #expect(store.starters.map(\.name) == ["B"])
        #expect(StarterStore(defaults: defaults).starters.map(\.name) == ["B"])
    }

    @Test func resetForgetsEverything() {
        let defaults = makeDefaults()
        let store = StarterStore(defaults: defaults)
        store.add(starter("A"))
        store.reset()
        #expect(store.starters.isEmpty)
        #expect(StarterStore(defaults: defaults).starters.isEmpty)
    }

    @Test func unreadableDataCountsAsNoStarters() {
        let defaults = makeDefaults()
        defaults.set(Data("kein JSON".utf8), forKey: StarterStore.key)
        #expect(StarterStore(defaults: defaults).starters.isEmpty)
    }
}
