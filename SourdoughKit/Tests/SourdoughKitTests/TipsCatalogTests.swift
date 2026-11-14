import Foundation
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
        #expect(TipsCatalog.topics(in: .starters).map(\.id) == [.starter, .starterFromScratch, .starterCare])
        #expect(TipsCatalog.topics(in: .ingredients).map(\.id)
                == [.flours, .wheat, .rye, .spelt, .buckwheat, .seeds, .nuts, .driedFruit, .roastedOnions, .herbs])
        #expect(TipsCatalog.topics(in: .baking).map(\.id) == [.kneading, .proofing, .freeStanding, .temperature, .schedule])
        #expect(TipsCatalog.topics(in: .app).map(\.id)
                == [.start, .planFlours, .planSetup, .planSchedule, .run, .log, .logDetail, .equipmentList,
                    .starterNew, .starterFeed])
        #expect(TipsTopic.Category.allCases == [.utensils, .starters, .ingredients, .baking, .app])
    }

    @Test func everyTopicBelongsToExactlyOneCategory() {
        // 4 utensils + 3 starter + 10 ingredients + 5 baking + 10 app pages = 32, counted by hand.
        #expect(TipsTopic.ID.allCases.count == 32)
        let grouped = TipsTopic.Category.allCases.flatMap { TipsCatalog.topics(in: $0).map(\.id) }
        #expect(grouped.count == 32)
        #expect(Set(grouped).count == 32)
    }

    @Test func titlesOfTheAppTopics() {
        #expect([TipsTopic.ID.start, .planFlours, .planSetup, .planSchedule, .run, .log, .logDetail,
                 .equipmentList, .starterNew, .starterFeed].map { TipsCatalog.topic($0).title }
                == ["Willkommen", "Mehle wählen", "Utensilien und Menge", "Zeitplan einstellen", "Der Durchgang",
                    "Das Backprotokoll", "Ein Durchgang im Protokoll", "Backutensilien verwalten", "Neuen Starter anlegen", "Starter füttern"])
    }

    @Test func theAppPagesLeadOnToTheSubjectPagesTheyAreAbout() {
        #expect(links(in: .planSchedule).isSuperset(of: ["temperature", "proofing", "schedule"]))
        #expect(links(in: .planFlours).isSuperset(of: ["flours", "starter", "planSetup"]))
        #expect(links(in: .planSetup).isSuperset(of: ["pan", "pot", "basket", "kneader", "freeStanding", "planSchedule"]))
        #expect(links(in: .equipmentList).isSuperset(of: ["kneader", "pot", "pan", "basket"]))
        #expect(links(in: .starterNew).contains("starterFeed"))
        #expect(links(in: .log).contains("logDetail"))
        #expect(links(in: .logDetail).isSuperset(of: ["run", "log", "planFlours"]))
        #expect(links(in: .run).isSuperset(of: ["kneading", "log", "planSchedule"]))
        #expect(links(in: .start).isSuperset(of: ["planFlours", "planSetup", "planSchedule", "run", "log",
                                                   "equipmentList", "starter"]))
    }

    @Test func theStartPageStatesWhatTheAppDoesNotDoAndLeavesTheVersionToTheApp() {
        let text = plainText(.start)
        #expect(text.contains("weckt dich nicht"))
        #expect(text.contains("kein Tagebuch"))
        #expect(!text.contains("Version"))
    }

    @Test func titlesOfTheStarterTopics() {
        #expect(TipsCatalog.topic(.starter).title == "Sauerteigstarter")
        #expect(TipsCatalog.topic(.starterFromScratch).title == "Starter selbst ansetzen")
    }

    @Test func theStarterPageNamesTheFridgeLimitsOfTheModel() {
        // At 4 °C 7 and 21 days. At 5 °C 7 × 3^(−0.1) ≈ 6.27 days ("gut 6") and
        // 21 × 0.896 ≈ 18.8 days ("knapp 19"); at 14 °C 7 / 3 ≈ 2.33 days ("gut 2").
        let text = plainText(.starter)
        for part in ["Bei 4 °C empfiehlt sie das Auffrischen 7 Tage", "bei 5 °C nach gut 6 Tagen",
                     "Ab 21 Tagen bei 4 °C (bei 5 °C knapp 19 Tagen)", "Bei 14 °C kommt das Auffrischen schon nach gut 2 Tagen",
                     "Ruht:", "Auffrischen empfohlen:", "Vor dem Backen zweimal auffrischen:"] {
            #expect(text.contains(part), "\(part)")
        }
        #expect(StarterFridge.refreshDays == 7 && StarterFridge.refreshTwiceDays == 21)
        #expect(abs(StarterFridge.refreshHours(celsius: 5) / 24 - 6.27) < 0.01)
        #expect(abs(StarterFridge.refreshTwiceHours(celsius: 5) / 24 - 18.8) < 0.05)
        #expect(abs(StarterFridge.refreshHours(celsius: 14) / 24 - 2.33) < 0.01)
    }

    @Test func theStartingFromScratchPageIsLinkedFromTheOtherStarterPages() {
        for id in [TipsTopic.ID.starter, .starterNew, .starterFeed] {
            #expect(links(in: id).contains("starterFromScratch"), "\(id)")
        }
        // The page names the phases with the days of `StarterEstablishing` at 22 °C
        // and the slower start at 12 °C (factor 3: 2 × 3 = 6 days).
        let text = plainText(.starterFromScratch)
        for part in ["Nach etwa 2 Tagen", "Nach etwa 3 Tagen", "Nach etwa 5 Tagen", "zehnten Tag",
                     "zweimal hintereinander", "Bei 12 °C beginnt die Scheinblüte also erst nach etwa 6 Tagen"] {
            #expect(text.contains(part), "\(part)")
        }
        #expect(StarterEstablishing.falseRiseDays == 2 && StarterEstablishing.quietDays == 3
                && StarterEstablishing.stabilizingDays == 5 && StarterEstablishing.usuallyReadyDays == 10)
        // The page for a new starter no longer reads "Angesetzt am" as any earlier date.
        #expect(!plainText(.starterNew).contains("auch ein früherer"))
    }

    @Test func titlesOfTheBakingTopics() {
        #expect(TipsCatalog.topic(.flours).title == "Mehle und ihre Mischung")
        #expect(TipsCatalog.topic(.kneading).title == "Kneten")
        #expect(TipsCatalog.topic(.schedule).title == "So wird der Zeitplan berechnet")
        #expect(TipsCatalog.topic(.temperature).title == "Temperatur und Zeit")
    }

    @Test func theStarterPageHoldsTheStateSectionsAsSiblingsAfterGoodToKnow() {
        let headings = TipsCatalog.topic(.starter).blocks.compactMap { block -> String? in
            if case .heading(let text) = block { text } else { nil }
        }
        #expect(headings == ["Gut zu wissen", "Was in die Rechnung eingeht", "Im Kühlschrank", "Die Zustände",
                             "Die Ansetzphase", "Übernommene Starter", "Das Datum", "Prüf selbst"])
        #expect(!plainText(.starter).contains("Platzhalter"))
        #expect(TipsTopic.ID(rawValue: "starterStates") == nil)
    }

    @Test func theStarterCarePageHasItsFiveSectionsAndIsLinkedFromTheInstructionsAndTheStarterPages() {
        let topic = TipsCatalog.topic(.starterCare)
        #expect(topic.title == "Starter erhalten und pflegen")
        #expect(topic.category == .starters)
        let headings = topic.blocks.compactMap { block -> String? in
            if case .heading(let text) = block { text } else { nil }
        }
        #expect(headings == ["Ein Teelöffel genügt", "Zwei Wege", "Selbes Glas oder frisches Glas",
                             "Woran du merkst, dass etwas nicht stimmt", "Und in der App"])
        #expect(links(in: .starterCare).isSuperset(of: ["starter", "starterFeed"]))
        for id in [TipsTopic.ID.starter, .starterFeed, .run] {
            #expect(links(in: id).contains("starterCare"), "\(id)")
        }
        for step in ["mixSourdough", "kneadFold", "kneadRye", "checkStarter", "waitStarter"] {
            let url = Bundle.module.url(forResource: step, withExtension: "md", subdirectory: "Steps")!
            let text = String(decoding: try! Data(contentsOf: url), as: UTF8.self)
            #expect(text.contains("(tip:starterCare)"), "\(step)")
        }
    }

    @Test func theTemperaturePageLinksTheScheduleAndProofingAndIsLinkedFromTheSchedule() {
        #expect(links(in: .temperature).isSuperset(of: ["schedule", "proofing"]))
        #expect(links(in: .schedule).contains("temperature"))
        #expect(TipsCatalog.topic(.temperature).category == .baking)
    }

    /// 8 h at 22 °C, three times as long for every 10 °C colder, worked out by
    /// hand: 27 °C is 5 K warmer, 8 / 3^0.5 = 8 / 1.7321 = 4.619; 16 °C is 6 K
    /// colder, 8 · 3^0.6 = 8 · 1.9332 = 15.47; 5 °C is 17 K colder,
    /// 8 · 3^1.7 = 8 · 6.473 = 51.78. The page quotes these rounded.
    @Test func theTemperaturePageQuotesTheHoursOfTheRule() {
        let text = plainText(.temperature)
        for (celsius, hours, quoted) in [(27.0, 4.619, "etwa 4,6 Stunden"), (22.0, 8.0, "8 Stunden"),
                                          (16.0, 15.47, "etwa 15,5 Stunden"), (5.0, 51.78, "etwa 52 Stunden")] {
            let rule = ScheduleRules.hours(.sourdough, ryeShare: 0, celsius: celsius)
            #expect(abs(rule - hours) < 0.01, "\(celsius) °C")
            #expect(text.contains(quoted), "\(quoted)")
        }
    }

    @Test func theTemperaturePageNamesTheRangesOfTheRule() {
        let text = plainText(.temperature)
        // Factors 0.85 to 1.2, sourdough 0.8 to 1.25, fridge 0.7 to 1.5.
        #expect(RestKind.proof.factorRange(at: .room) == 0.85...1.2)
        #expect(RestKind.sourdough.factorRange(at: .room) == 0.8...1.25)
        #expect(RestKind.bulk.factorRange(at: .fridge) == 0.7...1.5)
        for quoted in ["0,85- bis 1,2-Fache", "0,8- bis 1,25-Fache", "0,7- bis 1,5-Fache", "16 °C", "8 bis 18 °C"] {
            #expect(text.contains(quoted), "\(quoted)")
        }
    }

    private func plainText(_ id: TipsTopic.ID) -> String {
        TipsCatalog.topic(id).blocks.flatMap { block -> [String] in
            switch block {
            case .paragraph(let text): [text]
            case .bullets(let items): items
            default: []
            }
        }.joined(separator: "\n")
    }

    private func links(in id: TipsTopic.ID) -> Set<String> {
        Set(plainText(id).components(separatedBy: "(tip:").dropFirst().map { String($0.prefix { $0 != ")" }) })
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

    @Test func theMachinePageNamesTheKneadingTimesAndTheBowlRuleOfTheApp() {
        // The page states the rules of `Kneading` and `KneaderCapacity` in
        // words; they must not drift apart.
        let text = plainText(.kneader)
        func span(_ way: Kneading.Way, _ gluten: Kneading.Gluten) -> String {
            let range = Kneading.minutes(way, gluten)
            return "\(Int(range.lowerBound)) bis \(Int(range.upperBound)) Minuten"
        }
        for (way, gluten) in [(Kneading.Way.hook, Kneading.Gluten.wheat), (.blade, .wheat), (.hook, .spelt), (.blade, .spelt)] {
            #expect(text.contains(span(way, gluten)), "\(way) \(gluten) fehlt auf der Seite.")
        }
        // 400 g per litre, written as 0,4 kg; 4.8 l × 0.4 = 1.92 ≈ 1,9 kg.
        #expect(KneaderCapacity.gramsPerBowlLiter == 400)
        #expect(text.contains("0,4 kg Teig je Liter") && text.contains("4,8-l-Schüssel nimmt also etwa 1,9 kg"))
        #expect(!text.contains("Platzhalter"))
        #expect(links(in: .kneading).contains("kneader"))
    }

    @Test func theKneadingPageNamesTheRuleOfTheRounds() {
        // The page states the rule of `Folding` in words; the numbers must match.
        let text = plainText(.kneading)
        #expect(Folding.firmBelow == 65 && Folding.softAbove == 75)
        #expect(text.contains("unter 65 % zwei Runden im Abstand von 45 Minuten, bis 75 % drei, darüber vier Runden"))
        #expect(Folding.speltMax == 3 && text.contains("höchstens drei Runden"))
        #expect(Folding.fewerFromRye == 20 && text.contains("Ab 20 % Roggen"))
        #expect(BakeRules.freeStandingRyeMax == 50 && text.contains("Ab 50 % Roggen faltet die App nicht"))
        #expect(Folding.freeHoursAtEnd == 1 && text.contains("Die letzte Stunde der Stockgare bleibt frei"))
        #expect(links(in: .schedule).contains("kneading"))
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
