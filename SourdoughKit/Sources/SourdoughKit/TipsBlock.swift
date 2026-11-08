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
}

/// Reads the small Markdown subset used for tips pages: `#`, `##`, `- `,
/// paragraphs and blank lines. Inline Markdown (bold, italic, links) stays
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
}
