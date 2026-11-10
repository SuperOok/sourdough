import Foundation
import Observation
import SourdoughKit

/// The bakes, running and done: one JSON file per bake in a folder of
/// Application Support (`bakes/`), so that photos can join them later.
/// Unreadable files are left out. There is at most one active bake.
@Observable
final class BakeRunStore {
    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("bakes", isDirectory: true)
    }

    private let directory: URL
    /// Newest first.
    private(set) var runs: [BakeRun] = []

    init(directory: URL = BakeRunStore.defaultDirectory) {
        self.directory = directory
        load()
    }

    /// The bake in progress, if any.
    var active: BakeRun? {
        runs.first { $0.status == .active }
    }

    func run(_ id: BakeRun.ID) -> BakeRun? {
        runs.first { $0.id == id }
    }

    /// Starts `run` unless another bake is in progress.
    func start(_ run: BakeRun) {
        guard active == nil else { return }
        runs.insert(run, at: 0)
        save(run)
    }

    func complete(_ id: BakeRun.ID, at date: Date) {
        change(id) { $0.complete(at: date) }
    }

    func answer(_ id: BakeRun.ID, _ answer: BakeProcess.Answer, at date: Date) {
        change(id) { $0.answer(answer, at: date) }
    }

    /// Opens the last done step of `id` again. A finished bake runs again
    /// only while no other bake is in progress.
    func undo(_ id: BakeRun.ID) {
        if let other = active, other.id != id { return }
        change(id) { $0.undo() }
    }

    func cancel(_ id: BakeRun.ID, at date: Date) {
        change(id) { $0.cancel(at: date) }
    }

    func remove(_ id: BakeRun.ID) {
        runs.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: file(id))
    }

    func reset() {
        runs = []
        try? FileManager.default.removeItem(at: directory)
    }

    /// The line under "Backprotokoll" on the start screen.
    var startSubtitle: String {
        let ended = runs.filter { $0.status != .active }.count
        return ended == 0 ? "Noch kein Durchgang" : ended == 1 ? "1 Durchgang" : "\(ended) Durchgänge"
    }

    private func change(_ id: BakeRun.ID, _ edit: (inout BakeRun) -> Void) {
        guard let index = runs.firstIndex(where: { $0.id == id }) else { return }
        edit(&runs[index])
        save(runs[index])
    }

    private func file(_ id: BakeRun.ID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private func save(_ run: BakeRun) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(run).write(to: file(run.id), options: .atomic)
    }

    private func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        runs = files
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(BakeRun.self, from: $0) }
            .sorted { $0.startedAt > $1.startedAt }
    }
}
