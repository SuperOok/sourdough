import Foundation
import Observation
import SourdoughKit

/// The saved equipment of the user, one entry per piece, kept in
/// `UserDefaults` as JSON in the order it was added. Unreadable data counts
/// as no equipment.
@Observable
final class EquipmentStore {
    static let key = "equipment.v2"

    private let defaults: UserDefaults
    private(set) var items: [EquipmentItem] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func item(_ id: EquipmentItem.ID) -> EquipmentItem? {
        items.first { $0.id == id }
    }

    func add(_ item: EquipmentItem) {
        items.append(item)
        save()
    }

    /// Replaces the piece with the same id; unknown ids are ignored.
    func update(_ item: EquipmentItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
    }

    func remove(_ id: EquipmentItem.ID) {
        items.removeAll { $0.id == id }
        save()
    }

    func reset() {
        items = []
        save()
    }

    /// The kinds of which the user has nothing yet.
    var missingKinds: [EquipmentKind] { items.missingKinds }

    /// The line under "Meine Backutensilien" on the start screen.
    var startSubtitle: String {
        items.isEmpty ? "Noch nichts angelegt" : "\(items.count) angelegt"
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(items), forKey: Self.key)
    }

    private func load() {
        items = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([EquipmentItem].self, from: $0) } ?? []
    }
}
