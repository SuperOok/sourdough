/// A dough as the baker weighs it: flour, water and starter, in grams.
///
/// The starter counts towards the totals. It consists of flour and water in
/// the ratio given by its hydration, so 200 g of starter at 100 % hydration
/// hold 100 g flour and 100 g water.
public struct Dough: Equatable, Sendable {
    public var flour: Double
    public var water: Double
    public var starter: Double
    /// Water per 100 parts of flour in the starter, in percent.
    public var starterHydration: Double

    public init(flour: Double, water: Double, starter: Double, starterHydration: Double = 100) {
        self.flour = flour
        self.water = water
        self.starter = starter
        self.starterHydration = starterHydration
    }

    /// Flour added directly plus the flour inside the starter.
    public var totalFlour: Double {
        flour + starter * 100 / (100 + starterHydration)
    }

    /// Water added directly plus the water inside the starter.
    public var totalWater: Double {
        water + starter * starterHydration / (100 + starterHydration)
    }

    /// Total water per total flour, in percent; `nil` without any flour.
    public var hydration: Double? {
        let flour = totalFlour
        guard flour > 0 else { return nil }
        return totalWater / flour * 100
    }
}
