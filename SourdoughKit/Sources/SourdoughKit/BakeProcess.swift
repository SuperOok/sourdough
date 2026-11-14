import Foundation

/// The steps of a bake, from checking the starter to the bread ready to cut,
/// and the actions and rests of its schedule: one definition for both.
///
/// The process is data (`nodes`): steps (`Step`) and rests in their order.
/// A step is an action of the schedule, a decision that is due with the next
/// action, or the cooling at the end. Where a step differs with the
/// equipment, the dough or an earlier answer, it has rules (`Choice`): each
/// a condition (`Condition`) and the variant (`Variant`: text, answers, what
/// to do while waiting) it leads to; the first rule that holds wins, else
/// the variant `otherwise`. The same conditions are evaluated for a running
/// bake (`Context`) and written onto the branches of the diagram
/// (`plantUML()`, `docs/ablauf.puml`).
///
/// The texts are Markdown files in `Steps/`, with placeholders in braces
/// (`Placeholder`) that the app fills. To change what the instructions say,
/// edit a file. To add a step, a branch or a condition, extend `StepID`,
/// `nodes` or `Condition`; run, schedule and diagram follow.
public enum BakeProcess {
    /// The steps in their order. The raw values are stored in the files of
    /// bakes (`BakeRun`) and must stay.
    public enum StepID: String, Codable, CaseIterable, Sendable {
        case checkStarter, mixSourdough, checkSourdough, knead, shape, checkProof, preheat, bake, cool
    }

    /// What a decision can be answered. The raw values are stored.
    public enum Answer: String, Codable, CaseIterable, Sendable {
        case yes, notYet, belowRim, overRim

        /// "Not yet" keeps the step open and shows what to do meanwhile.
        public var waits: Bool { self == .notYet }

        /// The German label of the answer, on its button and in the diagram.
        public var label: String {
            switch self {
            case .yes: "Ja"
            case .notYet: "Noch nicht"
            case .belowRim: "Unter dem Rand"
            case .overRim: "Am Deckel oder darüber"
            }
        }
    }

    /// One text of the instructions; the raw value is the file name in `Steps/`.
    public enum Text: String, CaseIterable, Sendable {
        case checkStarter, mixSourdough, checkSourdough
        case kneadFold, kneadRye
        case shapePan, shapeBasketRound, shapeBasketLong, shapeBowl
        case checkProofRim, checkProofRipe
        case preheatPot, preheatPotOpen, preheatTray, preheatPan
        case bakePot, bakePotOpen, bakeTray, bakePanLid, bakePanOpen
        case cool
        case waitStarter, waitSourdough, waitProof
    }

    /// The values a text can name. The app fills them in German.
    public enum Placeholder: String, CaseIterable, Sendable {
        /// The starter's name.
        case starter
        /// "mit „Thermomix“" or "von Hand".
        case kneading
        /// The loaf pan or pot by name.
        case vessel
        /// "im Gärkörbchen „Körbchen“" or "in einer Schüssel".
        case proofVessel
        /// The flours of the sourdough stage: "78 g Roggenvollkorn".
        case sourdoughFlour
        case sourdoughWater
        case starterGrams
        /// The flours of the main dough.
        case mainFlour
        case mainWater
        /// The temperature of the water for the main dough.
        case waterCelsius
        case salt
        /// What soaks ahead, with its water: a paragraph and a list, or nothing.
        case soaker
        /// When the add-ins go into the dough: a paragraph, or nothing.
        case addIns
        /// The temperature the rest after this step aims for: "bei etwa 19 °C".
        /// Only the temperature: where the dough finds it is up to the user.
        case restTemperature
        /// How long that rest takes, and until when.
        case restDuration
        case restUntil
    }

    // MARK: Conditions

    /// What a branch of the process depends on: everything a running bake
    /// knows about itself.
    public struct Context: Sendable {
        public var setup: BakeSetup
        /// Percent rye of the flour.
        public var ryeShare: Double
        /// The answers so far.
        public var answers: [StepID: Answer]

        public init(setup: BakeSetup, ryeShare: Double = 0, answers: [StepID: Answer] = [:]) {
            self.setup = setup
            self.ryeShare = ryeShare
            self.answers = answers
        }
    }

