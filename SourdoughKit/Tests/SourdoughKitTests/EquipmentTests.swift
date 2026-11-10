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
        #expect(EquipmentKind.allCases.filter(\.hasMaterial) == [.pan])
        #expect(EquipmentKind.allCases.filter(\.hasLid) == [.pot, .pan])
        #expect(EquipmentKind.allCases.filter(\.hasShape) == [.basket])
    }

    @Test func aBannetonIsRoundOrLong() {
        #expect(!EquipmentItem(kind: .basket, name: "R").isLong)
        #expect(EquipmentItem(kind: .basket, name: "O", shape: .oval).isLong)
        #expect(EquipmentItem(kind: .basket, name: "L", shape: .rectangular).isLong)
    }

    @Test func piecesSavedWithoutAShapeAreRound() throws {
        let json = #"[{"id":"5D4E1C36-0F7E-4C1B-8D2A-0E8A3B6C9F11","kind":"basket","name":"Alt","#
            + #""material":"sheetMetal","hasLid":false,"hasSiliconeLiner":false}]"#
        let items = try JSONDecoder().decode([EquipmentItem].self, from: Data(json.utf8))
        #expect(items.first?.shape == .round)
        #expect(items.first?.dimensions == nil)
        #expect(items.first?.name == "Alt")
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
        #expect(item.shape == .round)
    }

    @Test func eachItemGetsItsOwnId() {
        #expect(EquipmentItem(kind: .basket, name: "A").id != EquipmentItem(kind: .basket, name: "A").id)
    }

    @Test func potsSavedBeforeTheLidSettingHaveALid() throws {
        // Every pot was stored with `hasLid` false then, as the field did not apply to it.
        let json = #"[{"id":"5D4E1C36-0F7E-4C1B-8D2A-0E8A3B6C9F11","kind":"pot","name":"Alt","#
            + #""material":"sheetMetal","hasLid":false,"hasSiliconeLiner":false}]"#
        let items = try JSONDecoder().decode([EquipmentItem].self, from: Data(json.utf8))
        #expect(items.first?.hasLid == true)
    }

    @Test func thePotLidSurvivesAJSONRoundTripInEitherState() throws {
        let withLid = EquipmentItem(kind: .pot, name: "Mit", hasLid: true)
        let without = EquipmentItem(kind: .pot, name: "Ohne", hasLid: false)
        let data = try JSONEncoder().encode([withLid, without])
        #expect(try JSONDecoder().decode([EquipmentItem].self, from: data) == [withLid, without])
        // The pot's own key carries the setting; the old key stays for older readers.
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"potLid\":false") && text.contains("\"potLid\":true"))
    }

    @Test func aPanKeepsItsLidUnderTheOldKey() throws {
        let pan = EquipmentItem(kind: .pan, name: "Pan", hasLid: true)
        let text = String(decoding: try JSONEncoder().encode(pan), as: UTF8.self)
        #expect(text.contains("\"hasLid\":true") && !text.contains("potLid"))
    }

    @Test func survivesAJSONRoundTrip() throws {
        let item = EquipmentItem(
            kind: .pan, name: "Gusseisen", material: .castIron, hasLid: true,
            hasSiliconeLiner: true,
            dimensions: Dimensions(shape: .rectangular, lengthCm: 30, widthCm: 10, heightCm: 8))
        let basket = EquipmentItem(kind: .basket, name: "Lang", shape: .rectangular)
        let data = try JSONEncoder().encode([item, basket])
        #expect(try JSONDecoder().decode([EquipmentItem].self, from: data) == [item, basket])
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
