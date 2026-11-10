import SourdoughKit
import Testing
import UIKit
@testable import Sourdough

struct EquipmentIconTests {
    @Test func eachPieceShowsItsOwnIcon() {
        #expect(EquipmentIcon.name(EquipmentItem(kind: .kneader, name: "x")) == "KneaderIcon")
        #expect(EquipmentIcon.name(EquipmentItem(kind: .pot, name: "x", hasLid: true)) == "PotIcon")
        #expect(EquipmentIcon.name(EquipmentItem(kind: .pot, name: "x")) == "PotOpenIcon")
        #expect(EquipmentIcon.name(EquipmentItem(kind: .pan, name: "x", hasLid: true)) == "PanLidIcon")
        #expect(EquipmentIcon.name(EquipmentItem(kind: .pan, name: "x")) == "PanOpenIcon")
        #expect(EquipmentIcon.name(EquipmentItem(kind: .basket, name: "x")) == "BasketRoundIcon")
        #expect(EquipmentIcon.name(EquipmentItem(kind: .basket, name: "x", shape: .oval)) == "BasketLongIcon")
        #expect(EquipmentIcon.name(EquipmentItem(kind: .basket, name: "x", shape: .rectangular)) == "BasketLongIcon")
    }

    @Test func aKindNotOwnedShowsItsNewPiece() {
        #expect(EquipmentKind.allCases.map(EquipmentIcon.name(for:))
                == ["KneaderIcon", "PotIcon", "PanOpenIcon", "BasketRoundIcon"])
    }

    @Test func everyIconIsInTheAssetCatalog() {
        let names = ["BreadIcon", "PotIcon", "PotOpenIcon", "PanOpenIcon", "PanLidIcon",
                     "KneaderIcon", "BasketRoundIcon", "BasketLongIcon"] + IngredientIcon.allNames
        for name in names {
            #expect(UIImage(named: name) != nil, "\(name) fehlt im Asset-Katalog.")
        }
    }
}
