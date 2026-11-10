import Foundation
import SourdoughKit

extension EquipmentKind {
    /// The name of the kind, which is also the name a new piece gets when the
    /// user types none.
    var germanName: String {
        switch self {
        case .kneader: "Küchenmaschine"
        case .pot: "Bräter/Römertopf"
        case .pan: "Kastenform"
        case .basket: "Gärkörbchen"
        }
    }

    /// The tips page of the kind.
    var tip: TipsTopic.ID {
        switch self {
        case .kneader: .kneader
        case .pot: .pot
        case .pan: .pan
        case .basket: .basket
        }
    }
}

extension EquipmentItem.Material {
    var germanName: String {
        switch self {
        case .sheetMetal: "Blech"
        case .castIron: "Gusseisen"
        }
    }
}

extension Dimensions.Shape {
    var germanName: String {
        switch self {
        case .rectangular: "Rechteckig"
        case .round: "Rund"
        case .oval: "Oval"
        }
    }
}

extension Dimensions {
    /// "30 × 10 × 8 cm", "oval 30 × 20 × 12 cm", "rund Ø 24 × 10 cm"
    var germanText: String {
        let length = StarterText.number(lengthCm)
        let width = StarterText.number(widthCm)
        let height = StarterText.number(heightCm)
        return switch shape {
        case .rectangular: "\(length) × \(width) × \(height) cm"
        case .oval: "oval \(length) × \(width) × \(height) cm"
        case .round: "rund Ø \(length) × \(height) cm"
        }
    }

    /// "2,4 l", "5 l": the volume rounded to a tenth of a litre.
    var volumeText: String {
        StarterText.number((volumeLiters * 10).rounded() / 10) + " l"
    }
}

extension EquipmentItem {
    /// What the piece is, in plain German: the kind with its variant and, if
    /// given, its size and volume.
    var detailText: String {
        var parts: [String] = []
        switch kind {
        case .kneader: parts.append("Küchenmaschine mit Knetfunktion")
        case .pot:
            parts.append("Bräter/Römertopf, \(Self.withOrWithout(hasLid)) Deckel, "
                         + "\(Self.withOrWithout(hasSiliconeLiner)) Silikoneinlage")
        case .pan:
            parts.append("Kastenform aus \(material.germanName), \(Self.withOrWithout(hasLid)) Deckel, "
                         + "\(Self.withOrWithout(hasSiliconeLiner)) Silikoneinlage")
        case .basket: parts.append("Gärkörbchen, \(shape.germanName.lowercased())")
        }
        if let dimensions {
            parts.append(dimensions.germanText)
            parts.append(dimensions.volumeText)
        }
        return parts.joined(separator: " · ")
    }

    private static func withOrWithout(_ flag: Bool) -> String {
        flag ? "mit" : "ohne"
    }
}