    /// A condition of a branch, with its German label for the diagram.
    public enum Condition: Hashable, Sendable {
        /// At least this percent rye.
        case ryeShareAtLeast(Double)
        /// The bread bakes in or on this.
        case vessel(BakeSetup.Vessel)
        /// In a loaf pan that has a lid.
        case panWithLid
        /// In a pot with its lid; a pot not known to have none has one.
        case potWithLid
        /// In a pot known to have no lid.
        case potWithoutLid
        /// A free-standing loaf proofs in a banneton, long or round.
        case basket(long: Bool)
        /// Kneaded by a machine with this tool; by hand is neither.
        case kneadingTool(EquipmentItem.KneadingTool)
        /// The decision was answered so.
        case answer(StepID, Answer)
        /// All of them.
        case all([Condition])

        public func holds(in context: Context) -> Bool {
            let setup = context.setup
            switch self {
            case .ryeShareAtLeast(let share): return context.ryeShare >= share
            case .vessel(let vessel): return setup.vessel == vessel
            case .panWithLid: return setup.vessel == .loafPan && setup.pan?.hasLid == true
            case .potWithLid: return setup.vessel == .pot && setup.pot?.hasLid != false
            case .potWithoutLid: return setup.vessel == .pot && setup.pot?.hasLid == false
            case .basket(let long): return setup.basket.map { $0.isLong == long } ?? false
            case .kneadingTool(let tool): return setup.kneader?.kneadingTool == tool
            case .answer(let step, let answer): return context.answers[step] == answer
            case .all(let conditions): return conditions.allSatisfy { $0.holds(in: context) }
            }
        }

        /// "Roggen ab 50 %", "Kastenform mit Deckel und Antwort „Am Deckel oder darüber“".
        public var label: String {
            switch self {
            case .ryeShareAtLeast(let share): "Roggen ab \(Self.number(share)) %"
            case .vessel(.loafPan): "Kastenform"
            case .vessel(.pot): "Bräter"
            case .vessel(.tray): "Blech"
            case .panWithLid: "Kastenform mit Deckel"
            case .potWithLid: "Bräter mit Deckel"
            case .potWithoutLid: "Bräter ohne Deckel"
            case .basket(long: true): "längliches Gärkörbchen"
            case .basket(long: false): "rundes Gärkörbchen"
            case .kneadingTool(.hook): "Küchenmaschine mit Knethaken"
            case .kneadingTool(.blade): "Küchenmaschine mit Messer"
            case .answer(_, let answer): "Antwort „\(answer.label)“"
            case .all(let conditions): conditions.map(\.label).joined(separator: " und ")
            }
        }

        /// The simple conditions this one is made of: itself, unless it
        /// combines others.
        public var atoms: [Condition] {
            if case .all(let conditions) = self { return conditions.flatMap(\.atoms) }
            return [self]
        }

        /// "50", "49,5"
        static func number(_ value: Double) -> String {
            value == value.rounded() ? String(Int(value)) : String(value).replacingOccurrences(of: ".", with: ",")
        }
    }

    /// A value that depends on conditions: the first rule that holds, else
    /// `otherwise`.
    public struct Choice<Value: Sendable>: Sendable {
        public struct Rule: Sendable {
            public let condition: Condition
            public let value: Value
        }

        public let rules: [Rule]
        public let otherwise: Value

        /// Always `value`.
        init(_ value: Value) {
            rules = []
            otherwise = value
        }

        init(_ rules: [(Condition, Value)], otherwise: Value) {
            self.rules = rules.map { Rule(condition: $0.0, value: $0.1) }
            self.otherwise = otherwise
        }

        public func value(in context: Context) -> Value {
            rules.first { $0.condition.holds(in: context) }?.value ?? otherwise
        }

        /// Every value with the condition that leads to it; `nil` for
        /// `otherwise`, the last.
        public var branches: [(condition: Condition?, value: Value)] {
            rules.map { ($0.condition, $0.value) } + [(nil, otherwise)]
        }
    }

