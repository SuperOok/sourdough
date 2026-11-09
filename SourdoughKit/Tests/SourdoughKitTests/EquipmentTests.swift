import Foundation
import Testing
@testable import SourdoughKit

struct DimensionsTests {
    @Test func rectangleVolumeIsLengthTimesWidthTimesHeight() {
        // 30 × 10 × 8 = 2400 cm³ = 2400 ml = 2,4 l
        let pan = Dimensions(shape: .rectangular, lengthCm: 30, widthCm: 10, heightCm: 8)
        #expect(pan.volumeMilliliters == 2400)
        #expect(pan.volumeLiters == 2.4)
    }

    @Test func roundVolumeIsACylinderAndIgnoresTheWidth() {
        // π/4 × 24² × 10 = π × 144 × 10 = 1440 π ≈ 4523,893 ml
        let pot = Dimensions(shape: .round, lengthCm: 24, widthCm: 99, heightCm: 10)
        #expect(abs(pot.volumeMilliliters - 4523.893) < 0.001)
    }

    @Test func ovalVolumeIsAQuarterPiTimesLengthWidthHeight() {
        // π/4 × 30 × 20 × 12 = π × 1800 ≈ 5654,867 ml
        let oval = Dimensions(shape: .oval, lengthCm: 30, widthCm: 20, heightCm: 12)
        #expect(abs(oval.volumeMilliliters - 5654.867) < 0.001)
        #expect(abs(oval.volumeLiters - 5.654867) < 0.000001)
    }

    @Test func aRoundShapeDefaultsToNoWidth() {
        #expect(Dimensions(shape: .round, lengthCm: 24, heightCm: 10).widthCm == 0)
    }

    @Test func allShapesAreListed() {
        #expect(Dimensions.Shape.allCases == [.rectangular, .round, .oval])
    }
}

struct EquipmentItemTests {
    @Test func kindsListTheirDetails() {
        #expect(EquipmentKind.allCases == [.kneader, .pot, .pan, .basket])
        #expect(EquipmentKind.allCases.filter(\.hasDimensions) == [.pot, .pan])
        #expect(EquipmentKind.allCases.filter(\.hasLiner) == [.pot, .pan])
        #expect(EquipmentKind.allCases.filter(\.hasMaterialAndLid) == [.pan])
    }

    @Test func rawValuesAreTheTipsTopicIds() {
        #expect(EquipmentKind.allCases.map(\.rawValue) == ["kneader", "pot", "pan", "basket"])
    }

    @Test func anItemDefaultsToThePlainVariant() {
        let item = EquipmentItem(kind: .pan, name: "Form")
        #expect(item.material == .sheetMetal)
        #expect(!item.hasLid)
        #expect(!item.hasSiliconeLiner)
        #expect(item.dimensions == nil)
    }

    @Test func eachItemGetsItsOwnId() {
        #expect(EquipmentItem(kind: .basket, name: "A").id != EquipmentItem(kind: .basket, name: "A").id)
    }

    @Test func survivesAJSONRoundTrip() throws {
        let item = EquipmentItem(
            kind: .pan, name: "Gusseisen", material: .castIron, hasLid: true,
            hasSiliconeLiner: true,
            dimensions: Dimensions(shape: .rectangular, lengthCm: 30, widthCm: 10, heightCm: 8))
        let data = try JSONEncoder().encode([item])
        #expect(try JSONDecoder().decode([EquipmentItem].self, from: data) == [item])
    }

    @Test func allMaterialsAreListed() {
        #expect(EquipmentItem.Material.allCases == [.sheetMetal, .castIron])
    }

    @Test func everythingIsMissingWithoutItems() {
        #expect([EquipmentItem]().missingKinds == [.kneader, .pot, .pan, .basket])
    }

    @Test func aKindWithSeveralItemsIsNotMissing() {
        let items = [EquipmentItem(kind: .pan, name: "A"), EquipmentItem(kind: .pan, name: "B"),
                     EquipmentItem(kind: .kneader, name: "C")]
        #expect(items.missingKinds == [.pot, .basket])
    }

    @Test func nothingIsMissingWithOneOfEachKind() {
        let items = EquipmentKind.allCases.map { EquipmentItem(kind: $0, name: $0.rawValue) }
        #expect(items.missingKinds.isEmpty)
    }
}
