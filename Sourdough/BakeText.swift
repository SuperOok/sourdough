import Foundation
import SourdoughKit

extension Flour {
    /// "Roggen 1150", "Dinkelvollkorn"
    var germanName: String {
        if self == .buckwheat { return "Buchweizenmehl" }
        guard let number = typeNumber else {
            return grain.germanName + "vollkorn"
        }
        return "\(grain.germanName) \(number)"
    }
}

extension BreadType {
    var germanName: String {
        switch self {
        case .wheatBread: "Weizenbrot"
        case .wheatWholeGrainBread: "Weizenvollkornbrot"
        case .wheatMixedBread: "Weizenmischbrot"
        case .speltBread: "Dinkelbrot"
        case .speltMixedBread: "Dinkel-Mischbrot"
        case .ryeMixedBread50: "Roggenmischbrot 50"
        case .ryeMixedBread70: "Roggenmischbrot 70"
        case .ryeBread80: "Roggenbrot 80"
        case .ryeWholeGrainBread: "Roggenvollkornbrot"
        case .buckwheatRyeBread: "Buchweizen-Roggenbrot"
        case .buckwheatSpeltBread: "Buchweizen-Dinkelbrot"
        }
    }

    /// Crumb and taste, in a few words.
    var character: String {
        switch self {
        case .wheatBread: "Locker, mild, mit knuspriger Kruste."
        case .wheatWholeGrainBread: "Saftig, kräftig, leicht nussig."
        case .wheatMixedBread: "Locker mit Roggenwürze, bleibt länger frisch."
        case .speltBread: "Luftig, mild-nussig, schnittfest."
        case .speltMixedBread: "Locker bis mittel, leicht säuerlich."
        case .ryeMixedBread50: "Mitteldicht und würzig."
        case .ryeMixedBread70: "Dicht, feucht, kräftig-säuerlich."
        case .ryeBread80: "Dicht, saftig, aromatisch."
        case .ryeWholeGrainBread: "Sehr dicht, feucht und herb."
        case .buckwheatRyeBread: "Dicht, feucht, nussig-herb."
        case .buckwheatSpeltBread: "Mitteldicht, feucht, mild-nussig."
        }
    }
}

extension AddIn {
    var germanName: String {
        switch self {
        case .seeds: "Saaten"
        case .nuts: "Nüsse"
        case .driedFruit: "Trockenfrüchte"
        case .roastedOnions: "Röstzwiebeln"
        case .herbs: "Kräuter"
        }
    }
}

extension BakeSetup.Vessel {
    var germanName: String {
        switch self {
        case .loafPan: "Kastenform"
        case .pot: "Bräter"
        case .tray: "Blech"
        }
    }
}

/// German texts for planning a bake.
enum BakeText {
    /// "67 g in 67 g Wasser"
    static func soakAmount(_ portion: Recipe.AddInPortion) -> String {
        "\(grams(portion.grams)) in \(grams(portion.waterGrams)) Wasser"
    }

    /// "15 % · 67 g", or only "15 %" without a flour total.
    static func addInAmount(share: Double, totalGrams: Double?) -> String {
        guard let totalGrams else { return percent(share) }
        return "\(percent(share)) · \(grams(totalGrams * share / 100))"
    }

    /// Where the amount of dough comes from.
    static func doughSource(_ setup: BakeSetup) -> String {
        guard let item = setup.vesselItem, let size = item.dimensions else {
            return "Ohne Innenmaße rechnet die App mit \(grams(DoughAmount.defaultGrams)) Teig."
        }
        if setup.vessel == .loafPan {
            return "Aus dem Volumen von „\(item.name)“ (\(size.volumeText)), zu etwa 60 % gefüllt."
        }
        return "Aus der Bodenfläche von „\(item.name)“: Ein runder Bräter mit 27 cm Durchmesser fasst etwa 1 kg Teig."
    }

    /// "30 %", "28,5 %"
    static func percent(_ value: Double) -> String {
        StarterText.number((value * 10).rounded() / 10) + " %"
    }

    /// Whole grams: "248 g"
    static func grams(_ value: Double) -> String {
        "\(Int(value.rounded())) g"
    }

    /// "0–40 %"
    static func range(_ range: ClosedRange<Double>) -> String {
        "\(StarterText.number(range.lowerBound))–\(StarterText.number(range.upperBound)) %"
    }