    /// What a step shows: its text and, for a decision, its answers and
    /// what to do while it waits.
    public struct Variant: Sendable {
        public let text: Text
        /// Empty for a step that is simply done.
        public let answers: [Answer]
        /// What to do while a decision is answered "not yet".
        public let wait: Text?

        init(_ text: Text, answers: [Answer] = [], wait: Text? = nil) {
            self.text = text
            self.answers = answers
            self.wait = wait
        }
    }

    /// One step of a bake.
    public struct Step: Sendable {
        /// When the step is due in the schedule.
        public enum Timing: Sendable, Equatable {
            /// An action of the schedule, which takes
            /// `ScheduleRules.minutes`. One that overlaps the rest before it
            /// runs during its end (preheating during the proof).
            case action(ActionKind, overlapsRest: Bool = false)
            /// A decision, due when the next action starts.
            case beforeNextAction
            /// The cooling at the end, after the last action.
            case cooling
        }

        public let id: StepID
        public let timing: Timing
        public let variants: Choice<Variant>
    }

    /// A node of the process: a step, or a rest of the dough between steps
    /// (with its German name for the diagram).
    public enum Node: Sendable {
        case step(Step)
        case rest(RestKind, String)
    }

    /// The process, in its order.
    public static let nodes: [Node] = {
        let check: [Answer] = [.yes, .notYet]
        return [
            .step(Step(id: .checkStarter, timing: .beforeNextAction,
                       variants: Choice(Variant(.checkStarter, answers: check, wait: .waitStarter)))),
            .step(Step(id: .mixSourdough, timing: .action(.mixSourdough), variants: Choice(Variant(.mixSourdough)))),
            .rest(.sourdough, "Sauerteig reift"),
            .step(Step(id: .checkSourdough, timing: .beforeNextAction,
                       variants: Choice(Variant(.checkSourdough, answers: check, wait: .waitSourdough)))),
            // Rye has no gluten to develop: no stretching and folding.
            .step(Step(id: .knead, timing: .action(.knead),
                       variants: Choice([(.ryeShareAtLeast(BakeRules.freeStandingRyeMax), Variant(.kneadRye))],
                                        otherwise: Variant(.kneadFold)))),
            .rest(.bulk, "Stockgare"),
            .step(Step(id: .shape, timing: .action(.shape),
                       variants: Choice([(.vessel(.loafPan), Variant(.shapePan)),
                                         (.basket(long: true), Variant(.shapeBasketLong)),
                                         (.basket(long: false), Variant(.shapeBasketRound))],
                                        otherwise: Variant(.shapeBowl)))),
            .rest(.proof, "Stückgare"),
            // Only a loaf pan with a lid asks whether the dough rose over the
            // rim: then it bakes without the lid, with steam.
            .step(Step(id: .checkProof, timing: .beforeNextAction,
                       variants: Choice([(.panWithLid, Variant(.checkProofRim, answers: [.belowRim, .overRim]))],
                                        otherwise: Variant(.checkProofRipe, answers: check, wait: .waitProof)))),
            .step(Step(id: .preheat, timing: .action(.preheat, overlapsRest: true),
                       variants: Choice([(.vessel(.loafPan), Variant(.preheatPan)),
                                         (.potWithLid, Variant(.preheatPot)),
                                         (.potWithoutLid, Variant(.preheatPotOpen))],
                                        otherwise: Variant(.preheatTray)))),
            .step(Step(id: .bake, timing: .action(.bake),
                       variants: Choice([(.all([.panWithLid, .answer(.checkProof, .overRim)]), Variant(.bakePanOpen)),
                                         (.panWithLid, Variant(.bakePanLid)),
                                         (.vessel(.loafPan), Variant(.bakePanOpen)),
                                         (.potWithLid, Variant(.bakePot)),
                                         (.potWithoutLid, Variant(.bakePotOpen))],
                                        otherwise: Variant(.bakeTray)))),
            .step(Step(id: .cool, timing: .cooling, variants: Choice(Variant(.cool)))),
        ]
    }()

    /// The steps, in their order.
    public static let steps: [Step] = nodes.compactMap { node in
        if case .step(let step) = node { return step }
        return nil
    }

