import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

struct EquipmentFormTests {
    private func pan(length: String = "", width: String = "", height: String = "") -> EquipmentFormModel {
        let model = EquipmentFormModel(kind: .pan)
        model.lengthText = length
        model.widthText = width
        model.heightText = height
        return model
    }

    @Test func aNewPotStartsRoundAndOtherKindsRectangular() {
        #expect(EquipmentFormModel(kind: .pot).shape == .round)
        #expect(EquipmentFormModel(kind: .pan).shape == .rectangular)
        #expect(EquipmentFormModel(kind: .kneader).shape == .rectangular)
    }

    @Test func aNewFormIsPlainAndValid() {
        let model = EquipmentFormModel(kind: .pan)
        #expect(model.name == "")
        #expect(model.material == .sheetMetal)
        #expect(!model.hasLid)
        #expect(!model.hasLiner)
        #expect(model.size == .none)
        #expect(model.isValid)
        #expect(model.errorText == nil)
        #expect(model.volumeText == nil)
    }

    @Test func withoutATypedNameThePieceGetsTheNameOfItsKind() {
        #expect(EquipmentFormModel(kind: .kneader).resolvedName == "Küchenmaschine")
        let blank = EquipmentFormModel(kind: .pot)
        blank.name = "   "
        #expect(blank.resolvedName == "Bräter/Römertopf")
        blank.name = "  Römertopf groß "
        #expect(blank.resolvedName == "Römertopf groß")
    }

    @Test func aCompleteRectangleGivesDimensionsAndVolume() {
        // 30 × 10 × 8 = 2400 ml
        let model = pan(length: "30", width: "10", height: "8")
        #expect(model.size == .given(Dimensions(shape: .rectangular, lengthCm: 30, widthCm: 10, heightCm: 8)))
        #expect(model.volumeText == "2,4 l")
        #expect(model.isValid)
    }

    @Test func aCommaIsAllowedAsDecimalSeparator() {
        // 12,5 × 10 × 8 = 1000 ml
        let model = pan(length: "12,5", width: "10", height: "8")
        #expect(model.volumeText == "1 l")
    }

    @Test func aRoundShapeNeedsNoWidthAndIgnoresWhatIsTypedThere() {
        // π/4 × 24² × 10 ≈ 4523,9 ml
        let model = pan(length: "24", width: "abc", height: "10")
        model.shape = .round
        #expect(model.size == .given(Dimensions(shape: .round, lengthCm: 24, widthCm: 0, heightCm: 10)))
        #expect(model.volumeText == "4,5 l")
    }

    @Test func anOvalNeedsAllThreeMeasures() {
        let model = pan(length: "30", width: "20", height: "12")
        model.shape = .oval
        #expect(model.volumeText == "5,7 l")
        model.widthText = ""
        #expect(model.size == .incomplete(missing: ["Breite"]))
        #expect(model.hintText == "Noch fehlt: Breite. Gib alle Maße an oder keines.")
    }

    @Test func aRoundShapeMissesItsDiameter() {
        let model = EquipmentFormModel(kind: .pot)
        model.heightText = "10"
        #expect(model.hintText == "Noch fehlt: Durchmesser. Gib alle Maße an oder keines.")
    }

