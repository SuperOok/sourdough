import Foundation
import SourdoughKit

/// Text helpers for the tips pages.
enum TipsText {
    static let linkScheme = "tip"

    /// Inline Markdown (bold, italic, links) of one block as styled text; the
    /// plain text if the Markdown cannot be read. `parse` is there for the
    /// tests: real Markdown practically always parses.
    static func attributed(_ markdown: String,
                           parse: (String) throws -> AttributedString = { try AttributedString(markdown: $0) })
        -> AttributedString {
        (try? parse(markdown)) ?? AttributedString(markdown)
    }

    /// The topic a `tip:<id>` link points to; `nil` for other links. Reads the
    /// whole string: the URL that Markdown produces has no `path`.
    static func topicID(from url: URL) -> TipsTopic.ID? {
        let prefix = linkScheme + ":"
        guard url.absoluteString.hasPrefix(prefix) else { return nil }
        return TipsTopic.ID(rawValue: String(url.absoluteString.dropFirst(prefix.count)))
    }
}

extension TipsTopic.Category {
    var germanTitle: String {
        switch self {
        case .utensils: "Backutensilien"
        case .starters: "Sauerteigstarter"
        }
    }
}
