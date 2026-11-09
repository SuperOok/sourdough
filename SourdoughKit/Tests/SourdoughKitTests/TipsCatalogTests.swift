import Testing
@testable import SourdoughKit

struct TipsCatalogTests {
    @Test func everyTopicHasAFileWithATitleAndContent() {
        for id in TipsTopic.ID.allCases {
            let topic = TipsCatalog.topic(id)
            #expect(topic.id == id)
            #expect(topic.title != id.rawValue, "\(id) hat keine #-Überschrift.")
            #expect(topic.blocks.count > 1, "\(id) hat keinen Inhalt.")
        }
    }

    @Test func titlesOfTheUtensilTopics() {
        #expect(TipsCatalog.topic(.kneader).title == "Küchenmaschine")
        #expect(TipsCatalog.topic(.pot).title == "Bräter und Römertopf")
        #expect(TipsCatalog.topic(.pan).title == "Kastenform")
        #expect(TipsCatalog.topic(.basket).title == "Gärkörbchen")
    }

    @Test func titleFallsBackToTheIdWithoutAHeading() {
        #expect(TipsTopic(id: .pot, markdown: "Nur Text.").title == "pot")
    }

    @Test func allListsEveryTopicOnce() {
        #expect(TipsCatalog.all.map(\.id) == TipsTopic.ID.allCases)
    }

    @Test func topicsAreGroupedIntoCategories() {
        #expect(TipsCatalog.topics(in: .utensils).map(\.id) == [.kneader, .pot, .pan, .basket])
        #expect(TipsCatalog.topics(in: .starters).map(\.id) == [.starter, .starterStates])
        #expect(TipsTopic.Category.allCases == [.utensils, .starters])
    }

    @Test func titlesOfTheStarterTopics() {
        #expect(TipsCatalog.topic(.starter).title == "Sauerteigstarter")
        #expect(TipsCatalog.topic(.starterStates).title == "So wird der Zustand berechnet")
    }

    @Test func everyTipLinkPointsToAnExistingTopic() {
        for topic in TipsCatalog.all {
            for case .paragraph(let text) in topic.blocks + topic.blocks.flatMap(bulletsAsParagraphs) {
                for part in text.components(separatedBy: "(tip:").dropFirst() {
                    let target = String(part.prefix { $0 != ")" })
                    #expect(TipsTopic.ID(rawValue: target) != nil, "\(topic.id): tip:\(target) fehlt.")
                }
            }
        }
    }

    private func bulletsAsParagraphs(_ block: TipsBlock) -> [TipsBlock] {
        if case .bullets(let items) = block { return items.map(TipsBlock.paragraph) }
        return []
    }
}
