import Foundation

/// The steps of a bake, from checking the starter to the bread ready to cut.
///
/// The process is data: which steps there are (`StepID`), which of them are
/// decisions and what they can be answered (`answers`), and which text each
/// step shows for the chosen equipment and the answers so far (`text`). The
/// texts are Markdown files in `Steps/`, with placeholders in braces
/// (`Placeholder`) that the app fills. To change what the instructions say,
/// edit a file; to add a step or a branch, extend `StepID`, `answers` or
/// `text`, and `docs/ablauf.md` (the Mermaid diagram from `mermaid()`) follows.
public enum BakeProcess {
    /// The steps in their order. Each is planned at a time of the schedule
    /// (`plannedAction`).
    public enum StepID: String, Codable, CaseIterable, Sendable {
        case checkStarter, mixSourdough, checkSourdough, knead, shape, checkProof, preheat, bake, cool
    }

    /// What a decision can be answered.
    public enum Answer: String, Codable, CaseIterable, Sendable {
        case yes, notYet, belowRim, overRim

        /// "Not yet" keeps the step open and shows what to do meanwhile.
        public var waits: Bool { self == .notYet }
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

    /// The answers of a decision; empty for a step that is simply done.
    public static func answers(_ step: StepID, setup: BakeSetup) -> [Answer] {
        switch step {
        case .checkStarter, .checkSourdough: [.yes, .notYet]
        case .checkProof: hasLidDecision(setup) ? [.belowRim, .overRim] : [.yes, .notYet]
        case .mixSourdough, .knead, .shape, .preheat, .bake, .cool: []
        }
    }

    /// Only a loaf pan with a lid asks whether the dough rose over the rim:
    /// then it bakes without the lid, with steam.
    /// A pot bakes with its lid unless it is known to have none.
    static func potHasLid(_ setup: BakeSetup) -> Bool {
        setup.pot?.hasLid != false
    }

    static func hasLidDecision(_ setup: BakeSetup) -> Bool {
        setup.vessel == .loafPan && setup.pan?.hasLid == true
    }

    /// The text of `step` for `setup`, a dough of `ryeShare` percent rye and
    /// the answers so far.
    public static func text(_ step: StepID, setup: BakeSetup, ryeShare: Double,
                            answers: [StepID: Answer]) -> Text {
        switch step {
        case .checkStarter: .checkStarter
        case .mixSourdough: .mixSourdough
        case .checkSourdough: .checkSourdough
        // Rye has no gluten to develop: no stretching and folding.
        case .knead: ryeShare >= BakeRules.freeStandingRyeMax ? .kneadRye : .kneadFold
        case .shape:
            switch setup.vessel {
            case .loafPan: .shapePan
            case .pot, .tray: setup.basket.map { $0.isLong ? .shapeBasketLong : .shapeBasketRound } ?? .shapeBowl
            }
        case .checkProof: hasLidDecision(setup) ? .checkProofRim : .checkProofRipe
        case .preheat:
            switch setup.vessel {
            case .loafPan: .preheatPan
            case .pot: potHasLid(setup) ? .preheatPot : .preheatPotOpen
            case .tray: .preheatTray
            }
        case .bake:
            switch setup.vessel {
            case .loafPan: hasLidDecision(setup) && answers[.checkProof] != .overRim ? .bakePanLid : .bakePanOpen
            case .pot: potHasLid(setup) ? .bakePot : .bakePotOpen
            case .tray: .bakeTray
            }
        case .cool: .cool
        }
    }

    /// What to do while a decision is answered "not yet".
    public static func waitText(_ step: StepID) -> Text? {
        switch step {
        case .checkStarter: .waitStarter
        case .checkSourdough: .waitSourdough
        case .checkProof: .waitProof
        case .mixSourdough, .knead, .shape, .preheat, .bake, .cool: nil
        }
    }

    /// The action of the schedule whose start is the planned time of `step`;
    /// `nil` for cooling, which starts when baking ends.
    public static func plannedAction(_ step: StepID) -> ActionKind? {
        switch step {
        case .checkStarter, .mixSourdough: .mixSourdough
        case .checkSourdough, .knead: .knead
        case .shape: .shape
        case .checkProof, .preheat: .preheat
        case .bake: .bake
        case .cool: nil
        }
    }

