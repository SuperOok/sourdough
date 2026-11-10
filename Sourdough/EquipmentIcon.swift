import SourdoughKit

/// Which own icon (see `CustomIcon`) stands for a piece or a kind of
/// equipment. A pot and a loaf pan show whether they have a lid, a banneton
/// whether it is round or long.
enum EquipmentIcon {
    static func name(_ item: EquipmentItem) -> String {
        switch item.kind {
        case .kneader: "KneaderIcon"
        case .pot: item.hasLid ? "PotIcon" : "PotOpenIcon"
        case .pan: item.hasLid ? "PanLidIcon" : "PanOpenIcon"
        case .basket: item.isLong ? "BasketLongIcon" : "BasketRoundIcon"
        }
    }

    /// The icon of a kind not owned yet: as a new piece of it would be, so a
    /// pot with a lid, a pan without, a round banneton.
    static func name(for kind: EquipmentKind) -> String {
        name(EquipmentItem(kind: kind, name: "", hasLid: kind == .pot))
    }
}
