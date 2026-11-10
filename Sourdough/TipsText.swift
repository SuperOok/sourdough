import Foundation
import SourdoughKit
// UIKit only for `UIImage(named:)`: SwiftUI's `Image` cannot tell whether an
// asset is there.
import SwiftUI
import UIKit

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

    /// The picture of an image block: the photo from the assets, or a
    /// placeholder symbol when the photo is not there. Photos whose rights are
    /// not clear stay out of the repository (`.gitignore`).
    static func picture(named name: String) -> UIImage {
        UIImage(named: name) ?? UIImage(systemName: "photo")!
    }

    /// Shows the page of a `tip:<id>` link with `show`; other links go to the
    /// system.
    static func open(_ url: URL, show: (TipsTopic.ID) -> Void) -> OpenURLAction.Result {
        guard let id = topicID(from: url) else { return .systemAction }
        show(id)
        return .handled
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
        case .ingredients: "Zutaten"
        case .baking: "Brot backen"
        }
    }
}
