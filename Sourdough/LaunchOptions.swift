import SourdoughKit

/// Start parameters that bring the app into a defined state for tests.
///
/// `-skipSplash` goes straight to the start screen, `-resetData` forgets all
/// saved data, `-splashSeconds <n>` stretches the splash so a test can
/// reliably see it, `-seedEquipment all` saves the pieces of `EquipmentDemo`
/// before the start so a test need not add them by hand, `-seedStarters demo`
/// saves two starters in known states. Without parameters the
/// app starts as a user would find it.
struct LaunchOptions: Equatable {
    static let defaultSplashSeconds = 1.6

    var skipSplash: Bool
    var resetData: Bool
    var splashDuration: Duration
    /// Save the equipment of `EquipmentDemo` at launch, after `resetData`.
    var seedEquipment: Bool
    /// Save the starters of `StarterDemo` at launch.
    var seedDemoStarters: Bool

    init(arguments: [String]) {
        skipSplash = arguments.contains("-skipSplash")
        resetData = arguments.contains("-resetData")
        let seconds = arguments.firstIndex(of: "-splashSeconds")
            .flatMap { arguments.indices.contains($0 + 1) ? Double(arguments[$0 + 1]) : nil }
        splashDuration = .seconds(seconds ?? Self.defaultSplashSeconds)
        seedDemoStarters = arguments.firstIndex(of: "-seedStarters")
            .flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } == "demo"
        seedEquipment = arguments.firstIndex(of: "-seedEquipment")
            .flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } == "all"
    }
}
