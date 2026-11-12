import Testing
@testable import Sourdough

struct AppInfoTests {
    @Test func theVersionLineNamesVersionAndBuild() {
        #expect(AppInfo.versionLine(info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "3"])
                == "Version 1.0 (3)")
    }

    @Test func aMissingBuildOrVersionIsLeftOut() {
        #expect(AppInfo.versionLine(info: ["CFBundleShortVersionString": "2.1"]) == "Version 2.1")
        #expect(AppInfo.versionLine(info: ["CFBundleVersion": "7"]) == "Version unbekannt (7)")
        #expect(AppInfo.versionLine(info: [:]) == "Version unbekannt")
        #expect(AppInfo.versionLine(info: nil) == "Version unbekannt")
    }

    @Test func valuesOfTheWrongTypeCountAsMissing() {
        #expect(AppInfo.versionLine(info: ["CFBundleShortVersionString": 1, "CFBundleVersion": 3])
                == "Version unbekannt")
    }

    @Test func theRealBundleHasAVersionAndABuild() {
        // The app is built with a version and a build number (project settings);
        // the line must not fall back to "unbekannt".
        let line = AppInfo.versionLine()
        #expect(line.hasPrefix("Version "))
        #expect(!line.contains("unbekannt"))
    }

    @Test func theFontCreditNamesFontAuthorsAndLicence() {
        #expect(AppInfo.fontCredit == "Schrift: Caveat, The Caveat Project Authors, SIL OFL 1.1")
    }
}
