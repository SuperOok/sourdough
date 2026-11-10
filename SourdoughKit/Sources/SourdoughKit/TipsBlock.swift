import Foundation

/// One block of a tips page.
public enum TipsBlock: Equatable, Sendable {
    /// `# Title` — the page title.
    case title(String)
    /// `## Heading` — a section.
    case heading(String)
    /// Lines up to the next blank line, joined with spaces.
    case paragraph(String)
    /// Consecutive `- item` lines.
    case bullets([String])
    /// `![caption](name)` on a line of its own: a picture from the app's
    /// assets. The app leaves it out when it has no picture of that name.
    case image(name: String, caption: String)
    /// `![caption](animation:name)` on a line of its own: a moving picture the
    /// app draws itself (see `TipsAnimation`).
    case animation(TipsAnimation, caption: String)
}

/// The animations a tips page can show. The raw value is what follows
/// `animation:` in the Markdown; `StretchFold` holds the timing of the first.
public enum TipsAnimation: String, CaseIterable, Sendable {
    /// Stretching and folding a dough in its bowl.
    case stretchFold
}

/// Reads the small Markdown subset used for tips pages: `#`, `##`, `- `,
/// `![caption](name)`, `![caption](animation:name)`, paragraphs and blank lines. Inline Markdown (bold, italic, links) stays
/// in the text and is rendered by the app.
public enum TipsParser {
    public static func parse(_ markdown: String) -> [TipsBlock] {
        var blocks: [TipsBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))) }
            if !bullets.isEmpty { blocks.append(.bullets(bullets)) }
            paragraph = []
            bullets = []
        }

        for raw in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
            } else if line.hasPrefix("## ") {
                flush()
                blocks.append(.heading(String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                flush()
                blocks.append(.title(String(line.dropFirst(2))))
            } else if let image = image(line) {
                flush()
                blocks.append(image)
            } else if line.hasPrefix("- ") {
                if !paragraph.isEmpty { flush() }
                bullets.append(String(line.dropFirst(2)))
            } else {
                if !bullets.isEmpty { flush() }
                paragraph.append(line)
            }
        }
        flush()
        return blocks
    }

    /// `![caption](name)` as an image block; `nil` for any other line.
    static func image(_ line: String) -> TipsBlock? {
        guard line.hasPrefix("!["), line.hasSuffix(")"),
              let middle = line.range(of: "](") else { return nil }
        let caption = line[line.index(line.startIndex, offsetBy: 2)..<middle.lowerBound]
        let name = String(line[middle.upperBound..<line.index(before: line.endIndex)])
        let prefix = "animation:"
        if name.hasPrefix(prefix), let animation = TipsAnimation(rawValue: String(name.dropFirst(prefix.count))) {
            return .animation(animation, caption: String(caption))
        }
        return .image(name: name, caption: String(caption))
    }
}
