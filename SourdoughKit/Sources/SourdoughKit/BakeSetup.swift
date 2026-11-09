import Foundation

/// The equipment of one bake: what the dough proofs in, what it bakes in,
/// and what kneads it.
///
/// A loaf pan does both, proofing and baking. A free-standing loaf proofs in
/// a banneton, or in a bowl if there is none, and bakes in a pot or on a
/// tray. Bowl and tray count as always at hand.
public struct BakeSetup: Codable, Equatable, Sendable {
    public enum Vessel: String, Codable, CaseIterable, Sendable {
        case loafPan, pot, tray

        public var isFreeStanding: Bool { self != .loafPan }
    }

    public var vessel: Vessel
    /// The loaf pan, when baking in one.
    public var pan: EquipmentItem?
    /// The pot, when baking in one.
    public var pot: EquipmentItem?
    /// The banneton for a free-standing loaf; `nil` proofs in a bowl.
    public var basket: EquipmentItem?
    /// The machine that kneads; `nil` kneads by hand.
    public var kneader: EquipmentItem?

    public init(vessel: Vessel, pan: EquipmentItem? = nil, pot: EquipmentItem? = nil,
                basket: EquipmentItem? = nil, kneader: EquipmentItem? = nil) {
        self.vessel = vessel
        self.pan = pan
        self.pot = pot
        self.basket = basket
        self.kneader = kneader
    }

    /// The vessel's piece of equipment; `nil` for the tray.
    public var vesselItem: EquipmentItem? {
        switch vessel {
        case .loafPan: pan
        case .pot: pot
        case .tray: nil
        }
    }

    /// What does not fit about baking a dough of `ryeShare` percent rye this way.
    public func issues(ryeShare: Double) -> [BakeRules.Issue] {
        var issues: [BakeRules.Issue] = []
        if vessel == .loafPan && pan == nil { issues.append(.missingEquipment(.pan)) }
        if vessel == .pot && pot == nil { issues.append(.missingEquipment(.pot)) }
        if vessel.isFreeStanding && ryeShare > BakeRules.freeStandingRyeMax + FlourMix.tolerance {
            issues.append(.tooMuchRyeToStandFree)
        }
        return issues
    }

    /// A sensible start from what the user has: a loaf pan if the rye share
    /// needs one or there is no pot, else a pot, else the tray; the first
    /// banneton and kneader if there are any.
    public static func proposal(for items: [EquipmentItem], ryeShare: Double) -> BakeSetup {
        let pan = items.first { $0.kind == .pan }
        let pot = items.first { $0.kind == .pot }
        let kneader = items.first { $0.kind == .kneader }
        let basket = items.first { $0.kind == .basket }
        if let pan, ryeShare > BakeRules.freeStandingRyeMax || pot == nil {
            return BakeSetup(vessel: .loafPan, pan: pan, kneader: kneader)
        }
        return BakeSetup(vessel: pot == nil ? .tray : .pot, pot: pot, basket: basket, kneader: kneader)
    }
}

/// How much dough a vessel takes, as rules of thumb from the baking notes.
public enum DoughAmount {
    /// Dough per millilitre of loaf pan: a 10 × 11 × 27 cm pan (2.97 l), filled
    /// to about 60 %, takes about 1.5 kg of dough.
    public static let gramsPerPanMilliliter = 0.5
    /// A round pot of 27 cm takes about 1 kg; other pots in proportion to
    /// their floor area.
    public static let referencePotGrams = 1000.0
    public static let referencePotDiameterCm = 27.0
    /// Dough when nothing tells the size: a loaf on the tray, a pot or pan
    /// without measurements.
    public static let defaultGrams = 1000.0
    /// Salt per flour, in percent.
    public static let saltPercent = 2.0

    /// Grams of dough for `setup`.
    public static func grams(for setup: BakeSetup) -> Double {
        guard let size = setup.vesselItem?.dimensions else { return defaultGrams }
        switch setup.vessel {
        case .loafPan:
            return size.volumeMilliliters * gramsPerPanMilliliter
        case .pot, .tray:
            let reference = Double.pi / 4 * referencePotDiameterCm * referencePotDiameterCm
            return referencePotGrams * floorArea(of: size) / reference
        }
    }

    /// The floor area in cm²: length × width for a rectangle, π/4 × length ×
    /// width for an oval, π/4 × diameter² for a circle.
    public static func floorArea(of size: Dimensions) -> Double {
        switch size.shape {
        case .rectangular: size.lengthCm * size.widthCm
        case .oval: .pi / 4 * size.lengthCm * size.widthCm
        case .round: .pi / 4 * size.lengthCm * size.lengthCm
        }
    }

    /// Grams of flour for `doughGrams` of dough at `hydration` percent water:
    /// dough = flour × (1 + water + salt).
    public static func flourGrams(doughGrams: Double, hydration: Double) -> Double {
        doughGrams / (1 + hydration / 100 + saltPercent / 100)
    }
}
