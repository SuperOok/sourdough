import Testing
@testable import SourdoughKit

struct TipsParserTests {
    @Test func anImageStandsOnItsOwnLine() {
        #expect(TipsParser.parse("Text\n![Ein Bild](Foto)\n- Punkt") == [
            .paragraph("Text"), .image(name: "Foto", caption: "Ein Bild"), .bullets(["Punkt"])])
        // Not an image: no closing parenthesis, or no link part.
        #expect(TipsParser.parse("![Bild](Foto") == [.paragraph("![Bild](Foto")])
        #expect(TipsParser.parse("![Bild] (Foto)") == [.paragraph("![Bild] (Foto)")])
        #expect(TipsParser.parse("![](Foto)") == [.image(name: "Foto", caption: "")])
    }

    @Test func anAnimationIsAnImageWithAKnownAnimationName() {
        #expect(TipsParser.parse("![Dehnen](animation:stretchFold)")
                == [.animation(.stretchFold, caption: "Dehnen")])
        // An unknown animation is just a picture of that name, which the app leaves out.
        #expect(TipsParser.parse("![Gibt es nicht](animation:nichtda)")
                == [.image(name: "animation:nichtda", caption: "Gibt es nicht")])
    }

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
