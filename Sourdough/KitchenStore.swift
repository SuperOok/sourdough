import Foundation
import Observation
import SourdoughKit

/// The kitchen's temperatures, remembered for the next bake and the next
/// starter (`UserDefaults`, JSON under `kitchen.v1`).
@Observable
final class KitchenStore {
    static let key = "kitchen.v1"

    private let defaults: UserDefaults
    var temperatures: Temperatures {
        didSet { defaults.set(try? JSONEncoder().encode(temperatures), forKey: Self.key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        temperatures = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(Temperatures.self, from: $0) } ?? Temperatures()
    }

    /// Remembers the temperature a new starter is kept at.
    func remember(_ starter: Starter) {
        if starter.inFridge {
            temperatures.fridgeCelsius = starter.fridgeCelsius
        } else {
            temperatures.roomCelsius = starter.roomCelsius
        }
    }

    func reset() {
        temperatures = Temperatures()
    }
}
