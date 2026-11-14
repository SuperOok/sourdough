import Foundation

/// The grain (or pseudo-grain) a flour is made of. A starter is based on rye,
/// wheat or spelt (`starterGrains`); buckwheat is only a flour for the dough.
public enum FlourType: String, Codable, CaseIterable, Sendable {
    case rye, wheat, spelt
    /// A seed of the knotweed family, not a grain: it has no gluten.
    case buckwheat

    /// The grains a starter can be based on.
    public static let starterGrains: [FlourType] = [.rye, .wheat, .spelt]

    /// Relative fermentation time; 1 is wheat. These are rules of thumb, see
    /// `StarterModel`.
    public var timeFactor: Double {
        switch self {
        case .rye: 0.8
        case .wheat: 1.0
        case .spelt: 0.9
        // Not offered for a starter, so this is only for completeness.
        case .buckwheat: 1.0
        }
    }
}

/// How a starter came to be.
public enum StarterOrigin: String, Codable, CaseIterable, Sendable {
    /// It lived before it was added: received from someone or kept for long.
    /// Its first feeding is an estimate, or there is none.
    case existing
    /// Mixed fresh and seeded with a sample of another starter.
    case inoculated
    /// Mixed from flour and water alone; it goes through the establishing
    /// phase first (`Starter.establishing(at:)`).
    case spontaneous
}

/// How far a young starter rose between two feedings, as observed.
public enum Rise: String, Codable, CaseIterable, Sendable {
    case doubled
    case some
    case none
}

/// One feeding: what was kept of the starter and what was added.
///
/// An estimate (`isEstimate`) stands for the unknown last feeding of a starter
/// that was received: its date is approximate, `starterGrams` is the amount
/// received, and flour and water are unknown (0).
public struct Feeding: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    /// Grams of the old starter that were kept; 0 for the very first mix.
    public var starterGrams: Double
    public var flourGrams: Double
    public var waterGrams: Double
    /// The feeding is assumed, not recorded.
    public var isEstimate: Bool
    /// How far the starter rose since the feeding before; only asked in the
    /// establishing phase.
    public var rise: Rise?

    public init(id: UUID = UUID(), date: Date, starterGrams: Double,
                flourGrams: Double, waterGrams: Double, isEstimate: Bool = false, rise: Rise? = nil) {
        self.id = id
        self.date = date
        self.starterGrams = starterGrams
        self.flourGrams = flourGrams
        self.waterGrams = waterGrams
        self.isEstimate = isEstimate
        self.rise = rise
    }

    /// The assumed last feeding of a received starter of `grams`.
    public static func estimate(id: UUID = UUID(), date: Date, grams: Double) -> Feeding {
        Feeding(id: id, date: date, starterGrams: grams, flourGrams: 0, waterGrams: 0, isEstimate: true)
    }

    enum CodingKeys: String, CodingKey {
        case id, date, starterGrams, flourGrams, waterGrams, isEstimate, rise
    }

    /// Feedings saved before estimates and rises existed have neither.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        starterGrams = try container.decode(Double.self, forKey: .starterGrams)
        flourGrams = try container.decode(Double.self, forKey: .flourGrams)
        waterGrams = try container.decode(Double.self, forKey: .waterGrams)
        isEstimate = try container.decodeIfPresent(Bool.self, forKey: .isEstimate) ?? false
        rise = try container.decodeIfPresent(Rise.self, forKey: .rise)
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
    /// When the starter was started ("angesetzt"); for an existing one, when
    /// it was added.
    public var createdAt: Date
    public var origin: StarterOrigin
    public var feedings: [Feeding]
    public var inFridge: Bool
    public var fridgeCelsius: Double
    public var roomCelsius: Double

    public init(id: UUID = UUID(), name: String, flour: FlourType, createdAt: Date,
                feedings: [Feeding] = [], inFridge: Bool = true, fridgeCelsius: Double = 5,
                roomCelsius: Double = defaultRoomCelsius, origin: StarterOrigin = .inoculated) {
        self.id = id
        self.origin = origin
        self.name = name
        self.flour = flour
        self.createdAt = createdAt
        self.feedings = feedings
        self.inFridge = inFridge
        self.fridgeCelsius = fridgeCelsius
        self.roomCelsius = roomCelsius
    }

    enum CodingKeys: String, CodingKey {
        case id, name, flour, createdAt, origin, feedings, inFridge, fridgeCelsius, roomCelsius
    }

    /// Starters saved before the room temperature could be set have none;
    /// they get `defaultRoomCelsius`. Starters saved before the origin existed
    /// were all mixed with a first feeding: they read as `.inoculated`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        flour = try container.decode(FlourType.self, forKey: .flour)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        origin = try container.decodeIfPresent(StarterOrigin.self, forKey: .origin) ?? .inoculated
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

    /// Time since the starter was started (or added, if it existed before);
    /// never negative.
    public func age(at now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(createdAt))
    }
}
