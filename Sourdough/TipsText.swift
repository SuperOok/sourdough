import Foundation
import SourdoughKit

/// Text helpers for the tips pages.
enum TipsText {
    static let linkScheme = "tip"

    /// Inline Markdown (bold, italic, links) of one block as styled text.
    static func attributed(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
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
        }
    }
}
