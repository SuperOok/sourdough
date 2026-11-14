import Foundation
import Observation
import SourdoughKit

/// Reads a number typed into a field: empty is 0, comma or point as decimal
/// separator, never negative.
enum NumberInput {
    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value >= 0 else { return nil }
        return value
    }

    /// A field that is known to be valid, as a number; anything else counts as 0.
    static func grams(_ text: String) -> Double {
        parse(text) ?? 0
    }
}

/// The form for a new starter, in one of three ways (`StarterOrigin`): an
/// existing starter with an estimated last feeding (or none), a fresh mix with
/// a sample of another starter, or a spontaneous mix of flour and water alone.
@Observable
final class StarterFormModel {
    static let numbersOnly = "Bitte gib nur Zahlen ein."
    static let needsFood = "Mehl und Wasser dürfen nicht beide 0 sein."
    static let needsAmount = "Gib an, wie viel Starter du hast."
    static let needsSample = "Gib an, wie viel Anstellgut du nimmst. Ohne Probe ist es ein spontaner Ansatz."
    static let fridgeRange = "Die Kühlschranktemperatur liegt meist zwischen 0 und 15 °C."
    static let roomRange = "Die Raumtemperatur liegt meist zwischen 10 und 35 °C."
    static let coolRange = "Ein kühler Ort liegt meist zwischen 8 und 18 °C."
    static let coldHint = "Unter 22 °C dauert jede Phase länger. Am schnellsten geht es bei 24 bis 28 °C."

    /// A spontaneous mix is kept warm: it starts at room temperature.
    var origin: StarterOrigin = .existing {
        didSet { if origin == .spontaneous { inFridge = false } }
    }
    var name = ""
    var flour: FlourType = .rye
    /// When the starter was mixed (with a sample or spontaneously).
    var createdAt: Date
    /// Whether the last feeding of an existing starter is known.
    var lastFeedingKnown = true
    /// When an existing starter was fed last, roughly.
    var lastFedAt: Date
    /// How much there is of an existing starter.
    var amountText = "50"
    /// The sample of another starter in a fresh mix.
    var sampleText = StarterText.number(FeedFormModel.defaultStarterGrams)
    var flourText = "50"
    var waterText = "50"
    var inFridge = true
    var fridgeText: String
    var roomText: String
    /// When the form was opened: an existing starter is "bei dir" from then on.
    private let now: Date

    /// Starts with the temperatures used last.
    init(now: Date = Date(), temperatures: Temperatures = Temperatures()) {
        self.now = now
        createdAt = now
        lastFedAt = now
        fridgeText = StarterText.number(temperatures.fridgeCelsius)
        roomText = StarterText.number(temperatures.roomCelsius)
    }

