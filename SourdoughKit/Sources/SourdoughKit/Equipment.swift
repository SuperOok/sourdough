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
    /// Only a loaf pan has a material.
    public var hasMaterial: Bool { self == .pan }
    /// Pots and pans may come with a lid; a pot has one unless said otherwise.
    public var hasLid: Bool { self == .pot || self == .pan }
    /// A banneton is round, oval or long (rectangular); the shape decides how
    /// the dough is shaped.
    public var hasShape: Bool { self == .basket }
    /// A kneading machine kneads with a hook or a blade and has a bowl of
    /// some size.
    public var hasKneadingTool: Bool { self == .kneader }
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

    /// What a kneading machine kneads with: a hook (stand mixers like Bosch,
    /// Kenwood, KitchenAid) or a blade in dough mode (Thermomix, Monsieur
    /// Cuisine). The two need very different times.
    public enum KneadingTool: String, Codable, CaseIterable, Sendable {
        case hook
        case blade
    }

    public var id: UUID
    public var kind: EquipmentKind
    public var name: String
    public var material: Material
    public var hasLid: Bool
    public var hasSiliconeLiner: Bool
    /// The size, if the user gave it; only for pots and pans.
    public var dimensions: Dimensions?
    /// The shape of a banneton; round for everything else.
    public var shape: Dimensions.Shape
    /// What a kneading machine kneads with; a hook for everything else.
    public var kneadingTool: KneadingTool
    /// The bowl of a kneading machine in litres, if the user gave it.
    public var bowlLiters: Double?
    /// The most bread dough a kneading machine takes in grams, as its maker
    /// says, if the user gave it. It overrides the estimate from the bowl.
    public var maxDoughGrams: Double?

    public init(id: UUID = UUID(), kind: EquipmentKind, name: String,
                material: Material = .sheetMetal, hasLid: Bool = false,
                hasSiliconeLiner: Bool = false, dimensions: Dimensions? = nil,
                shape: Dimensions.Shape = .round, kneadingTool: KneadingTool = .hook,
                bowlLiters: Double? = nil, maxDoughGrams: Double? = nil) {
        self.id = id
        self.kind = kind
        self.name = name
        self.material = material
        self.hasLid = hasLid
        self.hasSiliconeLiner = hasSiliconeLiner
        self.dimensions = dimensions
        self.shape = shape
        self.kneadingTool = kneadingTool
        self.bowlLiters = bowlLiters
        self.maxDoughGrams = maxDoughGrams
    }

    /// Whether a loaf from it is long rather than round: an oval or
    /// rectangular banneton.
    public var isLong: Bool { shape != .round }

    private enum CodingKeys: String, CodingKey {
        case id, kind, name, material, hasLid, hasSiliconeLiner, dimensions, shape
        case kneadingTool, bowlLiters, maxDoughGrams
        /// The lid of a pot. Pots saved before they could be lidless are stored
        /// with `hasLid` false for every pot, so a pot has its own key.
        case potLid
    }

    /// Pieces saved before bannetons had a shape are round, pots saved
    /// before they had a lid setting have one, and kneading machines saved
    /// before they had a tool knead with a hook, the more common kind.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(EquipmentKind.self, forKey: .kind)
        name = try container.decode(String.self, forKey: .name)
        material = try container.decode(Material.self, forKey: .material)
        hasLid = kind == .pot
            ? try container.decodeIfPresent(Bool.self, forKey: .potLid) ?? true
            : try container.decode(Bool.self, forKey: .hasLid)
        hasSiliconeLiner = try container.decode(Bool.self, forKey: .hasSiliconeLiner)
        dimensions = try container.decodeIfPresent(Dimensions.self, forKey: .dimensions)
        shape = try container.decodeIfPresent(Dimensions.Shape.self, forKey: .shape) ?? .round
        kneadingTool = try container.decodeIfPresent(KneadingTool.self, forKey: .kneadingTool) ?? .hook
        bowlLiters = try container.decodeIfPresent(Double.self, forKey: .bowlLiters)
        maxDoughGrams = try container.decodeIfPresent(Double.self, forKey: .maxDoughGrams)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(name, forKey: .name)
        try container.encode(material, forKey: .material)
        try container.encode(hasLid, forKey: .hasLid)
        if kind == .pot { try container.encode(hasLid, forKey: .potLid) }
        try container.encode(hasSiliconeLiner, forKey: .hasSiliconeLiner)
        try container.encodeIfPresent(dimensions, forKey: .dimensions)
        try container.encode(shape, forKey: .shape)
        try container.encode(kneadingTool, forKey: .kneadingTool)
        try container.encodeIfPresent(bowlLiters, forKey: .bowlLiters)
        try container.encodeIfPresent(maxDoughGrams, forKey: .maxDoughGrams)
    }
}

extension Collection where Element == EquipmentItem {
    /// The kinds of which there is no piece yet, in the order of `EquipmentKind`.
    public var missingKinds: [EquipmentKind] {
        EquipmentKind.allCases.filter { kind in !contains { $0.kind == kind } }
    }
}
