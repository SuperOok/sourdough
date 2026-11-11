import Foundation
import Observation
import SourdoughKit

/// Step one of planning a bake: the bread type, the starter and the flours.
///
/// The model keeps the mix as the user set it; `effectiveMix` is that mix
/// with the limits in grams applied, and every change starts from it.
@Observable
final class BakePlanModel {
    static let defaultTotalText = "1000"
    /// Share a flour starts with when it is added.
    static let addedShare = 10.0
    static let needsFlour = "Gib eine Mehlmenge über 0 g ein."

    var bread: BreadType {
        didSet { if bread != oldValue { mix = bread.preset } }
    }
    private(set) var mix: FlourMix
    var starterID: Starter.ID?
    var totalText = defaultTotalText
    /// The typed limits; an empty text is no limit.
    private(set) var limitTexts: [Flour: String] = [:]

    init(bread: BreadType = .ryeMixedBread50, starterID: Starter.ID? = nil) {
        self.bread = bread
        mix = bread.preset
        self.starterID = starterID
    }

    /// The flour in grams; `nil` unless it is a number above 0.
    var totalGrams: Double? {
        NumberInput.parse(totalText).flatMap { $0 > 0 ? $0 : nil }
    }

    /// The limits in grams that are numbers above 0.
    var limits: [Flour: Double] {
        limitTexts.compactMapValues { text in NumberInput.parse(text).flatMap { $0 > 0 ? $0 : nil } }
    }

    var errorText: String? {
        if limitTexts.values.contains(where: { NumberInput.parse($0) == nil }) {
            return StarterFormModel.numbersOnly
        }
        return totalGrams == nil ? Self.needsFlour : nil
    }

    var effectiveMix: FlourMix {
        totalGrams.map { mix.limited(totalGrams: $0, limits: limits) } ?? mix
    }

    func limitText(_ flour: Flour) -> String {
        limitTexts[flour] ?? ""
    }

    func setLimitText(_ flour: Flour, _ text: String) {
        limitTexts[flour] = text.isEmpty ? nil : text
    }

    func setShare(_ flour: Flour, _ percent: Double) {
        mix = effectiveMix.setting(flour, to: percent)
    }

    func replace(_ old: Flour, with new: Flour) {
        mix = effectiveMix.replacing(old, with: new)
    }

    /// Flours not in the mix, in the order of `Flour.allCases`.
    var addableFlours: [Flour] {
        Flour.allCases.filter { effectiveMix.share(of: $0) == 0 }
    }

    /// Adds `flour` at `addedShare`, or less if the rules allow less.
    func add(_ flour: Flour) {
        guard let top = range(of: flour)?.upperBound, top > 0 else { return }
        setShare(flour, min(Self.addedShare, top))
    }

    func remove(_ flour: Flour) {
        setShare(flour, 0)
    }

    /// Whole percentages `flour` can take; `nil` if none or no amount.
    func range(of flour: Flour) -> ClosedRange<Double>? {
        guard let total = totalGrams else { return nil }
        return BakeRules.range(of: flour, in: effectiveMix, bread: bread, totalGrams: total, limits: limits)
    }

    func grams(of flour: Flour) -> Double? {
        totalGrams.map { effectiveMix.grams(of: flour, totalGrams: $0) }
    }

    var hydration: Double {
        effectiveMix.hydration
    }

    var waterGrams: Double? {
        totalGrams.map { $0 * hydration / 100 }
    }

    /// The chosen starter, if it is among `starters`.
    func starter(in starters: [Starter]) -> Starter? {
        starters.first { $0.id == starterID }
    }

    func issues(starters: [Starter]) -> [BakeRules.Issue] {
        BakeRules.issues(mix: effectiveMix, bread: bread, starterFlour: starter(in: starters)?.flour,
                         totalGrams: totalGrams ?? 0, limits: limits)
            + (setup?.issues(ryeShare: effectiveMix.ryeShare) ?? [])
    }

    // MARK: Step two: equipment and amounts

    /// The equipment; `nil` until step two proposes one.
    private(set) var setup: BakeSetup?

    /// Proposes equipment from `items` unless there is a choice already.
    func proposeSetup(from items: [EquipmentItem]) {
        guard setup == nil else { return }
        setup = BakeSetup.proposal(for: items, ryeShare: effectiveMix.ryeShare)
        takeAmountFromSetup()
    }

    /// Bakes in `vessel`, with the first piece of `items` that fits if none is chosen.
    func chooseVessel(_ vessel: BakeSetup.Vessel, from items: [EquipmentItem]) {
        var new = setup ?? BakeSetup(vessel: vessel)
        new.vessel = vessel
        if vessel == .loafPan, new.pan == nil { new.pan = items.first { $0.kind == .pan } }
        if vessel == .pot, new.pot == nil { new.pot = items.first { $0.kind == .pot } }
        setup = new
        takeAmountFromSetup()
    }

    /// Changes the setup in place, then recomputes the amount.
    func changeSetup(_ change: (inout BakeSetup) -> Void) {
        guard var new = setup else { return }
        change(&new)
        setup = new
        takeAmountFromSetup()
    }

    /// Seeds, nuts and the like, in percent of the flour. They take their
    /// share of the dough, so the flour total follows them.
    var addIns = AddIns() {
        didSet { takeAmountFromSetup() }
    }

    /// Grams of dough the vessel takes; `nil` without a setup.
    var doughGrams: Double? {
        setup.map(DoughAmount.grams)
    }

    /// Sets the flour total to what the vessel takes.
    private func takeAmountFromSetup() {
        guard let dough = doughGrams else { return }
        let flour = DoughAmount.flourGrams(doughGrams: dough, hydration: effectiveMix.hydration, addIns: addIns)
        totalText = String(Int(flour.rounded()))
    }

