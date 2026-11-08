import Testing
import SourdoughKit
@testable import Sourdough

struct EquipmentTextTests {
    @Test func nothingOwnedHasNoLines() {
        #expect(Equipment().lines.isEmpty)
    }

    @Test func kneadingMachine() {
        #expect(Equipment(hasKneadingMachine: true).lines ==
                [EquipmentLine(topic: .kneader, text: "Küchenmaschine mit Knetfunktion")])
    }

    @Test func potWithAndWithoutLiner() {
        #expect(Equipment(pot: .init(hasSiliconeLiner: true)).lines.map(\.text) ==
                ["Bräter/Römertopf mit Silikoneinlage"])
        #expect(Equipment(pot: .init(hasSiliconeLiner: false)).lines.map(\.text) ==
                ["Bräter/Römertopf ohne Silikoneinlage"])
    }

    @Test func loafPanDescribesMaterialLidAndLiner() {
        let sheet = Equipment(loafPan: .init(material: .sheetMetal, hasLid: false, hasSiliconeLiner: true))
        #expect(sheet.lines.map(\.text) == ["Kastenform aus Blech, ohne Deckel, mit Silikoneinlage"])
        let iron = Equipment(loafPan: .init(material: .castIron, hasLid: true, hasSiliconeLiner: false))
        #expect(iron.lines.map(\.text) == ["Kastenform aus Gusseisen, mit Deckel, ohne Silikoneinlage"])
    }

    @Test func provingBasket() {
        #expect(Equipment(hasProvingBasket: true).lines ==
                [EquipmentLine(topic: .basket, text: "Gärkörbchen")])
    }

    @Test func linesFollowTheOrderOfTheWizard() {
        let all = Equipment(hasKneadingMachine: true, pot: .init(), loafPan: .init(),
                            hasProvingBasket: true)
        #expect(all.lines.map(\.id) == ["kneader", "pot", "pan", "basket"])
    }

    @Test func everythingMissingWhenNothingIsOwned() {
        #expect(Equipment().missingLines.map(\.text) ==
                ["Küchenmaschine mit Knetfunktion", "Bräter/Römertopf", "Kastenform", "Gärkörbchen"])
        #expect(Equipment().missingLines.map(\.id) == ["kneader", "pot", "pan", "basket"])
    }

    @Test func nothingMissingWhenEverythingIsOwned() {
        let all = Equipment(hasKneadingMachine: true, pot: .init(), loafPan: .init(),
                            hasProvingBasket: true)
        #expect(all.missingLines.isEmpty)
    }

    @Test func eachItemIsEitherOwnedOrMissing() {
        let some = Equipment(hasKneadingMachine: true, loafPan: .init())
        #expect(some.lines.map(\.id) == ["kneader", "pan"])
        #expect(some.missingLines.map(\.id) == ["pot", "basket"])
        let others = Equipment(pot: .init(), hasProvingBasket: true)
        #expect(others.lines.map(\.id) == ["pot", "basket"])
        #expect(others.missingLines.map(\.id) == ["kneader", "pan"])
    }

    @Test func lineIdsAreTheTipsTopicIds() {
        let all = Equipment(hasKneadingMachine: true, pot: .init(), loafPan: .init(),
                            hasProvingBasket: true)
        #expect(all.lines.map(\.topic) == TipsTopic.ID.allCases)
    }

    @Test func materialNames() {
        #expect(Equipment.LoafPan.Material.sheetMetal.germanName == "Blech")
        #expect(Equipment.LoafPan.Material.castIron.germanName == "Gusseisen")
    }
}
