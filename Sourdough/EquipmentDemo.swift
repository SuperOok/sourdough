import Foundation
import SourdoughKit

/// Five pieces for the UI tests (`-seedEquipment all`): one of each kind in
/// the non-default variants, and a second, plain loaf pan, to have more than
/// one of a kind.
enum EquipmentDemo {
    static let kneaderName = "Thermomix"
    static let potName = "Römertopf"
    static let ironPanName = "Gusseisenform"
    static let plainPanName = "Kastenform"
    static let basketName = "Gärkörbchen"

    static func items() -> [EquipmentItem] {
        [
            EquipmentItem(kind: .kneader, name: kneaderName),
            EquipmentItem(kind: .pot, name: potName, hasLid: true, hasSiliconeLiner: true,
                          dimensions: Dimensions(shape: .oval, lengthCm: 30, widthCm: 20, heightCm: 12)),
            EquipmentItem(kind: .pan, name: ironPanName, material: .castIron, hasLid: true,
                          hasSiliconeLiner: true,
                          dimensions: Dimensions(shape: .rectangular, lengthCm: 30, widthCm: 10, heightCm: 8)),
            EquipmentItem(kind: .pan, name: plainPanName),
            EquipmentItem(kind: .basket, name: basketName),
        ]
    }
}