    /// The planned time of `step` in `schedule`.
    public static func plannedTime(_ step: StepID, in schedule: Schedule) -> Date {
        guard let action = plannedAction(step) else {
            return schedule.steps.first { $0.kind == .cooling }!.start
        }
        return schedule.steps.first { $0.kind == .action(action) }!.start
    }

    /// The rest that follows `step`, whose temperature and time its text names.
    public static func followingRest(_ step: StepID) -> RestKind? {
        switch step {
        case .mixSourdough: .sourdough
        case .knead: .bulk
        case .shape: .proof
        case .checkStarter, .checkSourdough, .checkProof, .preheat, .bake, .cool: nil
        }
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

    // MARK: Diagram

    /// The process as a Mermaid flowchart, for `docs/ablauf.md`: every step,
    /// every answer and every variant of the equipment.
    public static func mermaid() -> String {
        var lines = ["flowchart TD"]
        let setups: [(String, BakeSetup)] = [
            ("Kastenform mit Deckel", BakeSetup(vessel: .loafPan, pan: EquipmentItem(kind: .pan, name: "", hasLid: true))),
            ("Kastenform ohne Deckel", BakeSetup(vessel: .loafPan, pan: EquipmentItem(kind: .pan, name: ""))),
            ("Bräter mit rundem Gärkörbchen", BakeSetup(vessel: .pot, basket: EquipmentItem(kind: .basket, name: ""))),
            ("Bräter ohne Deckel mit rundem Gärkörbchen",
             BakeSetup(vessel: .pot, pot: EquipmentItem(kind: .pot, name: ""),
                       basket: EquipmentItem(kind: .basket, name: ""))),
            ("Bräter mit länglichem Gärkörbchen",
             BakeSetup(vessel: .pot, basket: EquipmentItem(kind: .basket, name: "", shape: .rectangular))),
            ("Blech, Gare in der Schüssel", BakeSetup(vessel: .tray)),
        ]
        var nodes = Set<String>()
        var edges: [String] = []
        func node(_ text: Text) -> String {
            nodes.insert(text.rawValue)
            return text.rawValue
        }
        for (_, setup) in setups {
            for ryeShare in [0.0, 100] {
                for answers in answerSets(setup) {
                    var previous: String?
                    for step in StepID.allCases {
                        let current = node(text(step, setup: setup, ryeShare: ryeShare, answers: answers))
                        if let previous {
                            // The bake in a pan with a lid depends on the answer about the rim.
                            let decided = step == .bake && hasLidDecision(setup) ? .checkProof : stepBefore(step)
                            let label = answers[decided].map { "|\($0.rawValue)|" } ?? ""
                            edges.append("    \(previous) -->\(label) \(current)")
                        }
                        if let wait = waitText(step), self.answers(step, setup: setup).contains(.notYet) {
                            let hold = node(wait)
                            edges.append("    \(current) -->|notYet| \(hold)")
                            edges.append("    \(hold) --> \(current)")
                        }
                        previous = current
                    }
                }
            }
        }
        lines += nodes.sorted().map { key in
            let text = Text(rawValue: key)!
            let label = "\"\(title(text))\""
            return "    \(key)" + (isDecision(text) ? "{\(label)}" : "[\(label)]")
        }
        var seen = Set<String>()
        lines += edges.filter { seen.insert($0).inserted }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func stepBefore(_ step: StepID) -> StepID {
        StepID.allCases[StepID.allCases.firstIndex(of: step)! - 1]
    }

    private static func isDecision(_ text: Text) -> Bool {
        [.checkStarter, .checkSourdough, .checkProofRim, .checkProofRipe].contains(text)
    }

    /// The combinations of proceeding answers for `setup`.
    private static func answerSets(_ setup: BakeSetup) -> [[StepID: Answer]] {
        let proof = answers(.checkProof, setup: setup).filter { !$0.waits }
        return proof.map { [.checkStarter: .yes, .checkSourdough: .yes, .checkProof: $0] }
    }
}
