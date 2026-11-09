import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

struct TipsTextTests {
    @Test func tipLinksResolveToTopics() {
        #expect(TipsText.topicID(from: URL(string: "tip:pan")!) == .pan)
        #expect(TipsText.topicID(from: URL(string: "tip:kneader")!) == .kneader)
    }

    @Test func theLinkInsideTheTextResolvesToo() {
        // The URL that Markdown produces, not one built by hand.
        let text = TipsText.attributed("Siehe [Kastenform](tip:pan).")
        let urls = text.runs.compactMap(\.link)
        #expect(urls.compactMap(TipsText.topicID(from:)) == [.pan])
    }

    @Test func otherLinksAndUnknownTopicsResolveToNothing() {
        #expect(TipsText.topicID(from: URL(string: "https://example.com/pan")!) == nil)
        #expect(TipsText.topicID(from: URL(string: "tip:unknown")!) == nil)
    }

    @Test func inlineMarkdownBecomesStyledText() {
        let text = TipsText.attributed("Das ist **fett** und [ein Link](tip:pot).")
        #expect(String(text.characters) == "Das ist fett und ein Link.")
        let links = text.runs.compactMap(\.link)
        #expect(links == [URL(string: "tip:pot")!])
    }

    @Test func plainTextStaysAsItIs() {
        #expect(String(TipsText.attributed("Nur Text").characters) == "Nur Text")
    }

    @Test func unreadableMarkdownStaysPlainText() {
        struct Unreadable: Error {}
        let text = TipsText.attributed("**halb", parse: { _ in throw Unreadable() })
        #expect(String(text.characters) == "**halb")
    }

    @Test func categoriesHaveGermanTitles() {
        #expect(TipsTopic.Category.utensils.germanTitle == "Backutensilien")
        #expect(TipsTopic.Category.starters.germanTitle == "Sauerteigstarter")
        #expect(TipsTopic.Category.baking.germanTitle == "Brot backen")
    }

    @Test func everyEquipmentKindOpensTheTopicWithItsOwnId() {
        for kind in EquipmentKind.allCases {
            #expect(kind.tip.rawValue == kind.rawValue)
        }
        #expect(EquipmentKind.allCases.map(\.tip) == [.kneader, .pot, .pan, .basket])
    }
}
