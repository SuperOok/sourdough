import SourdoughKit

/// One item as shown to the user. The id is the one of its tips topic and
/// stable for tests.
struct EquipmentLine: Equatable, Identifiable {
    let topic: TipsTopic.ID
    let text: String

    var id: String { topic.rawValue }
}

extension Equipment {
    /// The owned items in plain German, in the order of the wizard.
    var lines: [EquipmentLine] {
        var result: [EquipmentLine] = []
        if hasKneadingMachine {
            result.append(EquipmentLine(topic: .kneader, text: "Küchenmaschine mit Knetfunktion"))
        }
        if let pot {
            result.append(EquipmentLine(
                topic: .pot,
                text: "Bräter/Römertopf \(Self.withOrWithout(pot.hasSiliconeLiner)) Silikoneinlage"))
        }
        if let loafPan {
            let material = loafPan.material.germanName
            let lid = Self.withOrWithout(loafPan.hasLid)
            let liner = Self.withOrWithout(loafPan.hasSiliconeLiner)
            result.append(EquipmentLine(
                topic: .pan,
                text: "Kastenform aus \(material), \(lid) Deckel, \(liner) Silikoneinlage"))
        }
        if hasProvingBasket {
            result.append(EquipmentLine(topic: .basket, text: "Gärkörbchen"))
        }
        return result
    }

    /// What is not owned yet, in the order of the wizard, without variants.
    var missingLines: [EquipmentLine] {
        var result: [EquipmentLine] = []
        if !hasKneadingMachine {
            result.append(EquipmentLine(topic: .kneader, text: "Küchenmaschine mit Knetfunktion"))
        }
        if pot == nil { result.append(EquipmentLine(topic: .pot, text: "Bräter/Römertopf")) }
        if loafPan == nil { result.append(EquipmentLine(topic: .pan, text: "Kastenform")) }
        if !hasProvingBasket { result.append(EquipmentLine(topic: .basket, text: "Gärkörbchen")) }
        return result
    }

    private static func withOrWithout(_ flag: Bool) -> String {
        flag ? "mit" : "ohne"
    }
}

extension Equipment.LoafPan.Material {
    var germanName: String {
        switch self {
        case .sheetMetal: "Blech"
        case .castIron: "Gusseisen"
        }
    }
}
