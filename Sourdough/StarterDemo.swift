import Foundation
import SourdoughKit

/// Two starters in known states for the UI tests (`-seedStarters demo`),
/// relative to `now`: a rye starter in the fridge, fed an hour ago, which is
/// still rising, and a wheat starter at room temperature, fed three days ago,
/// which is long overdue.
enum StarterDemo {
    static let ryeName = "Roggensauerteig"
    static let wheatName = "Weizensauerteig"

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
        return [rye, wheat]
    }
}
