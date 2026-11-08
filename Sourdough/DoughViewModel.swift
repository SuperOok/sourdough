import Foundation
import Observation
import SourdoughKit

/// Turns the three text fields into a `Dough` and the result into text.
///
/// Empty fields count as zero; anything that is not a non-negative number
/// makes the input invalid. Both the decimal comma and the point are accepted.
@Observable
final class DoughViewModel {
    static let placeholder = "—"
    static let invalidText = "Bitte gib nur Zahlen ein."

    var flourText = ""
    var waterText = ""
    var starterText = ""

    /// Starter hydration is fixed at 100 % until the app lets it be set.
    private let starterHydration = 100.0

    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value >= 0 else { return nil }
        return value
    }

    var dough: Dough? {
        guard let flour = Self.parse(flourText),
              let water = Self.parse(waterText),
              let starter = Self.parse(starterText) else { return nil }
        return Dough(flour: flour, water: water, starter: starter,
                     starterHydration: starterHydration)
    }

    var isInputValid: Bool { dough != nil }

    var hydrationText: String {
        guard let hydration = dough?.hydration else { return Self.placeholder }
        return String(format: "%.1f %%", locale: Locale(identifier: "de_DE"), hydration)
    }
}
