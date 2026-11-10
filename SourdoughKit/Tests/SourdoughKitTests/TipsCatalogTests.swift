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
        #expect(TipsCatalog.topics(in: .ingredients).map(\.id)
                == [.flours, .wheat, .rye, .spelt, .buckwheat, .seeds, .nuts, .driedFruit, .roastedOnions, .herbs])
        #expect(TipsCatalog.topics(in: .baking).map(\.id) == [.kneading, .proofing, .freeStanding, .schedule])
        #expect(TipsTopic.Category.allCases == [.utensils, .starters, .ingredients, .baking])
    }

    @Test func titlesOfTheStarterTopics() {
        #expect(TipsCatalog.topic(.starter).title == "Sauerteigstarter")
        #expect(TipsCatalog.topic(.starterStates).title == "So wird der Zustand berechnet")
    }

    @Test func titlesOfTheBakingTopics() {
        #expect(TipsCatalog.topic(.flours).title == "Mehle und ihre Mischung")
        #expect(TipsCatalog.topic(.kneading).title == "Kneten")
        #expect(TipsCatalog.topic(.schedule).title == "So wird der Zeitplan berechnet")
    }

    @Test func theKneadingPageHasItsPhotoAndTheAnimation() {
        let blocks = TipsCatalog.topic(.kneading).blocks
        #expect(blocks.contains(.image(name: "KneadingPhoto",
                                       caption: "Krume bei zu kurz, richtig und zu lang geknetetem Teig")))
        #expect(blocks.contains(.animation(.stretchFold, caption: "Dehnen und Falten: Teig an einer Seite greifen, "
            + "hochziehen, zur Mitte falten, Schüssel eine Vierteldrehung drehen")))
    }

    @Test func theKneadingPageIsLinkedFromTheFloursTheGrainsAndTheMachine() {
        for id in [TipsTopic.ID.flours, .wheat, .rye, .spelt, .kneader] {
            let linked = TipsCatalog.topic(id).blocks.contains { block in
                switch block {
                case .paragraph(let text): text.contains("(tip:kneading)")
                case .bullets(let items): items.contains { $0.contains("(tip:kneading)") }
                default: false
                }
            }
            #expect(linked, "\(id) verweist nicht auf Kneten.")
        }
    }

    @Test func topicIdsAreIdentifiableByTheirFileName() {
        #expect(TipsTopic.ID.kneading.id == "kneading")
    }

    @Test func titlesOfTheIngredientTopics() {
        #expect([TipsTopic.ID.wheat, .rye, .spelt, .buckwheat, .seeds, .nuts, .driedFruit, .roastedOnions, .herbs]
            .map { TipsCatalog.topic($0).title }
                == ["Weizen", "Roggen", "Dinkel", "Buchweizen", "Saaten", "Nüsse", "Trockenfrüchte",
                    "Röstzwiebeln", "Kräuter"])
    }

    @Test func everyGrainAndAddInHasItsPage() {
        #expect(FlourType.allCases.map(TipsTopic.id(for:)) == [.rye, .wheat, .spelt, .buckwheat])
        #expect(AddIn.allCases.map(TipsTopic.id(for:)) == [.seeds, .nuts, .driedFruit, .roastedOnions, .herbs])
    }

    @Test func theBannetonPageHasItsPhoto() {
        #expect(TipsCatalog.topic(.basket).blocks.contains(
            .image(name: "BasketPhoto", caption: "Ein rundes und ein längliches Gärkörbchen mit Teig")))
    }

    @Test func theTermsProofingAndFreeStandingHavePagesThatAreLinkedWhereTheyAreUsed() {
        #expect(TipsCatalog.topic(.proofing).title == "Gare: Stockgare und Stückgare")
        #expect(TipsCatalog.topic(.freeStanding).title == "Freigeschoben backen")
        func links(_ id: TipsTopic.ID, to target: String) -> Bool {
            TipsCatalog.topic(id).blocks.flatMap { block -> [TipsBlock] in
                if case .bullets(let items) = block { return items.map(TipsBlock.paragraph) }
                return [block]
            }.contains { block in
                if case .paragraph(let text) = block { text.contains("(tip:\(target))") } else { false }
            }
        }
        for id in [TipsTopic.ID.schedule, .kneading, .wheat, .basket] {
            #expect(links(id, to: "proofing"), "\(id.rawValue) verlinkt die Gare nicht.")
        }
        for id in [TipsTopic.ID.rye, .flours, .buckwheat, .proofing] {
            #expect(links(id, to: "freeStanding"), "\(id.rawValue) verlinkt „freigeschoben“ nicht.")
        }
    }

    @Test func theBuckwheatPageHasItsPhotoAndIsLinkedFromTheFlours() {
        #expect(TipsCatalog.topic(.buckwheat).blocks.contains(
            .image(name: "BuckwheatPhoto", caption: "Buchweizenkörner. Foto: V.Boldychev, CC BY-SA 4.0, via Wikimedia Commons.")))
        #expect(TipsCatalog.topic(.buckwheat).category == .ingredients)
        let flours = TipsCatalog.topic(.flours).blocks.flatMap(bulletsAsParagraphs)
        #expect(flours.contains { if case .paragraph(let text) = $0 { text.contains("(tip:buckwheat)") } else { false } })
    }

    @Test func theRyePageShowsRyeEarsWithTheCreditTheLicenseAsks() {
        let blocks = TipsCatalog.topic(.rye).blocks
        #expect(blocks.contains(.image(name: "RyePhoto", caption: "Roggenähren. Foto: Roger Culos, CC BY-SA 3.0, via Wikimedia Commons.")))
        #expect(blocks.contains { block in
            if case .paragraph(let text) = block {
                text.contains("Roger Culos") && text.contains("CC BY-SA 3.0")
            } else { false }
        })
    }

    @Test func theRyePageHasItsOwnPhoto() {
        #expect(TipsCatalog.topic(.rye).blocks.contains(
            .image(name: "RyeBreadPhoto",
                   caption: "Roggenmischbrot aus der Kastenform, frisch angeschnitten. Eigenes Foto.")))
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
