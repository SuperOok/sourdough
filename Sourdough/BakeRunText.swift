import Foundation
import SourdoughKit

/// German texts of a running bake: the values for the placeholders of the
/// step texts, the step titles and the answers.
enum BakeRunText {
    /// "„Opa“", or "deinen Starter" without a name.
    static func values(for run: BakeRun, step: BakeProcess.StepID) -> [BakeProcess.Placeholder: String] {
        let recipe = run.recipe
        let schedule = run.schedule
        let calendar = run.calendar
        var values: [BakeProcess.Placeholder: String] = [
            .starter: run.starter.map { "„\($0.name)“" } ?? "deinen Starter",
            .kneading: run.setup.kneader.map { "mit „\($0.name)“" } ?? "von Hand",
            .vessel: run.setup.vesselItem.map { "„\($0.name)“" } ?? "das Blech",
            .proofVessel: run.setup.basket.map { "das Gärkörbchen „\($0.name)“" } ?? "eine Schüssel",
            .sourdoughFlour: portions(recipe.sourdoughFlour, separator: " und "),
            .sourdoughWater: BakeText.grams(recipe.sourdoughWater),
            .starterGrams: BakeText.grams(recipe.starterGrams),
            .mainFlour: portions(recipe.mainFlour, separator: ", "),
            .mainWater: BakeText.grams(recipe.mainWater),
            .salt: BakeText.grams(recipe.salt),
            .waterCelsius: waterCelsius(run),
            .soaker: soaker(recipe),
            .addIns: addIns(recipe),
        ]
        if let rest = BakeProcess.followingRest(step), let resting = schedule.rest(rest) {
            values[.restTemperature] = restTemperature(run.celsius(rest))
            values[.restDuration] = ScheduleText.duration(hours: resting.hours)
            values[.restUntil] = ScheduleText.time(resting.end, calendar: calendar)
        } else {
            values[.restUntil] = ScheduleText.time(schedule.target, calendar: calendar)
        }
        return values
    }

    /// The text of `step` with its values filled in.
    static func markdown(_ run: BakeRun, _ step: BakeProcess.StepID) -> String {
        BakeProcess.fill(BakeProcess.markdown(run.text(step)), values(for: run, step: step))
    }

    /// What to do while `step` waits; `nil` unless it is a decision.
    static func waitMarkdown(_ run: BakeRun, _ step: BakeProcess.StepID) -> String? {
        BakeProcess.waitText(step).map { BakeProcess.fill(BakeProcess.markdown($0), values(for: run, step: step)) }
    }

    /// The `#` title of the step's text.
    static func title(_ run: BakeRun, _ step: BakeProcess.StepID) -> String {
        BakeProcess.title(run.text(step))
    }

    /// "Zurück zu „Sauerteigstufe ansetzen“": the button that opens `step` again.
    static func undoLabel(_ run: BakeRun, _ step: BakeProcess.StepID) -> String {
        "Zurück zu „\(title(run, step))“"
    }

    static func answer(_ answer: BakeProcess.Answer) -> String {
        switch answer {
        case .yes: "Ja"
        case .notYet: "Noch nicht"
        case .belowRim: "Unter dem Rand"
        case .overRim: "Am Deckel oder darüber"
        }
    }

    /// "bei etwa 19 °C": the target temperature of a rest, in whole degrees.
    /// Only the temperature, no place: where the dough finds it is up to the user.
    static func restTemperature(_ celsius: Double) -> String {
        "bei etwa \(Int(celsius.rounded())) °C"
    }

    /// Warm water for a warm bulk rest, else for the usual 26 °C dough.
    static func waterCelsius(_ run: BakeRun) -> String {
        let warm = run.schedule.rest(.bulk)?.kind == .rest(.bulk, .warm)
        let target = warm ? Temperatures.warmCelsius : Temperatures.doughTargetCelsius
        return "\(StarterText.number(run.temperatures.waterCelsius(target: target))) °C"
    }

    /// What soaks along with the sourdough, as a paragraph and a list; empty
    /// without anything to soak.
    static func soaker(_ recipe: Recipe) -> String {
        guard !recipe.soaked.isEmpty else { return "" }
        let lines = recipe.soaked.map { "- \(BakeText.grams($0.grams)) \($0.addIn.germanName) "
            + "in \(BakeText.grams($0.waterGrams)) Wasser" }
        return (["Weiche gleichzeitig in einer zweiten Schüssel ein und decke sie ab:", ""] + lines)
            .joined(separator: "\n")
    }

    /// When the add-ins go into the dough; empty without add-ins.
    static func addIns(_ recipe: Recipe) -> String {
        func amount(_ portion: Recipe.AddInPortion) -> String {
            let soaked = portion.addIn.soaks ? " (eingeweicht)" : ""
            return "\(BakeText.grams(portion.grams)) \(portion.addIn.germanName)\(soaked)"
        }
        let first = recipe.addIns.filter(\.addIn.goesInFirst).map(amount)
        let last = recipe.addIns.filter { !$0.addIn.goesInFirst }.map(amount)
        var sentences: [String] = []
        if !first.isEmpty { sentences.append("Gib gleich \(list(first)) mit dazu.") }
        if !last.isEmpty { sentences.append("Arbeite am Ende des Knetens \(list(last)) kurz unter.") }
        return sentences.joined(separator: " ")
    }

    /// "a", "a und b", "a, b und c"
    static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " und " + items.last!
    }

    /// "112 g Roggen 1150, 134 g Dinkel 1050"
    static func portions(_ portions: [Recipe.Portion], separator: String) -> String {
        portions.map { "\(BakeText.grams($0.grams)) \($0.flour.germanName)" }.joined(separator: separator)
    }

    static func status(_ status: BakeRun.Status) -> String {
        switch status {
        case .active: "läuft"
        case .finished: "fertig"
        case .cancelled: "abgebrochen"
        }
    }
}
