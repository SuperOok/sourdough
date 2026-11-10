import Foundation

/// What goes into a dough besides flour, water, salt and the sourdough.
/// Shares are percent of the flour. The numbers are rules of thumb, all in
/// one place; the tips page of each add-in explains them.
public enum AddIn: String, Codable, CaseIterable, Sendable {
    /// Sunflower, pumpkin, linseed, sesame: soaked ahead ("Quellstück").
    case seeds
    /// Walnuts, hazelnuts: roasted, roughly chopped, no extra water.
    case nuts
    /// Raisins and other dried fruit: soaked ahead in some water.
    case driedFruit
    /// Fried onions: they draw water from the dough, which gets some on top.
    case roastedOnions
    /// Fresh herbs, chopped: little of them, no extra water.
    case herbs

    /// The share a new add-in starts with.
    public var presetShare: Double {
        switch self {
        case .seeds, .nuts, .driedFruit: 15
        case .roastedOnions: 8
        case .herbs: 3
        }
    }

    /// The shares that make sense: below, the add-in hardly shows; above,
    /// the dough no longer holds together.
    public var shareRange: ClosedRange<Double> {
        switch self {
        case .seeds, .nuts, .driedFruit: 5...30
        case .roastedOnions: 2...15
        case .herbs: 1...6
        }
    }

    /// Grams of water per gram of the add-in that the dough gets on top:
    /// seeds soak in their own weight of water, dried fruit in half of it,
    /// and fried onions take half their weight from the dough.
    public var waterPerGram: Double {
        switch self {
        case .seeds: 1
        case .driedFruit, .roastedOnions: 0.5
        case .nuts, .herbs: 0
        }
    }

    /// Whether it soaks in its water ahead, from the time the sourdough is
    /// mixed; otherwise its water goes into the main dough.
    public var soaks: Bool { self == .seeds || self == .driedFruit }

    /// Whether it goes in at the start of kneading, so that the dough takes
    /// up the soaked seeds; the others go in at the end, so that they do not
    /// tear the dough.
    public var goesInFirst: Bool { self == .seeds }
}

/// The add-ins of a dough with their shares in percent of the flour.
public struct AddIns: Codable, Equatable, Sendable {
    public private(set) var shares: [AddIn: Double]

    public init(_ shares: [AddIn: Double] = [:]) {
        self.shares = shares
    }

    /// The add-ins in the order of `AddIn`.
    public var addIns: [AddIn] { AddIn.allCases.filter { shares[$0] != nil } }

    public var isEmpty: Bool { shares.isEmpty }

    /// The add-ins not in the dough yet.
    public var addable: [AddIn] { AddIn.allCases.filter { shares[$0] == nil } }

    public func share(of addIn: AddIn) -> Double { shares[addIn] ?? 0 }

    /// Adds `addIn` with its preset share.
    public mutating func add(_ addIn: AddIn) {
        shares[addIn] = shares[addIn] ?? addIn.presetShare
    }

    public mutating func remove(_ addIn: AddIn) {
        shares[addIn] = nil
    }

    /// Sets the share of an add-in in the dough, kept within its range.
    public mutating func set(_ addIn: AddIn, to percent: Double) {
        guard shares[addIn] != nil else { return }
        shares[addIn] = min(max(percent, addIn.shareRange.lowerBound), addIn.shareRange.upperBound)
    }

    /// Grams of add-ins and of their water per gram of flour: what the dough
    /// weighs on top of flour, water and salt.
    public var gramsPerFlourGram: Double {
        shares.reduce(0) { $0 + $1.value / 100 * (1 + $1.key.waterPerGram) }
    }
}
