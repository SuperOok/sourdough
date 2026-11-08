import Observation
import SourdoughKit

/// The state of the equipment wizard: a draft that is edited step by step
/// and only saved when the user finishes.
@Observable
final class EquipmentWizardModel {
    enum Step: Int, CaseIterable {
        case kneader, pot, loafPan, basket

        /// The tips page that belongs to this step.
        var tip: TipsTopic.ID {
            switch self {
            case .kneader: .kneader
            case .pot: .pot
            case .loafPan: .pan
            case .basket: .basket
            }
        }

        var title: String {
            switch self {
            case .kneader: "Küchenmaschine"
            case .pot: "Bräter oder Römertopf"
            case .loafPan: "Kastenform"
            case .basket: "Gärkörbchen"
            }
        }
    }

    var draft: Equipment
    private(set) var step: Step = .kneader

    init(starting equipment: Equipment) {
        draft = equipment
    }

    var isFirstStep: Bool { step == Step.allCases.first }
    var isLastStep: Bool { step == Step.allCases.last }
    /// "Schritt 2 von 4"
    var progressText: String { "Schritt \(step.rawValue + 1) von \(Step.allCases.count)" }

    func next() { if let n = Step(rawValue: step.rawValue + 1) { step = n } }
    func back() { if let p = Step(rawValue: step.rawValue - 1) { step = p } }

    // Bindings for the controls. Switching a part off forgets its details,
    // switching it on starts from the plain variant.

    var hasPot: Bool {
        get { draft.pot != nil }
        set { draft.pot = newValue ? (draft.pot ?? Equipment.Pot()) : nil }
    }

    var potHasLiner: Bool {
        get { draft.pot?.hasSiliconeLiner ?? false }
        set { draft.pot?.hasSiliconeLiner = newValue }
    }

    var hasLoafPan: Bool {
        get { draft.loafPan != nil }
        set { draft.loafPan = newValue ? (draft.loafPan ?? Equipment.LoafPan()) : nil }
    }

    var panMaterial: Equipment.LoafPan.Material {
        get { draft.loafPan?.material ?? .sheetMetal }
        set { draft.loafPan?.material = newValue }
    }

    var panHasLid: Bool {
        get { draft.loafPan?.hasLid ?? false }
        set { draft.loafPan?.hasLid = newValue }
    }

    var panHasLiner: Bool {
        get { draft.loafPan?.hasSiliconeLiner ?? false }
        set { draft.loafPan?.hasSiliconeLiner = newValue }
    }
}
