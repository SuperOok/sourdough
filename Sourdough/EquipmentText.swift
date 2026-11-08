import SourdoughKit

/// One owned item as shown to the user. `id` is stable for tests.
struct EquipmentLine: Equatable, Identifiable {
    let id: String
    let text: String
}

extension Equipment {
    /// The owned items in plain German, in the order of the wizard.
    var lines: [EquipmentLine] {
        var result: [EquipmentLine] = []
        if hasKneadingMachine {
            result.append(EquipmentLine(id: "kneader", text: "Küchenmaschine mit Knetfunktion"))
        }
        if let pot {
            result.append(EquipmentLine(
                id: "pot",
                text: "Bräter/Römertopf \(Self.withOrWithout(pot.hasSiliconeLiner)) Silikoneinlage"))
        }
        if let loafPan {
            let material = loafPan.material.germanName
            let lid = Self.withOrWithout(loafPan.hasLid)
            let liner = Self.withOrWithout(loafPan.hasSiliconeLiner)
            result.append(EquipmentLine(
                id: "pan",
                text: "Kastenform aus \(material), \(lid) Deckel, \(liner) Silikoneinlage"))
        }
        if hasProvingBasket {
            result.append(EquipmentLine(id: "basket", text: "Gärkörbchen"))
        }
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