    /// The typed name, or the default of the flour if there is none.
    var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? flour.starterName : trimmed
    }

    /// A fridge temperature from a field; `nil` unless it is a number from 0 to 15.
    static func parseFridge(_ text: String) -> Double? {
        NumberInput.parse(text).flatMap { (0...15).contains($0) ? $0 : nil }
    }

    /// A room temperature from a field; `nil` unless it is a number from 10 to 35.
    static func parseRoom(_ text: String) -> Double? {
        NumberInput.parse(text).flatMap { (10...35).contains($0) ? $0 : nil }
    }

    /// The temperature of a cool place from a field; `nil` unless it is a
    /// number from 8 to 18.
    static func parseCool(_ text: String) -> Double? {
        NumberInput.parse(text).flatMap { (8...18).contains($0) ? $0 : nil }
    }

    /// The number fields on screen, in order, for "Weiter" above the keypad.
    var fields: [String] {
        let amounts: [String] = switch origin {
        case .existing: lastFeedingKnown ? ["add-amount"] : []
        case .inoculated: ["add-sample", "add-flour-grams", "add-water-grams"]
        case .spontaneous: ["add-flour-grams", "add-water-grams"]
        }
        return amounts + [inFridge ? "add-fridge-temp" : "add-room-temp"]
    }

    /// What is wrong with the amount of an existing starter.
    var amountError: String? {
        guard origin == .existing, lastFeedingKnown else { return nil }
        guard let grams = NumberInput.parse(amountText) else { return Self.numbersOnly }
        return grams == 0 ? Self.needsAmount : nil
    }

    /// What is wrong with the first feeding (sample, flour and water) of a fresh mix.
    var foodError: String? {
        guard origin != .existing else { return nil }
        guard let flourGrams = NumberInput.parse(flourText),
              let waterGrams = NumberInput.parse(waterText) else { return Self.numbersOnly }
        if origin == .inoculated {
            guard let sampleGrams = NumberInput.parse(sampleText) else { return Self.numbersOnly }
            if sampleGrams == 0 { return Self.needsSample }
        }
        return flourGrams + waterGrams == 0 ? Self.needsFood : nil
    }

    /// What is wrong with the temperature of the place.
    var storageError: String? {
        if inFridge { return Self.parseFridge(fridgeText) == nil ? Self.fridgeRange : nil }
        return Self.parseRoom(roomText) == nil ? Self.roomRange : nil
    }

    /// A spontaneous mix colder than 22 °C: every phase takes longer. Not an
    /// error, only a hint.
    var coldHint: String? {
        guard origin == .spontaneous, storageError == nil,
              let celsius = inFridge ? Self.parseFridge(fridgeText) : Self.parseRoom(roomText),
              celsius < StarterModel.referenceCelsius else { return nil }
        return Self.coldHint
    }

    var errorText: String? { amountError ?? foodError ?? storageError }

    var isValid: Bool { errorText == nil }

    /// The new starter, or `nil` if the form is not valid.
    func makeStarter(id: UUID = UUID()) -> Starter? {
        guard errorText == nil else { return nil }
        let feedings: [Feeding]
        // Checked above, in `errorText`: the fields of the chosen way are numbers.
        let grams = NumberInput.grams
        switch origin {
        case .existing:
            feedings = lastFeedingKnown ? [Feeding.estimate(date: lastFedAt, grams: grams(amountText))] : []
        case .inoculated:
            feedings = [Feeding(date: createdAt, starterGrams: grams(sampleText), flourGrams: grams(flourText),
                                waterGrams: grams(waterText))]
        case .spontaneous:
            feedings = [Feeding(date: createdAt, starterGrams: 0, flourGrams: grams(flourText),
                                waterGrams: grams(waterText))]
        }
        return Starter(id: id, name: resolvedName, flour: flour,
                       createdAt: origin == .existing ? now : createdAt,
                       feedings: feedings, inFridge: inFridge,
                       fridgeCelsius: Self.parseFridge(fridgeText) ?? Temperatures().fridgeCelsius,
                       roomCelsius: Self.parseRoom(roomText) ?? Starter.defaultRoomCelsius,
                       origin: origin)
    }
}

/// The form for a feeding. Starts with the amounts of the last feeding; after
/// an estimated one, with the amount received as the kept starter. In the
/// establishing phase it asks how far the starter rose (`asksRise`).
@Observable
final class FeedFormModel {
    static let defaultStarterGrams = 20.0
    static let needsRise = "Wähle, wie weit er aufgegangen ist, dann lässt sich speichern."

    var date: Date
    var starterText: String
    var flourText: String
    var waterText: String
    let asksRise: Bool
    var rise: Rise?

    init(previous: Feeding?, asksRise: Bool = false, now: Date = Date()) {
        date = now
        self.asksRise = asksRise
        let starter = previous.map(\.starterGrams).flatMap { $0 > 0 ? $0 : nil }
        starterText = StarterText.number(starter ?? Self.defaultStarterGrams)
        // An estimate knows no flour and water.
        let food = previous.flatMap { $0.isEstimate ? nil : $0 }
        flourText = StarterText.number(food?.flourGrams ?? 50)
        waterText = StarterText.number(food?.waterGrams ?? 50)
    }

    /// What is wrong with the amounts.
    var amountError: String? {
        guard NumberInput.parse(starterText) != nil,
              let flourGrams = NumberInput.parse(flourText),
              let waterGrams = NumberInput.parse(waterText) else { return StarterFormModel.numbersOnly }
        return flourGrams + waterGrams == 0 ? StarterFormModel.needsFood : nil
    }

    /// The rise is missing in the establishing phase.
    var riseError: String? {
        asksRise && rise == nil ? Self.needsRise : nil
    }

    var errorText: String? { amountError ?? riseError }

    var isValid: Bool { errorText == nil }

    /// The feeding, or `nil` if the form is not valid.
    func makeFeeding(id: UUID = UUID()) -> Feeding? {
        guard errorText == nil,
              let starterGrams = NumberInput.parse(starterText),
              let flourGrams = NumberInput.parse(flourText),
              let waterGrams = NumberInput.parse(waterText) else { return nil }
        return Feeding(id: id, date: date, starterGrams: starterGrams, flourGrams: flourGrams,
                       waterGrams: waterGrams, rise: asksRise ? rise : nil)
    }
}
