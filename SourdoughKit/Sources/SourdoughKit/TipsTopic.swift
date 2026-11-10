import Foundation

/// One page of tips and tricks.
public struct TipsTopic: Equatable, Sendable, Identifiable {
    /// Every topic. The raw value is the file name in `Tips/` and the target
    /// of `tip:` links. The utensil topics use the ids of the equipment lines.
    public enum ID: String, CaseIterable, Identifiable, Sendable {
        case kneader, pot, pan, basket
        case starter, starterStates
        case flours, wheat, rye, spelt, buckwheat
        case seeds, nuts, driedFruit, roastedOnions, herbs
        case kneading, proofing, freeStanding, schedule

        public var id: String { rawValue }
    }

    public enum Category: String, CaseIterable, Sendable {
        case utensils
        case starters
        case ingredients
        case baking
    }

    public let id: ID
    public let blocks: [TipsBlock]

    public init(id: ID, markdown: String) {
        self.id = id
        blocks = TipsParser.parse(markdown)
    }

    /// The first `#` heading; the id if the page has none.
    public var title: String {
        for case .title(let title) in blocks { return title }
        return id.rawValue
    }

    /// The page about a grain: the ids are those of `FlourType`.
    public static func id(for grain: FlourType) -> ID { ID(rawValue: grain.rawValue)! }

    /// The page about an add-in: the ids are those of `AddIn`.
    public static func id(for addIn: AddIn) -> ID { ID(rawValue: addIn.rawValue)! }

    public var category: Category {
        switch id {
        case .kneader, .pot, .pan, .basket: .utensils
        case .starter, .starterStates: .starters
        case .flours, .wheat, .rye, .spelt, .buckwheat, .seeds, .nuts, .driedFruit, .roastedOnions, .herbs: .ingredients
        case .kneading, .proofing, .freeStanding, .schedule: .baking
        }
    }
}

/// All tips pages, read from the Markdown files of the package.
public enum TipsCatalog {
    public static func topic(_ id: TipsTopic.ID) -> TipsTopic {
        // A missing file is a programming error; `TipsCatalogTests` makes sure
        // every id has one.
        let url = Bundle.module.url(forResource: id.rawValue, withExtension: "md",
                                    subdirectory: "Tips")!
        return TipsTopic(id: id, markdown: String(decoding: try! Data(contentsOf: url), as: UTF8.self))
    }

    public static var all: [TipsTopic] {
        TipsTopic.ID.allCases.map(topic)
    }

    public static func topics(in category: TipsTopic.Category) -> [TipsTopic] {
        all.filter { $0.category == category }
    }
}
