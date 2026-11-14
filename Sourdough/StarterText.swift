import Foundation
import SourdoughKit

extension FlourType {
    var germanName: String {
        switch self {
        case .rye: "Roggen"
        case .wheat: "Weizen"
        case .spelt: "Dinkel"
        case .buckwheat: "Buchweizen"
        }
    }

    /// The name a new starter gets when the user types none.
    var starterName: String {
        switch self {
        case .rye: "Roggensauerteig"
        case .wheat: "Weizensauerteig"
        case .spelt: "Dinkelsauerteig"
        case .buckwheat: "Buchweizensauerteig"
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
        case .resting: "Ruht"
        case .refreshRecommended: "Auffrischen empfohlen"
        case .refreshTwice: "Vor dem Backen zweimal auffrischen"
        }
    }

    var hint: String {
        switch self {
        case .rising: "Der Starter geht noch auf."
        case .peak: "Jetzt ist er am besten zum Verwenden."
        case .pastPeak: "Bald füttern oder verwenden."
        case .hungry: "Jetzt füttern oder verwenden."
        case .neglected: "Erst auffrischen, dann verwenden."
        case .resting: "Im Kühlschrank ruht er. Vor dem Backen einmal auffrischen."
        case .refreshRecommended: "Frisch ihn bald auf, dann hält er wieder eine Weile."
        case .refreshTwice: "Er hat lange geruht. Vor dem Backen zweimal auffrischen, dann ist er wieder kräftig."
        }
    }
}

extension StarterOrigin {
    /// The choice in "Wie entsteht er?".
    var title: String {
        switch self {
        case .existing: "Schon vorhanden"
        case .inoculated: "Mit Anstellgut ansetzen"
        case .spontaneous: "Spontan ansetzen"
        }
    }
}

extension Rise {
    /// The answer in the feeding form.
    var title: String {
        switch self {
        case .doubled: "Verdoppelt"
        case .some: "Etwas"
        case .none: "Nicht"
        }
    }

    /// In the feeding log.
    var logText: String {
        switch self {
        case .doubled: "verdoppelt"
        case .some: "etwas aufgegangen"
        case .none: "nicht aufgegangen"
        }
    }
}

extension EstablishingPhase {
    var title: String {
        switch self {
        case .fresh: "Frisch angesetzt"
        case .falseRise: "Scheinblüte"
        case .quiet: "Ruhephase"
        case .stabilizing: "Wird stabil"
        case .overdue: "Dauert länger als üblich"
        }
    }

