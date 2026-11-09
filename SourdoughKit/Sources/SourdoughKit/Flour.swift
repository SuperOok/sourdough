/// A flour as it is sold: grain plus type number, or whole grain.
///
/// The type number tells the ash content (mg per 100 g of dry flour): the
/// higher it is, the more of the outer layers are in the flour, the more
/// water it takes up. Whole grain flour has no type number.
public enum Flour: String, Codable, CaseIterable, Sendable {
    case rye997, rye1150, rye1370, ryeWholeGrain
    case spelt630, spelt1050, speltWholeGrain
    case wheat405, wheat550, wheat1050, wheatWholeGrain

    public var grain: FlourType {
        switch self {
        case .rye997, .rye1150, .rye1370, .ryeWholeGrain: .rye
        case .spelt630, .spelt1050, .speltWholeGrain: .spelt
        case .wheat405, .wheat550, .wheat1050, .wheatWholeGrain: .wheat
        }
    }

    /// The type number; `nil` for whole grain flour.
    public var typeNumber: Int? {
        switch self {
        case .rye997: 997
        case .rye1150: 1150
        case .rye1370: 1370
        case .spelt630: 630
        case .spelt1050: 1050
        case .wheat405: 405
        case .wheat550: 550
        case .wheat1050: 1050
        case .ryeWholeGrain, .speltWholeGrain, .wheatWholeGrain: nil
        }
    }

    /// Grams of water 100 g of this flour take up in a dough, as a rule of
    /// thumb. The numbers are chosen so that the six bread types land in the
    /// water ranges of the baking notes: darker flour takes more, rye much
    /// more, spelt a little less than wheat of the same type.
    public var waterUptake: Double {
        switch self {
        case .rye997: 80
        case .rye1150: 85
        case .rye1370: 88
        case .ryeWholeGrain: 95
        case .spelt630: 65
        case .spelt1050: 70
        case .speltWholeGrain: 78
        case .wheat405: 63
        case .wheat550: 66
        case .wheat1050: 72
        case .wheatWholeGrain: 80
        }
    }

    /// The flour of the other grain among wheat and spelt that replaces this
    /// one 1:1; `nil` for rye, which cannot stand in for either.
    public var counterpart: Flour? {
        switch self {
        case .wheat405, .wheat550: .spelt630
        case .wheat1050: .spelt1050
        case .wheatWholeGrain: .speltWholeGrain
        case .spelt630: .wheat550
        case .spelt1050: .wheat1050
        case .speltWholeGrain: .wheatWholeGrain
        case .rye997, .rye1150, .rye1370, .ryeWholeGrain: nil
        }
    }
}
