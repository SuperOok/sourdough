/// The baking equipment a baker owns. Stored and shown by the app; later
/// recipes can ask what is available.
public struct Equipment: Codable, Equatable, Sendable {
    /// Stand mixer or food processor with a kneading function.
    public var hasKneadingMachine: Bool
    /// Dutch oven or clay baker; `nil` if there is none.
    public var pot: Pot?
    /// Loaf pan; `nil` if there is none.
    public var loafPan: LoafPan?
    /// Banneton for the final proof.
    public var hasProvingBasket: Bool

    public init(hasKneadingMachine: Bool = false,
                pot: Pot? = nil,
                loafPan: LoafPan? = nil,
                hasProvingBasket: Bool = false) {
        self.hasKneadingMachine = hasKneadingMachine
        self.pot = pot
        self.loafPan = loafPan
        self.hasProvingBasket = hasProvingBasket
    }

    /// `true` if nothing is owned.
    public var isEmpty: Bool {
        self == Equipment()
    }

    public struct Pot: Codable, Equatable, Sendable {
        public var hasSiliconeLiner: Bool

        public init(hasSiliconeLiner: Bool = false) {
            self.hasSiliconeLiner = hasSiliconeLiner
        }
    }

    public struct LoafPan: Codable, Equatable, Sendable {
        public enum Material: String, Codable, CaseIterable, Sendable {
            case sheetMetal
            case castIron
        }

        public var material: Material
        public var hasLid: Bool
        public var hasSiliconeLiner: Bool

        public init(material: Material = .sheetMetal,
                    hasLid: Bool = false,
                    hasSiliconeLiner: Bool = false) {
            self.material = material
            self.hasLid = hasLid
            self.hasSiliconeLiner = hasSiliconeLiner
        }
    }
}
