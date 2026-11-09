import Foundation

/// What kind of baking equipment a piece is. The raw values are the ids of
/// the tips topics of the same name.
public enum EquipmentKind: String, Codable, CaseIterable, Sendable {
    /// Stand mixer or food processor with a kneading function.
    case kneader
    /// Dutch oven or clay baker.
    case pot
    /// Loaf pan.
    case pan
    /// Banneton for the final proof.
    case basket

    /// Pots and pans have a size, and with it a volume.
    public var hasDimensions: Bool { self == .pot || self == .pan }
    /// Pots and pans can come with a silicone liner.
    public var hasLiner: Bool { self == .pot || self == .pan }
    /// Only a loaf pan has a material and may have a lid.
    public var hasMaterialAndLid: Bool { self == .pan }
}

/// The inner size of a pot or pan, in centimetres, and the volume it gives.
public struct Dimensions: Codable, Equatable, Sendable {
    public enum Shape: String, Codable, CaseIterable, Sendable {
        case rectangular
        case round
        case oval
    }

    public var shape: Shape
    /// The length; the diameter for a round shape.
    public var lengthCm: Double
    /// The width; ignored for a round shape.
    public var widthCm: Double
    public var heightCm: Double

    public init(shape: Shape, lengthCm: Double, widthCm: Double = 0, heightCm: Double) {
        self.shape = shape
        self.lengthCm = lengthCm
        self.widthCm = widthCm
        self.heightCm = heightCm
    }

    /// The volume in millilitres (1 cm³ is 1 ml): length × width × height for
    /// a rectangle, π/4 × length × width × height for an oval, and π/4 ×
    /// diameter² × height for a cylinder.
    public var volumeMilliliters: Double {
        switch shape {
        case .rectangular: lengthCm * widthCm * heightCm
        case .oval: .pi / 4 * lengthCm * widthCm * heightCm
        case .round: .pi / 4 * lengthCm * lengthCm * heightCm
        }
    }

    public var volumeLiters: Double { volumeMilliliters / 1000 }
}

/// One piece of baking equipment of the user. There can be several of a kind,
/// so each has a name to tell them apart. Fields that do not belong to the
/// kind (see `EquipmentKind`) keep their defaults.
public struct EquipmentItem: Codable, Equatable, Identifiable, Sendable {
    public enum Material: String, Codable, CaseIterable, Sendable {
        case sheetMetal
        case castIron
    }

    public var id: UUID
    public var kind: EquipmentKind
    public var name: String
    public var material: Material
    public var hasLid: Bool
    public var hasSiliconeLiner: Bool
    /// The size, if the user gave it; only for pots and pans.
    public var dimensions: Dimensions?

    public init(id: UUID = UUID(), kind: EquipmentKind, name: String,
                material: Material = .sheetMetal, hasLid: Bool = false,
                hasSiliconeLiner: Bool = false, dimensions: Dimensions? = nil) {
        self.id = id
        self.kind = kind
        self.name = name
        self.material = material
        self.hasLid = hasLid
        self.hasSiliconeLiner = hasSiliconeLiner
        self.dimensions = dimensions
    }
}

extension Collection where Element == EquipmentItem {
    /// The kinds of which there is no piece yet, in the order of `EquipmentKind`.
    public var missingKinds: [EquipmentKind] {
        EquipmentKind.allCases.filter { kind in !contains { $0.kind == kind } }
    }
}
