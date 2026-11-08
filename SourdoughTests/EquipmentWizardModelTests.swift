import Testing
import SourdoughKit
@testable import Sourdough

struct EquipmentWizardModelTests {
    @Test func startsAtTheFirstStepWithTheGivenDraft() {
        let start = Equipment(hasProvingBasket: true)
        let model = EquipmentWizardModel(starting: start)
        #expect(model.draft == start)
        #expect(model.step == .kneader)
        #expect(model.isFirstStep)
        #expect(!model.isLastStep)
        #expect(model.progressText == "Schritt 1 von 4")
    }

    @Test func walksForwardAndBackAndStopsAtTheEnds() {
        let model = EquipmentWizardModel(starting: Equipment())
        model.back()
        #expect(model.step == .kneader)
        model.next(); #expect(model.step == .pot)
        model.next(); #expect(model.step == .loafPan)
        model.next(); #expect(model.step == .basket)
        #expect(model.isLastStep)
        #expect(model.progressText == "Schritt 4 von 4")
        model.next()
        #expect(model.step == .basket)
        model.back(); #expect(model.step == .loafPan)
    }

    @Test func everyStepHasItsTitle() {
        #expect(EquipmentWizardModel.Step.allCases.map(\.title) ==
                ["Küchenmaschine", "Bräter oder Römertopf", "Kastenform", "Gärkörbchen"])
    }

    @Test func potSwitchCreatesAndForgetsDetails() {
        let model = EquipmentWizardModel(starting: Equipment())
        #expect(!model.hasPot)
        #expect(!model.potHasLiner)
        model.potHasLiner = true            // no pot yet: nothing happens
        #expect(model.draft.pot == nil)
        model.hasPot = true
        model.potHasLiner = true
        #expect(model.draft.pot == Equipment.Pot(hasSiliconeLiner: true))
        model.hasPot = true                 // switching on again keeps the details
        #expect(model.potHasLiner)
        model.hasPot = false
        #expect(model.draft.pot == nil)
        model.hasPot = true                 // starts plain again
        #expect(!model.potHasLiner)
    }

    @Test func loafPanSwitchCreatesAndForgetsDetails() {
        let model = EquipmentWizardModel(starting: Equipment())
        #expect(!model.hasLoafPan)
        #expect(model.panMaterial == .sheetMetal)
        #expect(!model.panHasLid)
        #expect(!model.panHasLiner)
        model.panMaterial = .castIron       // no pan yet: nothing happens
        model.panHasLid = true
        model.panHasLiner = true
        #expect(model.draft.loafPan == nil)
        model.hasLoafPan = true
        model.panMaterial = .castIron
        model.panHasLid = true
        model.panHasLiner = true
        #expect(model.draft.loafPan ==
                Equipment.LoafPan(material: .castIron, hasLid: true, hasSiliconeLiner: true))
        model.hasLoafPan = true
        #expect(model.panMaterial == .castIron)
        model.hasLoafPan = false
        #expect(model.draft.loafPan == nil)
        model.hasLoafPan = true
        #expect(model.draft.loafPan == Equipment.LoafPan())
    }
}