    var hint: String {
        switch self {
        case .fresh: "Noch tut sich wenig. Halte ihn warm und füttere ihn einmal am Tag."
        case .falseRise: "Starkes Blubbern ist jetzt meist noch keine Hefe. Weiter füttern, noch nicht backen."
        case .quiet: "Er wirkt fast tot, das ist normal. Füttere ihn weiter jeden Tag."
        case .stabilizing: "Hefen und Milchsäurebakterien übernehmen. Achte darauf, ob er sich nach dem Füttern verdoppelt."
        case .overdue: "Prüfe Wärme, Mehl und Wasser: Die Tipps unter „Starter selbst ansetzen“ nennen die häufigen Gründe."
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

    /// What to look at oneself, whatever the app estimates.
    static let checkYourself = "Riecht er angenehm säuerlich und verdoppelt er sich nach dem Auffrischen "
        + "in einigen Stunden, ist er gesund. Graue Flüssigkeit obenauf oder ein Geruch nach Nagellack heißen: "
        + "hungrig, abgießen oder unterrühren und auffrischen, wenn nötig mehrmals. "
        + "Schimmel oder rosa und orange Stellen: wegwerfen und neu beginnen."

    /// "einem Verhältnis von 1 : 2,5 : 2,5" (starter : flour : water) of the
    /// feeding, or the assumed one where the amounts say nothing.
    static func ratio(_ feeding: Feeding) -> String {
        guard !feeding.isEstimate, feeding.starterGrams > 0 else { return "dem angenommenen Verhältnis 1 : 1 : 1" }
        let flour = number((feeding.flourGrams / feeding.starterGrams * 10).rounded() / 10)
        let water = number((feeding.waterGrams / feeding.starterGrams * 10).rounded() / 10)
        return "einem Verhältnis von 1 : \(flour) : \(water)"
    }

    /// Why the app says what it says about a fed starter.
    static func explanation(_ starter: Starter, status: StarterStatus) -> String? {
        guard let last = starter.lastFeeding else { return nil }
        let celsius = "\(number((starter.celsius * 10).rounded() / 10)) °C"
        func after(_ hours: Double) -> String { duration(hours * 3600) }
        if starter.inFridge {
            return "Bei \(celsius) im Kühlschrank wächst der Starter kaum, die Mengen der Fütterung zählen "
                + "deshalb nicht. Die App empfiehlt das Auffrischen nach etwa "
                + "\(after(StarterFridge.refreshHours(celsius: starter.celsius))) und zweimal Auffrischen vor "
                + "dem Backen nach etwa \(after(StarterFridge.refreshTwiceHours(celsius: starter.celsius))), "
                + "jeweils ab der letzten Fütterung. Das sind Richtwerte aus der Praxis, keine Messung."
        }
        return "Bei \(celsius) und \(ratio(last)) (Starter : Mehl : Wasser) erwartet die App den Höhepunkt "
            + "nach etwa \(after(status.peakHours)); hungrig ist er nach etwa "
            + "\(after(status.peakHours * StarterModel.hungryAt)), lange nicht gefüttert nach etwa "
            + "\(after(status.peakHours * StarterModel.neglectedAt)), jeweils ab der Fütterung. "
            + "Das sind Richtwerte, keine Messung."
    }

    /// One line of the feeding log.
    static func feedingLine(_ feeding: Feeding, timeZone: TimeZone = .current) -> String {
        let food = "\(grams(feeding.flourGrams)) Mehl + \(grams(feeding.waterGrams)) Wasser"
        let what = feeding.isEstimate ? "Übernommen: \(grams(feeding.starterGrams)), Fütterung geschätzt"
            : feeding.starterGrams > 0 ? "\(grams(feeding.starterGrams)) Starter + \(food)"
            : "Ansatz: \(food)"
        let rise = feeding.rise.map { " · \($0.logText)" } ?? ""
        return "\(date(feeding.date, timeZone: timeZone)) · \(what)\(rise)"
    }
}

/// Everything the screens show about a starter at one moment, as text.
struct StarterSummary: Equatable {
    static let notFed = "Noch nicht gefüttert"
    static let none = "—"

    /// What the establishing phase adds.
    struct Establishing: Equatable {
        let phase: String
        /// "1 von 2"
        let doubled: String
        let usuallyReadyBy: String
    }

    let stateTitle: String
    let hint: String
    /// "Angesetzt vor", or "Bei dir seit" for a starter that existed before.
    let ageTitle: String
    let age: String
    /// "Füttern oder verwenden bis", or "Füttern bis" in the establishing phase.
    let feedByTitle: String
    let feedBy: String
    let bestWindow: String
    /// In the fridge: from when to refresh twice before baking; `nil` elsewhere.
    let refreshTwice: String?
    /// Why the app says so; `nil` without an estimate.
    let why: String?
    let establishing: Establishing?
    /// When a spontaneous starter became ready; `nil` for others and before.
    let readySince: String?

    init(_ starter: Starter, now: Date, timeZone: TimeZone = .current) {
        func format(_ date: Date) -> String { StarterText.date(date, timeZone: timeZone) }
        ageTitle = starter.origin == .existing ? "Bei dir seit" : "Angesetzt vor"
        age = StarterText.duration(starter.age(at: now))
        readySince = starter.readySince.map(format)
        switch starter.condition(at: now) {
        case .notFed:
            stateTitle = Self.notFed
            hint = Self.notFed
            feedByTitle = "Füttern oder verwenden bis"
            feedBy = Self.none
            bestWindow = Self.none
            refreshTwice = nil
            why = nil
            establishing = nil
        case .establishing(let status):
            stateTitle = "Ansetzphase · Tag \(status.day)"
            hint = status.phase.hint
            feedByTitle = "Füttern bis"
            feedBy = format(status.feedBy)
            bestWindow = Self.none
            refreshTwice = nil
            why = nil
            establishing = Establishing(
                phase: status.phase.title,
                doubled: "\(status.doublingsInARow) von \(StarterEstablishing.doublingsToBeReady)",
                usuallyReadyBy: format(status.usuallyReadyBy))
        case .fed(let status):
            stateTitle = status.state.title
            hint = status.state.hint
            feedBy = format(status.feedBy)
            why = StarterText.explanation(starter, status: status)
            establishing = nil
            if let twice = status.refreshTwiceFrom {
                // In the fridge it is not used from the jar: no best window.
                feedByTitle = "Auffrischen ab"
                bestWindow = Self.none
                refreshTwice = format(twice)
            } else {
                feedByTitle = "Füttern oder verwenden bis"
                bestWindow = "\(format(status.bestFrom)) – \(format(status.bestUntil))"
                refreshTwice = nil
            }
        }
    }

    /// The line under a starter in the list.
    var feedByLine: String { "\(feedByTitle) \(feedBy)" }
}