    static func issue(_ issue: BakeRules.Issue, bread: BreadType) -> String {
        switch issue {
        case .tooLittleRye(let minimum):
            "Zu wenig Roggen: Ein \(bread.germanName) braucht mindestens \(percent(minimum)) Roggen."
        case .tooMuchRye(let maximum):
            "Zu viel Roggen: Ein \(bread.germanName) verträgt höchstens \(percent(maximum)) Roggen."
        case .tooMuchBuckwheat(let maximum):
            "Zu viel Buchweizen: Ohne Gluten wird das Brot ab \(percent(maximum)) dicht und schwer. "
                + "Nimm höchstens \(percent(maximum))."
        case .needsRyeStarter:
            "Ab \(percent(BakeRules.ryeStarterFrom)) Roggen braucht der Teig einen Roggensauerteig. "
                + "Wähle einen Roggenstarter oder nimm weniger Roggen."
        case .overLimit(let flour):
            "\(flour.germanName) liegt über deiner Grenze, und kein anderes Mehl kann den Rest übernehmen."
        case .tooMuchRyeToStandFree:
            "Mit mehr als \(percent(BakeRules.freeStandingRyeMax)) Roggen läuft ein freigeschobenes Brot "
                + "auseinander. Nimm die Kastenform oder weniger Roggen."
        case .missingEquipment(let kind):
            "Für diesen Backweg fehlt ein Utensil: \(kind.germanName)."
        }
    }

    /// The line under the flour list: "Roggen 50 % (erlaubt 40–60 %) · Vollkorn 45 %"
    static func mixSummary(_ mix: FlourMix, bread: BreadType) -> String {
        "Roggen \(percent(mix.ryeShare)) (erlaubt \(range(bread.ryeRange))) · Vollkorn \(percent(mix.wholeGrainShare))"
    }
}

extension Place {
    /// "Kühlschrank (5 °C)"
    func germanName(_ temperatures: Temperatures) -> String {
        let celsius = "\(StarterText.number(temperatures.celsius(self))) °C"
        return switch self {
        case .warm: "Warm (\(celsius))"
        case .room: "Raumtemperatur (\(celsius))"
        case .cool: "Kühl (\(celsius))"
        case .fridge: "Kühlschrank (\(celsius))"
        }
    }
}

/// German texts for the timeline.
enum ScheduleText {
    private static let weekdays = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

    /// "Sa 08:10"
    static func time(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        return String(format: "%@ %02d:%02d", weekdays[parts.weekday! - 1], parts.hour!, parts.minute!)
    }

    /// "Sa"
    static func weekday(_ date: Date, calendar: Calendar) -> String {
        weekdays[calendar.component(.weekday, from: date) - 1]
    }

    /// "14.11."
    static func dayMonth(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.day, .month], from: date)
        return String(format: "%02d.%02d.", parts.day!, parts.month!)
    }

    /// "Sa 14.11. 18:00"
    static func day(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.weekday, .day, .month, .hour, .minute], from: date)
        return String(format: "%@ %02d.%02d. %02d:%02d", weekdays[parts.weekday! - 1],
                      parts.day!, parts.month!, parts.hour!, parts.minute!)
    }

    /// The title of a step; shaping depends on the vessel.
    static func title(_ kind: ScheduleStep.Kind, vessel: BakeSetup.Vessel) -> String {
        switch kind {
        case .action(.mixSourdough): "Sauerteig ansetzen"
        case .action(.knead): "Hauptteig kneten"
        case .action(.shape): vessel == .loafPan ? "Teig in die Form geben" : "Teig formen"
        case .action(.preheat): "Ofen vorheizen"
        case .action(.bake): "Backen"
        case .rest(.sourdough, _): "Sauerteig reift"
        case .rest(.bulk, _): "Stockgare"
        case .rest(.proof, _): "Stückgare"
        case .cooling: "Auskühlen"
        }
    }

    /// A duration rounded to the minute: "1 Std. 3 Min." (1.05 h may come
    /// out of the arithmetic as 1.0499… h and must not show as 1 h 2 min).
    static func duration(hours: Double) -> String {
        StarterText.duration((hours * 60).rounded() * 60)
    }

    /// "1 Std. 3 Min. bis 2 Std. 15 Min."
    static func range(_ hours: ClosedRange<Double>) -> String {
        "\(duration(hours: hours.lowerBound)) bis \(duration(hours: hours.upperBound))"
    }

    /// "Für 7 Std. 30 Min. wären etwa 14 °C nötig."
    static func needed(hours: Double, celsius: Double) -> String {
        "Für \(duration(hours: hours)) wären etwa \(StarterText.number(celsius.rounded())) °C nötig."
    }

    static func conflict(_ step: ScheduleStep, vessel: BakeSetup.Vessel, window: InteractionWindow,
                         calendar: Calendar) -> String {
        "\(title(step.kind, vessel: vessel)) um \(time(step.start, calendar: calendar)) liegt außerhalb von "
            + "\(window.startHour) bis \(window.endHour) Uhr."
    }
}
