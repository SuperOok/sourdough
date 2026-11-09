import Foundation
import Observation
import SourdoughKit

/// The form for one piece of equipment, for a new piece or an existing one.
/// The name is optional (a piece without a typed name gets the name of its
/// kind), and so is the size: all of its fields empty (or 0) mean "not given".
@Observable
final class EquipmentFormModel {
    static let incompleteSize = "Gib alle Maße an oder keines."

    let id: UUID
    let kind: EquipmentKind
    var name: String
    var material: EquipmentItem.Material
    var hasLid: Bool
    var hasLiner: Bool
    var shape: Dimensions.Shape
    var lengthText: String
    var widthText: String
    var heightText: String

    /// A form for a new piece of that kind. A pot starts round, a pan rectangular.
    init(kind: EquipmentKind, id: UUID = UUID()) {
        self.id = id
        self.kind = kind
        name = ""
        material = .sheetMetal
        hasLid = false
        hasLiner = false
        shape = kind == .pot ? .round : .rectangular
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
        lengthText = item.dimensions.map { StarterText.number($0.lengthCm) } ?? ""
        widthText = item.dimensions.flatMap { $0.shape == .round ? nil : StarterText.number($0.widthCm) } ?? ""
        heightText = item.dimensions.map { StarterText.number($0.heightCm) } ?? ""
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
        case invalid(String)
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
        let asked = isRound ? [length, height] : [length, width, height]
        if asked.allSatisfy({ $0 == 0 }) { return .none }
        if asked.contains(0) { return .invalid(Self.incompleteSize) }
        return .given(Dimensions(shape: shape, lengthCm: length, widthCm: width, heightCm: height))
    }

    var errorText: String? {
        if case .invalid(let message) = size { return message }
        return nil
    }

    var isValid: Bool { errorText == nil }

    /// "2,4 l" once the size is complete, otherwise `nil`.
    var volumeText: String? {
        if case .given(let dimensions) = size { return dimensions.volumeText }
        return nil
    }

    /// The piece, or `nil` if the form is not valid. Details that do not
    /// belong to the kind stay at their defaults.
    func makeItem() -> EquipmentItem? {
        guard errorText == nil else { return nil }
        var dimensions: Dimensions?
        if case .given(let given) = size { dimensions = given }
        return EquipmentItem(
            id: id, kind: kind, name: resolvedName,
            material: kind.hasMaterialAndLid ? material : .sheetMetal,
            hasLid: kind.hasMaterialAndLid && hasLid,
            hasSiliconeLiner: kind.hasLiner && hasLiner,
            dimensions: dimensions)
    }
}
