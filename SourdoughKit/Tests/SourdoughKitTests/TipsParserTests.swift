import Testing
@testable import SourdoughKit

struct TipsParserTests {
    @Test func emptyTextHasNoBlocks() {
        #expect(TipsParser.parse("").isEmpty)
        #expect(TipsParser.parse("\n  \n").isEmpty)
    }

    @Test func titleAndHeading() {
        #expect(TipsParser.parse("# Titel\n## Abschnitt") == [.title("Titel"), .heading("Abschnitt")])
    }

    @Test func paragraphLinesAreJoinedWithASpace() {
        #expect(TipsParser.parse("eins\nzwei\n\ndrei") == [.paragraph("eins zwei"), .paragraph("drei")])
    }

    @Test func bulletsFormOneBlock() {
        #expect(TipsParser.parse("- a\n- b\n- c") == [.bullets(["a", "b", "c"])])
    }

    @Test func listsAndParagraphsEndEachOther() {
        #expect(TipsParser.parse("Text\n- a\n- b\nWieder Text") ==
                [.paragraph("Text"), .bullets(["a", "b"]), .paragraph("Wieder Text")])
    }

    @Test func headingsEndOpenBlocks() {
        #expect(TipsParser.parse("Text\n## H\n- a\n# T") ==
                [.paragraph("Text"), .heading("H"), .bullets(["a"]), .title("T")])
    }

    @Test func linesAreTrimmedAndInlineMarkdownIsKept() {
        #expect(TipsParser.parse("   Das ist **fett**, siehe [x](tip:pot).  ") ==
                [.paragraph("Das ist **fett**, siehe [x](tip:pot).")])
    }
}
