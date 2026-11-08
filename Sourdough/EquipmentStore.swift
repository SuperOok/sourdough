import Foundation
import Observation
import SourdoughKit

/// The saved equipment of the user, kept in `UserDefaults` as JSON.
///
/// `isConfigured` tells "never set up" from "set up with nothing owned".
/// Unreadable data counts as never set up.
@Observable
final class EquipmentStore {
    static let key = "equipment.v1"

    private let defaults: UserDefaults
    private(set) var equipment = Equipment()
    private(set) var isConfigured = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func save(_ equipment: Equipment) {
        defaults.set(try? JSONEncoder().encode(equipment), forKey: Self.key)
        load()
    }

    func reset() {
        defaults.removeObject(forKey: Self.key)
        load()
    }

    private func load() {
        let decoded = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(Equipment.self, from: $0) }
        equipment = decoded ?? Equipment()
        isConfigured = decoded != nil
    }
}
