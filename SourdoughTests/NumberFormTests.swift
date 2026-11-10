import Testing
import SwiftUI
@testable import Sourdough

struct NumberFormTests {
    @Test func weiterGoesToTheNextFieldUntilTheLast() {
        let fields = ["a", "b", "c"]
        #expect(NumberForm<EmptyView>.field(after: "a", in: fields) == "b")
        #expect(NumberForm<EmptyView>.field(after: "b", in: fields) == "c")
        #expect(NumberForm<EmptyView>.field(after: "c", in: fields) == nil)
        // No focus, or a field that is not a number field (the name).
        #expect(NumberForm<EmptyView>.field(after: nil, in: fields) == nil)
        #expect(NumberForm<EmptyView>.field(after: "item-name", in: fields) == nil)
    }

    @Test func theSizeFieldsFollowTheShape() {
        #expect(EquipmentFormModel(kind: .pan).sizeFields == ["item-length", "item-width", "item-height"])
        #expect(EquipmentFormModel(kind: .pot).sizeFields == ["item-length", "item-height"])
        #expect(EquipmentFormModel(kind: .basket).sizeFields == [])
    }
}
