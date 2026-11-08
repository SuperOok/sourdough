import Foundation
import Testing
@testable import SourdoughKit

struct EquipmentTests {
    @Test func defaultsOwnNothing() {
        let equipment = Equipment()
        #expect(!equipment.hasKneadingMachine)
        #expect(equipment.pot == nil)
        #expect(equipment.loafPan == nil)
        #expect(!equipment.hasProvingBasket)
        #expect(equipment.isEmpty)
    }

    @Test func anythingOwnedIsNotEmpty() {
        #expect(!Equipment(hasKneadingMachine: true).isEmpty)
        #expect(!Equipment(pot: .init()).isEmpty)
        #expect(!Equipment(loafPan: .init()).isEmpty)
        #expect(!Equipment(hasProvingBasket: true).isEmpty)
    }

    @Test func partsDefaultToPlainVariants() {
        #expect(Equipment.Pot().hasSiliconeLiner == false)
        let pan = Equipment.LoafPan()
        #expect(pan.material == .sheetMetal)
        #expect(!pan.hasLid)
        #expect(!pan.hasSiliconeLiner)
    }

    @Test func survivesAJSONRoundTrip() throws {
        let equipment = Equipment(
            hasKneadingMachine: true,
            pot: .init(hasSiliconeLiner: true),
            loafPan: .init(material: .castIron, hasLid: true, hasSiliconeLiner: false),
            hasProvingBasket: true)
        let data = try JSONEncoder().encode(equipment)
        #expect(try JSONDecoder().decode(Equipment.self, from: data) == equipment)
    }

    @Test func allMaterialsAreListed() {
        #expect(Equipment.LoafPan.Material.allCases == [.sheetMetal, .castIron])
    }
}
