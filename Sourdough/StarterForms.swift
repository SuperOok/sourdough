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
}

/// The form for a new starter. The first mix has no old starter to keep.
@Observable
final class StarterFormModel {
    static let numbersOnly = "Bitte gib nur Zahlen ein."
    static let needsFood = "Mehl und Wasser dürfen nicht beide 0 sein."
    static let fridgeRange = "Die Kühlschranktemperatur liegt meist zwischen 0 und 15 °C."
    static let roomRange = "Die Raumtemperatur liegt meist zwischen 10 und 35 °C."

    var name = ""
    var flour: FlourType = .rye
    var createdAt: Date
    var flourText = "50"
    var waterText = "50"
    var inFridge = true
    var fridgeText: String
    var roomText: String

    /// Starts with the temperatures used last.
    init(now: Date = Date(), temperatures: Temperatures = Temperatures()) {
        createdAt = now
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

    var errorText: String? {
        guard let flourGrams = NumberInput.parse(flourText),
              let waterGrams = NumberInput.parse(waterText) else { return Self.numbersOnly }
        if flourGrams + waterGrams == 0 { return Self.needsFood }
        if inFridge && Self.parseFridge(fridgeText) == nil { return Self.fridgeRange }
        if !inFridge && Self.parseRoom(roomText) == nil { return Self.roomRange }
        return nil
    }

    var isValid: Bool { errorText == nil }

    /// The new starter, or `nil` if the form is not valid.
    func makeStarter(id: UUID = UUID()) -> Starter? {
        guard errorText == nil,
              let flourGrams = NumberInput.parse(flourText),
              let waterGrams = NumberInput.parse(waterText) else { return nil }
        let first = Feeding(date: createdAt, starterGrams: 0, flourGrams: flourGrams,
                            waterGrams: waterGrams)
        return Starter(id: id, name: resolvedName, flour: flour, createdAt: createdAt,
                       feedings: [first], inFridge: inFridge,
                       fridgeCelsius: Self.parseFridge(fridgeText) ?? Temperatures().fridgeCelsius,
                       roomCelsius: Self.parseRoom(roomText) ?? Starter.defaultRoomCelsius)
    }
}

/// The form for a feeding. Starts with the amounts of the last feeding.
@Observable
final class FeedFormModel {
    static let defaultStarterGrams = 20.0

    var date: Date
    var starterText: String
    var flourText: String
    var waterText: String

    init(previous: Feeding?, now: Date = Date()) {
        date = now
        let starter = previous.map(\.starterGrams).flatMap { $0 > 0 ? $0 : nil }
        starterText = StarterText.number(starter ?? Self.defaultStarterGrams)
        flourText = StarterText.number(previous?.flourGrams ?? 50)
        waterText = StarterText.number(previous?.waterGrams ?? 50)
    }

    var errorText: String? {
        guard NumberInput.parse(starterText) != nil,
              let flourGrams = NumberInput.parse(flourText),
              let waterGrams = NumberInput.parse(waterText) else { return StarterFormModel.numbersOnly }
        return flourGrams + waterGrams == 0 ? StarterFormModel.needsFood : nil
    }

    var isValid: Bool { errorText == nil }

    /// The feeding, or `nil` if the form is not valid.
    func makeFeeding(id: UUID = UUID()) -> Feeding? {
        guard errorText == nil,
              let starterGrams = NumberInput.parse(starterText),
              let flourGrams = NumberInput.parse(flourText),
              let waterGrams = NumberInput.parse(waterText) else { return nil }
        return Feeding(id: id, date: date, starterGrams: starterGrams, flourGrams: flourGrams,
                       waterGrams: waterGrams)
    }
}
