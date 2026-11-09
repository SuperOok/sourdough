import Foundation
import SourdoughKit

/// Start parameters that bring the app into a defined state for tests.
///
/// `-skipSplash` goes straight to the start screen, `-resetData` forgets all
/// saved data, `-splashSeconds <n>` stretches the splash so a test can
/// reliably see it, `-seedEquipment all` saves the pieces of `EquipmentDemo`
/// before the start so a test need not add them by hand, `-seedStarters demo`
/// saves two starters in known states, `-now <yyyy-MM-ddTHH:mm>` fixes the
/// time a bake is planned from (local time), `-seedRun active` or
/// `-seedRun finished` saves the demo bake (`BakeRunDemo`). Without parameters the
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
    /// "Now" for planning a bake; `nil` is the real time.
    var now: Date?

    enum SeedRun: String {
        case active, finished
    }

    /// Save the demo bake at launch, after equipment and starters.
    var seedRun: SeedRun?

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
        seedRun = arguments.firstIndex(of: "-seedRun")
            .flatMap { arguments.indices.contains($0 + 1) ? SeedRun(rawValue: arguments[$0 + 1]) : nil }
        now = arguments.firstIndex(of: "-now")
            .flatMap { arguments.indices.contains($0 + 1) ? Self.parseNow(arguments[$0 + 1]) : nil }
    }

    /// "2026-11-13T09:00" in the device's time zone.
    static func parseNow(_ text: String, timeZone: TimeZone = .current) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: text)
    }
}