    /// The step `id`.
    public static func step(_ id: StepID) -> Step {
        steps.first { $0.id == id }!
    }

    /// What `step` shows in `context`.
    public static func variant(_ step: StepID, in context: Context) -> Variant {
        self.step(step).variants.value(in: context)
    }

    /// The answers of a decision; empty for a step that is simply done.
    public static func answers(_ step: StepID, in context: Context) -> [Answer] {
        variant(step, in: context).answers
    }

    /// The text of `step` for `setup`, a dough of `ryeShare` percent rye and
    /// the answers so far.
    public static func text(_ step: StepID, setup: BakeSetup, ryeShare: Double,
                            answers: [StepID: Answer]) -> Text {
        variant(step, in: Context(setup: setup, ryeShare: ryeShare, answers: answers)).text
    }

    /// What to do while a decision is answered "not yet"; `nil` for a step
    /// that cannot wait.
    public static func waitText(_ step: StepID, in context: Context) -> Text? {
        variant(step, in: context).wait
    }

    // MARK: Schedule

    /// What the schedule plans, in its order.
    public enum TimelineItem: Equatable, Sendable {
        case action(ActionKind, overlapsRest: Bool)
        case rest(RestKind)
        case cooling
    }

    /// The actions and rests of the process, without the decisions: what
    /// `Schedule` plans.
    public static let timeline: [TimelineItem] = nodes.compactMap { node in
        switch node {
        case .rest(let rest, _): .rest(rest)
        case .step(let step):
            switch step.timing {
            case .action(let action, let overlaps): .action(action, overlapsRest: overlaps)
            case .beforeNextAction: nil
            case .cooling: .cooling
            }
        }
    }

    /// The action of the schedule whose start is the planned time of `step`:
    /// its own, or for a decision the next one; `nil` for cooling, which
    /// starts when baking ends.
    public static func plannedAction(_ step: StepID) -> ActionKind? {
        let due = steps.drop { $0.id != step }.first { $0.timing != .beforeNextAction }!
        if case .action(let action, _) = due.timing { return action }
        return nil
    }

    /// The planned time of `step` in `schedule`.
    public static func plannedTime(_ step: StepID, in schedule: Schedule) -> Date {
        guard let action = plannedAction(step) else {
            return schedule.steps.first { $0.kind == .cooling }!.start
        }
        return schedule.steps.first { $0.kind == .action(action) }!.start
    }

    /// The rest that directly follows `step`, whose temperature and time its
    /// text names.
    public static func followingRest(_ step: StepID) -> RestKind? {
        let index = nodes.firstIndex { node in
            if case .step(let candidate) = node { return candidate.id == step }
            return false
        }!
        guard index + 1 < nodes.count, case .rest(let rest, _) = nodes[index + 1] else { return nil }
        return rest
    }

    // MARK: Texts

    /// The Markdown of `text`, with its placeholders.
    public static func markdown(_ text: Text) -> String {
        // A missing file is a programming error; `BakeProcessTests` makes sure
        // every text has one.
        let url = Bundle.module.url(forResource: text.rawValue, withExtension: "md", subdirectory: "Steps")!
        return String(decoding: try! Data(contentsOf: url), as: UTF8.self)
    }

    /// The `#` title of `text`.
    public static func title(_ text: Text) -> String {
        title(ofMarkdown: markdown(text), fallback: text.rawValue)
    }

    static func title(ofMarkdown markdown: String, fallback: String) -> String {
        for case .title(let title) in TipsParser.parse(markdown) { return title }
        return fallback
    }

    /// `markdown` with every `{placeholder}` replaced by its value; unknown
    /// or missing ones stay as they are.
    public static func fill(_ markdown: String, _ values: [Placeholder: String]) -> String {
        values.reduce(markdown) { text, value in
            text.replacingOccurrences(of: "{\(value.key.rawValue)}", with: value.value)
        }
    }

    /// The placeholders `markdown` names, in order of appearance.
    public static func placeholders(in markdown: String) -> [String] {
        markdown.components(separatedBy: "{").dropFirst().compactMap { part in
            part.contains("}") ? String(part.prefix { $0 != "}" }) : nil
        }
    }
}