    @Test func partialSizesAreRejected() {
        // Missing measures are a hint while typing, not an error.
        #expect(pan(length: "30").errorText == nil)
        #expect(pan(length: "30").hintText == "Noch fehlen: Breite und Höhe. Gib alle Maße an oder keines.")
        #expect(pan(length: "30", width: "0", height: "8").hintText
                == "Noch fehlt: Breite. Gib alle Maße an oder keines.")
        #expect(pan(length: "30", width: "10", height: "8").hintText == nil)
        #expect(!pan(length: "30").isValid)
        #expect(pan(length: "30").makeItem() == nil)
        #expect(pan(length: "30").volumeText == nil)
    }

    @Test func allZeroOrEmptyMeansNoSize() {
        #expect(pan(length: "0", width: "0", height: "0").size == .none)
        #expect(pan().size == .none)
    }

    @Test func textInsteadOfNumbersIsRejected() {
        #expect(pan(length: "abc", width: "10", height: "8").errorText == StarterFormModel.numbersOnly)
        #expect(pan(length: "30", width: "-1", height: "8").errorText == StarterFormModel.numbersOnly)
        #expect(pan(length: "30", width: "10", height: "x").errorText == StarterFormModel.numbersOnly)
    }

    @Test func kindsWithoutASizeIgnoreTheSizeFields() {
        let basket = EquipmentFormModel(kind: .basket)
        basket.lengthText = "abc"
        #expect(basket.size == .none)
        #expect(basket.isValid)
        let kneader = EquipmentFormModel(kind: .kneader)
        kneader.lengthText = "30"
        #expect(kneader.makeItem()?.dimensions == nil)
    }

    @Test func makeItemBuildsTheLoafPan() {
        let id = UUID()
        let model = EquipmentFormModel(kind: .pan, id: id)
        model.name = "Gusseisenform"
        model.material = .castIron
        model.hasLid = true
        model.hasLiner = true
        model.lengthText = "30"
        model.widthText = "10"
        model.heightText = "8"
        #expect(model.makeItem() == EquipmentItem(
            id: id, kind: .pan, name: "Gusseisenform", material: .castIron, hasLid: true,
            hasSiliconeLiner: true,
            dimensions: Dimensions(shape: .rectangular, lengthCm: 30, widthCm: 10, heightCm: 8)))
    }

    @Test func detailsThatDoNotBelongToTheKindAreDropped() {
        let pot = EquipmentFormModel(kind: .pot)
        pot.material = .castIron
        pot.hasLid = true
        pot.hasLiner = true
        let potItem = pot.makeItem()
        #expect(potItem?.material == .sheetMetal)
        #expect(potItem?.hasLid == true)
        #expect(potItem?.hasSiliconeLiner == true)

        let kneader = EquipmentFormModel(kind: .kneader)
        kneader.material = .castIron
        kneader.hasLid = true
        kneader.hasLiner = true
        #expect(kneader.makeItem() == EquipmentItem(id: kneader.id, kind: .kneader, name: "Küchenmaschine"))

        // Tool, bowl and limit belong to a kneader only.
        let pan = EquipmentFormModel(kind: .pan)
        pan.kneadingTool = .blade
        pan.bowlText = "4,8"
        pan.maxDoughText = "2000"
        #expect(pan.makeItem() == EquipmentItem(id: pan.id, kind: .pan, name: "Kastenform"))
        #expect(pan.numberFields == pan.sizeFields)
        #expect(pan.doughLimitText == nil)
    }

    @Test func aNewKneaderKneadsWithAHookAndHasNoBowl() {
        let kneader = EquipmentFormModel(kind: .kneader)
        #expect(kneader.kneadingTool == .hook)
        #expect(kneader.bowlText == "" && kneader.maxDoughText == "")
        #expect(kneader.numberFields == ["item-bowl", "item-max-dough"])
        #expect(kneader.doughLimitText == nil)
        #expect(kneader.makeItem()?.bowlLiters == nil)
    }

    @Test func aKneaderKeepsItsToolBowlAndLimit() {
        let kneader = EquipmentFormModel(kind: .kneader)
        kneader.name = "Thermomix"
        kneader.kneadingTool = .blade
        kneader.bowlText = "2,2"
        #expect(kneader.makeItem() == EquipmentItem(id: kneader.id, kind: .kneader, name: "Thermomix",
                                                    kneadingTool: .blade, bowlLiters: 2.2))
        // 2.2 l × 0.4 kg/l = 0.88 kg, shown as 0,9 kg.
        #expect(kneader.doughLimitText == "0,9 kg")
        // The maker's 1350 g wins: 1,35 kg is shown as 1,4 kg.
        kneader.maxDoughText = "1350"
        #expect(kneader.makeItem()?.maxDoughGrams == 1350)
        #expect(kneader.doughLimitText == "1,4 kg")
        // 0 is not given, like an empty field.
        kneader.bowlText = "0"
        kneader.maxDoughText = ""
        #expect(kneader.makeItem()?.bowlLiters == nil && kneader.makeItem()?.maxDoughGrams == nil)
    }

    @Test func aBowlThatIsNotANumberIsRejected() {
        let kneader = EquipmentFormModel(kind: .kneader)
        kneader.bowlText = "groß"
        #expect(kneader.errorText == StarterFormModel.numbersOnly)
        #expect(!kneader.isValid)
        #expect(kneader.makeItem() == nil)
        #expect(kneader.doughLimitText == nil)
        kneader.bowlText = "4,8"
        kneader.maxDoughText = "-1"
        #expect(kneader.errorText == StarterFormModel.numbersOnly)
    }

    @Test func editingAKneaderStartsWithItsValues() {
        let item = EquipmentItem(kind: .kneader, name: "kMix", kneadingTool: .blade, bowlLiters: 4.8,
                                 maxDoughGrams: 1350)
        let model = EquipmentFormModel(editing: item)
        #expect(model.kneadingTool == .blade)
        #expect(model.bowlText == "4,8")
        #expect(model.maxDoughText == "1350")
        #expect(model.makeItem() == item)
        let plain = EquipmentFormModel(editing: EquipmentItem(kind: .kneader, name: "Bosch"))
        #expect(plain.bowlText == "" && plain.maxDoughText == "")
    }

    @Test func aNewPotHasALidAndCanLoseIt() {
        let pot = EquipmentFormModel(kind: .pot)
        #expect(pot.hasLid && pot.makeItem()?.hasLid == true)
        pot.hasLid = false
        #expect(pot.makeItem()?.hasLid == false)
        #expect(!EquipmentFormModel(kind: .pan).hasLid)
    }

    @Test func theIconFollowsTheLidAndTheShape() {
        let pot = EquipmentFormModel(kind: .pot)
        #expect(pot.iconName == "PotIcon")
        pot.hasLid = false
        #expect(pot.iconName == "PotOpenIcon")
        let pan = EquipmentFormModel(kind: .pan)
        #expect(pan.iconName == "PanOpenIcon")
        pan.hasLid = true
        #expect(pan.iconName == "PanLidIcon")
        let basket = EquipmentFormModel(kind: .basket)
        #expect(basket.iconName == "BasketRoundIcon")
        basket.basketShape = .rectangular
        #expect(basket.iconName == "BasketLongIcon")
        // A lid on a kneader means nothing.
        let kneader = EquipmentFormModel(kind: .kneader)
        kneader.hasLid = true
        #expect(kneader.iconName == "KneaderIcon")
    }

    @Test func aBannetonKeepsItsShapeOthersStayRound() {
        let basket = EquipmentFormModel(kind: .basket)
        #expect(basket.basketShape == .round)
        basket.basketShape = .rectangular
        #expect(basket.makeItem()?.shape == .rectangular)
        #expect(EquipmentFormModel(editing: EquipmentItem(kind: .basket, name: "O", shape: .oval)).basketShape
                == .oval)
        let pan = EquipmentFormModel(kind: .pan)
        pan.basketShape = .oval
        #expect(pan.makeItem()?.shape == .round)
    }

    @Test func makeItemRefusesAnInvalidForm() {
        #expect(pan(length: "30").makeItem() == nil)
    }

    @Test func editingStartsWithTheValuesOfThePiece() {
        let item = EquipmentItem(
            kind: .pan, name: "A", material: .castIron, hasLid: true, hasSiliconeLiner: true,
            dimensions: Dimensions(shape: .rectangular, lengthCm: 12.5, widthCm: 10, heightCm: 8))
        let model = EquipmentFormModel(editing: item)
        #expect(model.id == item.id)
        #expect(model.kind == .pan)
        #expect(model.name == "A")
        #expect(model.material == .castIron)
        #expect(model.hasLid)
        #expect(model.hasLiner)
        #expect(model.shape == .rectangular)
        #expect(model.lengthText == "12,5")
        #expect(model.widthText == "10")
        #expect(model.heightText == "8")
        #expect(model.makeItem() == item)
    }

    @Test func editingARoundPotLeavesTheWidthEmpty() {
        let item = EquipmentItem(
            kind: .pot, name: "T", dimensions: Dimensions(shape: .round, lengthCm: 24, heightCm: 10))
        let model = EquipmentFormModel(editing: item)
        #expect(model.shape == .round)
        #expect(model.widthText == "")
        #expect(model.makeItem() == item)
    }

    @Test func editingAPieceWithoutASizeLeavesTheFieldsEmpty() {
        let pot = EquipmentFormModel(editing: EquipmentItem(kind: .pot, name: "T"))
        #expect(pot.shape == .round)
        #expect(pot.lengthText == "")
        #expect(pot.heightText == "")
        let pan = EquipmentFormModel(editing: EquipmentItem(kind: .pan, name: "P"))
        #expect(pan.shape == .rectangular)
        #expect(pan.makeItem()?.dimensions == nil)
    }

    @Test func editingKeepsTheTypedNameOnlyIfItIsNotBlank() {
        let model = EquipmentFormModel(editing: EquipmentItem(kind: .basket, name: "Oval"))
        model.name = ""
        #expect(model.makeItem()?.name == "Gärkörbchen")
    }
}
