import Testing
import SourdoughKit
@testable import Sourdough

struct EquipmentTextTests {
    @Test func kindNamesAreGerman() {
        #expect(EquipmentKind.allCases.map(\.germanName) ==
                ["Küchenmaschine", "Bräter/Römertopf", "Kastenform", "Gärkörbchen"])
    }

    @Test func materialAndShapeNames() {
        #expect(EquipmentItem.Material.sheetMetal.germanName == "Blech")
        #expect(EquipmentItem.Material.castIron.germanName == "Gusseisen")
        #expect(Dimensions.Shape.allCases.map(\.germanName) == ["Rechteckig", "Rund", "Oval"])
    }

    @Test func dimensionsAreWrittenPerShape() {
        #expect(Dimensions(shape: .rectangular, lengthCm: 30, widthCm: 10, heightCm: 8).germanText
                == "30 × 10 × 8 cm")
        #expect(Dimensions(shape: .oval, lengthCm: 30, widthCm: 20, heightCm: 12).germanText
                == "oval 30 × 20 × 12 cm")
        #expect(Dimensions(shape: .round, lengthCm: 24, heightCm: 10).germanText
                == "rund Ø 24 × 10 cm")
    }

    @Test func decimalsUseACommaInDimensions() {
        #expect(Dimensions(shape: .rectangular, lengthCm: 12.5, widthCm: 10, heightCm: 8).germanText
                == "12,5 × 10 × 8 cm")
    }

    @Test func volumeIsRoundedToATenthOfALitre() {
        // 2400 ml = 2,4 l; 4523,9 ml = 4,5 l; 5654,9 ml = 5,7 l; 5000 ml = 5 l
        #expect(Dimensions(shape: .rectangular, lengthCm: 30, widthCm: 10, heightCm: 8).volumeText == "2,4 l")
        #expect(Dimensions(shape: .round, lengthCm: 24, heightCm: 10).volumeText == "4,5 l")
        #expect(Dimensions(shape: .oval, lengthCm: 30, widthCm: 20, heightCm: 12).volumeText == "5,7 l")
        #expect(Dimensions(shape: .rectangular, lengthCm: 25, widthCm: 20, heightCm: 10).volumeText == "5 l")
    }

    @Test func kneadingMachineAndBasketHaveFixedDescriptions() {
        #expect(EquipmentItem(kind: .kneader, name: "x").detailText == "Küchenmaschine mit Knetfunktion")
        #expect(EquipmentItem(kind: .basket, name: "x").detailText == "Gärkörbchen, rund")
        #expect(EquipmentItem(kind: .basket, name: "x", shape: .oval).detailText == "Gärkörbchen, oval")
        #expect(EquipmentItem(kind: .basket, name: "x", shape: .rectangular).detailText
                == "Gärkörbchen, rechteckig")
    }

    @Test func potWithAndWithoutLidAndLiner() {
        #expect(EquipmentItem(kind: .pot, name: "x", hasLid: true, hasSiliconeLiner: true).detailText ==
                "Bräter/Römertopf, mit Deckel, mit Silikoneinlage")
        #expect(EquipmentItem(kind: .pot, name: "x").detailText ==
                "Bräter/Römertopf, ohne Deckel, ohne Silikoneinlage")
    }

    @Test func loafPanDescribesMaterialLidAndLiner() {
        let sheet = EquipmentItem(kind: .pan, name: "x", hasSiliconeLiner: true)
        #expect(sheet.detailText == "Kastenform aus Blech, ohne Deckel, mit Silikoneinlage")
        let iron = EquipmentItem(kind: .pan, name: "x", material: .castIron, hasLid: true)
        #expect(iron.detailText == "Kastenform aus Gusseisen, mit Deckel, ohne Silikoneinlage")
    }

    @Test func aGivenSizeAndItsVolumeFollowTheDescription() {
        let pot = EquipmentItem(
            kind: .pot, name: "x", hasLid: true, hasSiliconeLiner: true,
            dimensions: Dimensions(shape: .oval, lengthCm: 30, widthCm: 20, heightCm: 12))
        #expect(pot.detailText
                == "Bräter/Römertopf, mit Deckel, mit Silikoneinlage · oval 30 × 20 × 12 cm · 5,7 l")
        let pan = EquipmentItem(
            kind: .pan, name: "x", material: .castIron, hasLid: true, hasSiliconeLiner: true,
            dimensions: Dimensions(shape: .rectangular, lengthCm: 30, widthCm: 10, heightCm: 8))
        #expect(pan.detailText ==
                "Kastenform aus Gusseisen, mit Deckel, mit Silikoneinlage · 30 × 10 × 8 cm · 2,4 l")
    }
}

struct EquipmentDemoTests {
    @Test func demoHasFivePiecesWithTwoPans() {
        let items = EquipmentDemo.items()
        #expect(items.map(\.name) == ["Thermomix", "Römertopf", "Gusseisenform", "Kastenform", "Gärkörbchen"])
        #expect(items.map(\.kind) == [.kneader, .pot, .pan, .pan, .basket])
    }

    @Test func demoSizesGiveTheVolumesTheUITestsExpect() {
        let items = EquipmentDemo.items()
        #expect(items[1].dimensions?.volumeText == "5,7 l")
        #expect(items[2].dimensions?.volumeText == "2,4 l")
        #expect(items[3].dimensions == nil)
    }

    @Test func demoHasOneOfEveryKindSoNothingIsMissing() {
        #expect(EquipmentDemo.items().missingKinds.isEmpty)
    }
}