    // MARK: Step three: schedule

    /// The kitchen; the view writes valid changes back to `KitchenStore`.
    private(set) var temperatures = Temperatures()
    var roomText = "" {
        didSet { if let room = StarterFormModel.parseRoom(roomText) { temperatures.roomCelsius = room } }
    }
    var fridgeText = "" {
        didSet { if let fridge = StarterFormModel.parseFridge(fridgeText) { temperatures.fridgeCelsius = fridge } }
    }
    var coolText = "" {
        didSet { if let cool = StarterFormModel.parseCool(coolText) { temperatures.coolCelsius = cool } }
    }
    /// Whether the kitchen has a cool place the plan may use.
    var usesCoolPlace = true {
        didSet { temperatures.usesCoolPlace = usesCoolPlace }
    }
    var window = InteractionWindow()
    /// When the bread is ready to cut; `nil` until step three proposes one.
    var target: Date?
    private(set) var choices: [RestKind: RestChoice] = [:]
    /// The time the user asked for with plus and minus, where it differs from
    /// what the places allow: the plan shows the temperature it would need.
    private(set) var wishes: [RestKind: Double] = [:]

    /// The target for the date picker, which only shows once there is one.
    var chosenTarget: Date {
        get { target ?? .distantPast }
        set { target = newValue }
    }

    /// The temperatures to start from, as remembered.
    func useTemperatures(_ remembered: Temperatures) {
        roomText = StarterText.number(remembered.roomCelsius)
        fridgeText = StarterText.number(remembered.fridgeCelsius)
        coolText = StarterText.number(remembered.coolCelsius)
        usesCoolPlace = remembered.usesCoolPlace
        temperatures = remembered
    }

    var temperatureError: String? {
        if StarterFormModel.parseRoom(roomText) == nil { return StarterFormModel.roomRange }
        if StarterFormModel.parseFridge(fridgeText) == nil { return StarterFormModel.fridgeRange }
        if usesCoolPlace, StarterFormModel.parseCool(coolText) == nil { return StarterFormModel.coolRange }
        return nil
    }

    /// Proposes a target unless there is one.
    func proposeTarget(now: Date, calendar: Calendar) {
        guard target == nil, let setup else { return }
        target = Schedule.proposedTarget(after: now, ryeShare: effectiveMix.ryeShare, vessel: setup.vessel,
                                         temperatures: temperatures, window: window, calendar: calendar)
    }

    func schedule(calendar: Calendar) -> Schedule? {
        guard let setup, let target else { return nil }
        return Schedule(target: target, ryeShare: effectiveMix.ryeShare, vessel: setup.vessel,
                        temperatures: temperatures, window: window, choices: choices, calendar: calendar)
    }

    /// Fixes `rest` at `hours`. The time stays at the place it has if the
    /// range there holds it; otherwise the rest moves to the place that does
    /// (`ScheduleRules.place`), so the time comes from another temperature and
    /// not from a stretched range. If no place gives that long or short a
    /// rest, the closest one does, and the wish is kept for the hint.
    func setHours(_ hours: Double, of rest: RestKind, calendar: Calendar) {
        guard let step = schedule(calendar: calendar)?.rest(rest),
              case .rest(_, let current) = step.kind else { return }
        let place = ScheduleRules.place(forHours: hours, rest: rest, ryeShare: effectiveMix.ryeShare,
                                        temperatures: temperatures, current: current)
        choices[rest] = RestChoice(place: place, hours: hours)
        wishes[rest] = hours
    }

    /// Changes `rest` by `hours` from what was asked for last, or from the
    /// time it has.
    func stepHours(_ hours: Double, of rest: RestKind, calendar: Calendar) {
        guard let step = schedule(calendar: calendar)?.rest(rest) else { return }
        setHours(max((wishes[rest] ?? step.hours) + hours, 0.25), of: rest, calendar: calendar)
    }

    /// What it would take for `rest` to last as long as the user asked:
    /// `nil` unless the plan could not give that time.
    func needed(for rest: RestKind, in schedule: Schedule) -> (hours: Double, celsius: Double)? {
        guard let wish = wishes[rest], let step = schedule.rest(rest), abs(step.hours - wish) > 0.01 else {
            return nil
        }
        return (wish, ScheduleRules.celsius(rest, ryeShare: effectiveMix.ryeShare, hours: wish))
    }

    /// Moves `rest` to `place`, at its nominal time there.
    func setPlace(_ place: Place, of rest: RestKind) {
        let hours = ScheduleRules.hours(rest, ryeShare: effectiveMix.ryeShare, celsius: temperatures.celsius(place))
        choices[rest] = RestChoice(place: place, hours: hours)
        wishes[rest] = nil
    }

    /// Back to the proposal: no rest fixed.
    func resetChoices() {
        choices = [:]
        wishes = [:]
    }

    /// The bake to start; `nil` while something is missing or does not fit.
    func makeRun(starters: [Starter], now: Date, calendar: Calendar) -> BakeRun? {
        guard errorText == nil, temperatureError == nil, issues(starters: starters).isEmpty,
              let setup, let target, let total = totalGrams else { return nil }
        return BakeRun(startedAt: now, bread: bread, mix: effectiveMix, totalGrams: total, limits: limits,
                       starter: starter(in: starters), setup: setup, temperatures: temperatures, window: window,
                       target: target, choices: choices, timeZone: calendar.timeZone, addIns: addIns)
    }

    /// The amounts in grams; `nil` without a flour total.
    func recipe(starters: [Starter]) -> Recipe? {
        totalGrams.map {
            Recipe(mix: effectiveMix, totalGrams: $0, starterFlour: starter(in: starters)?.flour, addIns: addIns)
        }
    }
}
