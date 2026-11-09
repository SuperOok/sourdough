import Foundation
import Observation
import SourdoughKit

/// The saved starters, kept in `UserDefaults` as JSON, oldest first.
/// Unreadable data counts as no starters.
@Observable
final class StarterStore {
    static let key = "starters.v1"

    private let defaults: UserDefaults
    private(set) var starters: [Starter] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func starter(_ id: Starter.ID) -> Starter? {
        starters.first { $0.id == id }
    }

    func add(_ starter: Starter) {
        starters.append(starter)
        save()
    }

    /// Adds a feeding to the starter with that id; unknown ids are ignored.
    func feed(_ id: Starter.ID, with feeding: Feeding) {
        change(id) { $0.feedings.append(feeding) }
    }

    func setStorage(_ id: Starter.ID, inFridge: Bool, fridgeCelsius: Double) {
        change(id) {
            $0.inFridge = inFridge
            $0.fridgeCelsius = fridgeCelsius
        }
    }

    /// Changes only the fridge temperature, not where the starter is kept.
    func setFridgeCelsius(_ id: Starter.ID, _ celsius: Double) {
        change(id) { $0.fridgeCelsius = celsius }
    }

    /// Changes only the room temperature, not where the starter is kept.
    func setRoomCelsius(_ id: Starter.ID, _ celsius: Double) {
        change(id) { $0.roomCelsius = celsius }
    }

    func remove(_ id: Starter.ID) {
        starters.removeAll { $0.id == id }
        save()
    }

    func reset() {
        starters = []
        save()
    }

    /// The line under "Sauerteigstarter" on the start screen.
    var startSubtitle: String {
        starters.isEmpty ? "Noch keiner angelegt" : "\(starters.count) angelegt"
    }

    private func change(_ id: Starter.ID, _ edit: (inout Starter) -> Void) {
        guard let index = starters.firstIndex(where: { $0.id == id }) else { return }
        edit(&starters[index])
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(starters), forKey: Self.key)
    }

    private func load() {
        starters = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([Starter].self, from: $0) } ?? []
    }
}
