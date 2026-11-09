import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

struct KitchenStoreTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "KitchenStoreTests-\(UUID().uuidString)")!
    }

    @Test func startsWith22And5Degrees() {
        #expect(KitchenStore(defaults: makeDefaults()).temperatures == Temperatures(roomCelsius: 22, fridgeCelsius: 5))
    }

    @Test func remembersTheTemperatures() {
        let defaults = makeDefaults()
        KitchenStore(defaults: defaults).temperatures = Temperatures(roomCelsius: 19, fridgeCelsius: 4)
        #expect(KitchenStore(defaults: defaults).temperatures == Temperatures(roomCelsius: 19, fridgeCelsius: 4))
    }

    @Test func unreadableDataCountsAsNothingSaved() {
        let defaults = makeDefaults()
        defaults.set(Data("kaputt".utf8), forKey: KitchenStore.key)
        #expect(KitchenStore(defaults: defaults).temperatures == Temperatures())
    }

    @Test func aNewStarterLeavesTheTemperatureItIsKeptAt() {
        let store = KitchenStore(defaults: makeDefaults())
        store.remember(Starter(name: "K", flour: .rye, createdAt: Date(), inFridge: true, fridgeCelsius: 3))
        #expect(store.temperatures == Temperatures(roomCelsius: 22, fridgeCelsius: 3))
        store.remember(Starter(name: "R", flour: .rye, createdAt: Date(), inFridge: false, fridgeCelsius: 9,
                               roomCelsius: 20))
        #expect(store.temperatures == Temperatures(roomCelsius: 20, fridgeCelsius: 3))
    }

    @Test func resetGoesBackToTheDefaults() {
        let defaults = makeDefaults()
        let store = KitchenStore(defaults: defaults)
        store.temperatures.roomCelsius = 18
        store.reset()
        #expect(KitchenStore(defaults: defaults).temperatures == Temperatures())
    }
}
