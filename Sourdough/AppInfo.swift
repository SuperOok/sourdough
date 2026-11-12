import Foundation

/// What the app says about itself on its welcome page: the version and the
/// credit the font's licence asks for.
enum AppInfo {
    static let fontCredit = "Schrift: Caveat, The Caveat Project Authors, SIL OFL 1.1"

    /// "Version 1.0 (3)" from `CFBundleShortVersionString` and `CFBundleVersion`.
    /// `info` is a parameter so that tests do not depend on the bundle they run
    /// in; a missing value is left out ("Version 1.0") or, without any, "Version unbekannt".
    static func versionLine(info: [String: Any]? = Bundle.main.infoDictionary) -> String {
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (version?, build?): return "Version \(version) (\(build))"
        case let (version?, nil): return "Version \(version)"
        case let (nil, build?): return "Version unbekannt (\(build))"
        case (nil, nil): return "Version unbekannt"
        }
    }
}
