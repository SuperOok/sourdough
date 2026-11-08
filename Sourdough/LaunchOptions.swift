import SourdoughKit

/// Start parameters that bring the app into a defined state for tests.
///
/// `-skipSplash` goes straight to the start screen, `-resetData` forgets all
/// saved data, `-splashSeconds <n>` stretches the splash so a test can
/// reliably see it, `-seedEquipment all|none` saves equipment before the
/// start so a test need not click through the wizard. Without parameters the
/// app starts as a user would find it.
struct LaunchOptions: Equatable {
    static let defaultSplashSeconds = 1.6

    /// Everything owned, in the non-default variants: cast iron pan with lid
    /// and liner, pot with liner.
    static let fullEquipment = Equipment(
        hasKneadingMachine: true,
        pot: .init(hasSiliconeLiner: true),
        loafPan: .init(material: .castIron, hasLid: true, hasSiliconeLiner: true),
        hasProvingBasket: true)

    var skipSplash: Bool
    var resetData: Bool
    var splashDuration: Duration
    /// Equipment to save at launch, after `resetData`; `nil` for none.
    var seedEquipment: Equipment?

    init(arguments: [String]) {
        skipSplash = arguments.contains("-skipSplash")
        resetData = arguments.contains("-resetData")
        let seconds = arguments.firstIndex(of: "-splashSeconds")
            .flatMap { arguments.indices.contains($0 + 1) ? Double(arguments[$0 + 1]) : nil }
        splashDuration = .seconds(seconds ?? Self.defaultSplashSeconds)
        let seed = arguments.firstIndex(of: "-seedEquipment")
            .flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        seedEquipment = switch seed {
        case "all": Self.fullEquipment
        case "none": Equipment()
        default: nil
        }
    }
}
