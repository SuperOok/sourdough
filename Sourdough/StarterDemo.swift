import Foundation
import SourdoughKit

/// Three starters in known states for the UI tests (`-seedStarters demo`),
/// relative to `now`: a rye starter in the fridge, fed an hour ago, which
/// rests, a wheat starter at room temperature, fed three days ago,
/// which is long overdue, and a young rye starter mixed spontaneously three
/// and a half days ago, on day 4 of its establishing phase, with one doubling.
enum StarterDemo {
    static let ryeName = "Roggensauerteig"
    static let wheatName = "Weizensauerteig"
    static let youngName = "Junger Roggensauerteig"

    static func starters(now: Date) -> [Starter] {
        let hour: TimeInterval = 3600
        let rye = Starter(
            name: ryeName, flour: .rye, createdAt: now - 10 * 24 * hour,
            feedings: [Feeding(date: now - hour, starterGrams: 20, flourGrams: 50, waterGrams: 50)],
            inFridge: true, fridgeCelsius: 5)
        let wheat = Starter(
            name: wheatName, flour: .wheat, createdAt: now - 20 * 24 * hour,
            feedings: [Feeding(date: now - 72 * hour, starterGrams: 20, flourGrams: 50, waterGrams: 50)],
            inFridge: false, fridgeCelsius: 5)
        // Mixed 84 h ago, fed once a day since: 60 h ago (not risen), 36 h ago
        // (some), 12 h ago (doubled).
        let young = Starter(
            name: youngName, flour: .rye, createdAt: now - 84 * hour,
            feedings: [Feeding(date: now - 84 * hour, starterGrams: 0, flourGrams: 50, waterGrams: 50),
                       Feeding(date: now - 60 * hour, starterGrams: 20, flourGrams: 50, waterGrams: 50, rise: .none),
                       Feeding(date: now - 36 * hour, starterGrams: 20, flourGrams: 50, waterGrams: 50, rise: .some),
                       Feeding(date: now - 12 * hour, starterGrams: 20, flourGrams: 50, waterGrams: 50, rise: .doubled)],
            inFridge: false, fridgeCelsius: 5, origin: .spontaneous)
        return [rye, wheat, young]
    }
}
