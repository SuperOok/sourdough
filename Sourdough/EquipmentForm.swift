import Foundation
import Observation
import SourdoughKit

/// The form for one piece of equipment, for a new piece or an existing one.
/// The name is optional (a piece without a typed name gets the name of its
/// kind), and so is the size: all of its fields empty (or 0) mean "not given".
@Observable
final class EquipmentFormModel {
    /// The hint while some measures are given and others are still missing,
    /// e.g. "Noch fehlen: Breite und Höhe. Gib alle Maße an oder keines."
    static func incompleteSize(missing: [String]) -> String {
        let label = missing.count == 1 ? "Noch fehlt" : "Noch fehlen"
        return "\(label): \(missing.joined(separator: " und ")). Gib alle Maße an oder keines."
    }

    let id: UUID
    let kind: EquipmentKind
    var name: String
    var material: EquipmentItem.Material
    var hasLid: Bool
    var hasLiner: Bool
    var shape: Dimensions.Shape
    /// The shape of a banneton, which has no size.
    var basketShape: Dimensions.Shape
    var lengthText: String
    var widthText: String
    var heightText: String

    /// A form for a new piece of that kind. A pot starts round and with a
    /// lid, a pan rectangular and without.
    init(kind: EquipmentKind, id: UUID = UUID()) {
        self.id = id
        self.kind = kind
        name = ""
        material = .sheetMetal
        hasLid = kind == .pot
        hasLiner = false
        shape = kind == .pot ? .round : .rectangular
        basketShape = .round
        lengthText = ""
        widthText = ""
        heightText = ""
    }

    /// A form with the values of an existing piece.
    init(editing item: EquipmentItem) {
        id = item.id
        kind = item.kind
        name = item.name
        material = item.material
        hasLid = item.hasLid
        hasLiner = item.hasSiliconeLiner
        shape = item.dimensions?.shape ?? (item.kind == .pot ? .round : .rectangular)
        basketShape = item.shape
        lengthText = item.dimensions.map { StarterText.number($0.lengthCm) } ?? ""
        widthText = item.dimensions.flatMap { $0.shape == .round ? nil : StarterText.number($0.widthCm) } ?? ""
        heightText = item.dimensions.map { StarterText.number($0.heightCm) } ?? ""
    }

    /// The icon for what the form describes now: it follows the lid and the
    /// shape of a banneton.
    var iconName: String {
        EquipmentIcon.name(EquipmentItem(kind: kind, name: "", hasLid: kind.hasLid && hasLid,
                                         shape: kind.hasShape ? basketShape : .round))
    }

    /// The typed name, or the name of the kind if there is none.
    var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? kind.germanName : trimmed
    }

    /// What the size fields say.
    enum Size: Equatable {
        /// Not given (or not a kind with a size).
        case none
        case given(Dimensions)
        /// Some measures are given, these are still 0 or empty.
        case incomplete(missing: [String])
        case invalid(String)
    }

    /// The identifiers of the size fields on screen, top to bottom: a round
    /// shape has no width, a kind without a size no fields.
    var sizeFields: [String] {
        guard kind.hasDimensions else { return [] }
        return shape == .round ? ["item-length", "item-height"] : ["item-length", "item-width", "item-height"]
    }

    /// The width is not asked for a round shape and is ignored there.
    var size: Size {
        guard kind.hasDimensions else { return .none }
        let isRound = shape == .round
        guard let length = NumberInput.parse(lengthText),
              let height = NumberInput.parse(heightText),
              let width = isRound ? 0 : NumberInput.parse(widthText) else {
            return .invalid(StarterFormModel.numbersOnly)
        }
        let asked = isRound
            ? [("Durchmesser", length), ("Höhe", height)]
            : [("Länge", length), ("Breite", width), ("Höhe", height)]
        let missing = asked.filter { $0.1 == 0 }.map(\.0)
        if missing.count == asked.count { return .none }
        if !missing.isEmpty { return .incomplete(missing: missing) }
        return .given(Dimensions(shape: shape, lengthCm: length, widthCm: width, heightCm: height))
    }

    /// A wrong entry, shown in red.
    var errorText: String? {
        if case .invalid(let message) = size { return message }
        return nil
    }

    /// What is still missing, shown as a hint while the measures are typed.
    var hintText: String? {
        if case .incomplete(let missing) = size { return Self.incompleteSize(missing: missing) }
        return nil
    }

    var isValid: Bool { errorText == nil && hintText == nil }

    /// "2,4 l" once the size is complete, otherwise `nil`.
    var volumeText: String? {
        if case .given(let dimensions) = size { return dimensions.volumeText }
        return nil
    }

    /// The piece, or `nil` if the form is not valid. Details that do not
    /// belong to the kind stay at their defaults.
    func makeItem() -> EquipmentItem? {
        guard isValid else { return nil }
        var dimensions: Dimensions?
        if case .given(let given) = size { dimensions = given }
        return EquipmentItem(
            id: id, kind: kind, name: resolvedName,
            material: kind.hasMaterial ? material : .sheetMetal,
            hasLid: kind.hasLid && hasLid,
            hasSiliconeLiner: kind.hasLiner && hasLiner,
            dimensions: dimensions,
            shape: kind.hasShape ? basketShape : .round)
    }
}
