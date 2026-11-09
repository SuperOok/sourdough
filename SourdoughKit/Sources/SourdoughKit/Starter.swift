import Foundation

/// The flour a starter is based on.
public enum FlourType: String, Codable, CaseIterable, Sendable {
    case rye, wheat, spelt

    /// Relative fermentation time; 1 is wheat. These are rules of thumb, see
    /// `StarterModel`.
    public var timeFactor: Double {
        switch self {
        case .rye: 0.8
        case .wheat: 1.0
        case .spelt: 0.9
        }
    }
}

/// One feeding: what was kept of the starter and what was added.
public struct Feeding: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    /// Grams of the old starter that were kept; 0 for the very first mix.
    public var starterGrams: Double
    public var flourGrams: Double
    public var waterGrams: Double

    public init(id: UUID = UUID(), date: Date, starterGrams: Double,
                flourGrams: Double, waterGrams: Double) {
        self.id = id
        self.date = date
        self.starterGrams = starterGrams
        self.flourGrams = flourGrams
        self.waterGrams = waterGrams
    }

    /// Water per 100 parts of flour in the added food; `nil` without flour.
    public var hydration: Double? {
        flourGrams > 0 ? waterGrams / flourGrams * 100 : nil
    }
}

/// A sourdough starter and its history.
public struct Starter: Codable, Equatable, Sendable, Identifiable {
    /// Kitchen temperature for a starter that is not in the fridge, unless
    /// the user gives another.
    public static let defaultRoomCelsius = 22.0

    public var id: UUID
    public var name: String
    public var flour: FlourType
    /// When the starter was started ("angesetzt").
    public var createdAt: Date
    public var feedings: [Feeding]
    public var inFridge: Bool
    public var fridgeCelsius: Double
    public var roomCelsius: Double

    public init(id: UUID = UUID(), name: String, flour: FlourType, createdAt: Date,
                feedings: [Feeding] = [], inFridge: Bool = true, fridgeCelsius: Double = 5,
                roomCelsius: Double = defaultRoomCelsius) {
        self.id = id
        self.name = name
        self.flour = flour
        self.createdAt = createdAt
        self.feedings = feedings
        self.inFridge = inFridge
        self.fridgeCelsius = fridgeCelsius
        self.roomCelsius = roomCelsius
    }

    enum CodingKeys: String, CodingKey {
        case id, name, flour, createdAt, feedings, inFridge, fridgeCelsius, roomCelsius
    }

    /// Starters saved before the room temperature could be set have none;
    /// they get `defaultRoomCelsius`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        flour = try container.decode(FlourType.self, forKey: .flour)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        feedings = try container.decode([Feeding].self, forKey: .feedings)
        inFridge = try container.decode(Bool.self, forKey: .inFridge)
        fridgeCelsius = try container.decode(Double.self, forKey: .fridgeCelsius)
        roomCelsius = try container.decodeIfPresent(Double.self, forKey: .roomCelsius) ?? Self.defaultRoomCelsius
    }

    /// The temperature the starter is kept at.
    public var celsius: Double {
        inFridge ? fridgeCelsius : roomCelsius
    }

    /// The most recent feeding by date.
    public var lastFeeding: Feeding? {
        feedings.max { $0.date < $1.date }
    }

    /// Time since the starter was started; never negative.
    public func age(at now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(createdAt))
    }
}
