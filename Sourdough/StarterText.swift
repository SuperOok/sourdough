import Foundation
import SourdoughKit

extension FlourType {
    var germanName: String {
        switch self {
        case .rye: "Roggen"
        case .wheat: "Weizen"
        case .spelt: "Dinkel"
        }
    }

    /// The name a new starter gets when the user types none.
    var starterName: String {
        switch self {
        case .rye: "Roggensauerteig"
        case .wheat: "Weizensauerteig"
        case .spelt: "Dinkelsauerteig"
        }
    }
}

extension StarterState {
    var title: String {
        switch self {
        case .rising: "Reift"
        case .peak: "Am Höhepunkt"
        case .pastPeak: "Über dem Höhepunkt"
        case .hungry: "Hungrig"
        case .neglected: "Lange nicht gefüttert"
        }
    }

    var hint: String {
        switch self {
        case .rising: "Der Starter geht noch auf."
        case .peak: "Jetzt ist er am besten zum Verwenden."
        case .pastPeak: "Bald füttern oder verwenden."
        case .hungry: "Jetzt füttern oder verwenden."
        case .neglected: "Erst auffrischen, dann verwenden."
        }
    }
}

/// German texts for starters: durations, dates, amounts.
enum StarterText {
    private static let german = Locale(identifier: "de_DE")

    /// "3 Tage 4 Std.", "2 Std. 5 Min.", "40 Min."
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        let days = minutes / 1440
        let hours = minutes % 1440 / 60
        if days > 0 { return "\(days) \(days == 1 ? "Tag" : "Tage") \(hours) Std." }
        if hours > 0 { return "\(hours) Std. \(minutes % 60) Min." }
        return "\(minutes) Min."
    }

    /// "08.11.2026 14:00"
    static func date(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = german
        formatter.timeZone = timeZone
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: date)
    }

    /// "50", "12,5": a number as typed into a field.
    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", locale: german, value)
    }

    static func grams(_ value: Double) -> String {
        number(value) + " g"
    }

    /// One line of the feeding log.
    static func feedingLine(_ feeding: Feeding, timeZone: TimeZone = .current) -> String {
        let food = "\(grams(feeding.flourGrams)) Mehl + \(grams(feeding.waterGrams)) Wasser"
        let what = feeding.starterGrams > 0 ? "\(grams(feeding.starterGrams)) Starter + \(food)"
                                            : "Ansatz: \(food)"
        return "\(date(feeding.date, timeZone: timeZone)) · \(what)"
    }
}

/// Everything the screens show about a starter at one moment, as text.
struct StarterSummary: Equatable {
    static let notFed = "Noch nicht gefüttert"
    static let none = "—"

    let stateTitle: String
    let hint: String
    let age: String
    let feedBy: String
    let bestWindow: String

    init(_ starter: Starter, now: Date, timeZone: TimeZone = .current) {
        let status = starter.status(at: now)
        stateTitle = status?.state.title ?? Self.notFed
        hint = status?.state.hint ?? Self.notFed
        age = StarterText.duration(starter.age(at: now))
        feedBy = status.map { StarterText.date($0.feedBy, timeZone: timeZone) } ?? Self.none
        bestWindow = status.map {
            "\(StarterText.date($0.bestFrom, timeZone: timeZone)) – \(StarterText.date($0.bestUntil, timeZone: timeZone))"
        } ?? Self.none
    }
}
