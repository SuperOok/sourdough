import Foundation

/// One page of tips and tricks.
public struct TipsTopic: Equatable, Sendable, Identifiable {
    /// Every topic. The raw value is the file name in `Tips/` and the target
    /// of `tip:` links. The utensil topics use the ids of the equipment lines.
    public enum ID: String, CaseIterable, Sendable {
        case kneader, pot, pan, basket
    }

    public enum Category: String, CaseIterable, Sendable {
        case utensils
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

    public var category: Category {
        switch id {
        case .kneader, .pot, .pan, .basket: .utensils
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
