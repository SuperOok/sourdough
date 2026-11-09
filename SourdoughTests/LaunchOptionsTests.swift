import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

struct LaunchOptionsTests {
    @Test func noArgumentsMeansNormalStart() {
        let options = LaunchOptions(arguments: ["Sourdough"])
        #expect(!options.skipSplash)
        #expect(!options.resetData)
        #expect(options.splashDuration == .seconds(1.6))
    }

    @Test func nowIsTheRealTimeByDefault() {
        #expect(LaunchOptions(arguments: ["Sourdough"]).now == nil)
        #expect(LaunchOptions(arguments: ["-now"]).now == nil)
        #expect(LaunchOptions(arguments: ["-now", "morgen"]).now == nil)
    }

    @Test func nowCanBeFixedInLocalTime() {
        // 2026-11-13 09:00 in Berlin (UTC+1 in November) is 08:00 UTC:
        // 1 763 020 800 s is 2025-11-13 08:00 UTC, plus 365 days of 86 400 s.
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        #expect(LaunchOptions.parseNow("2026-11-13T09:00", timeZone: berlin)
                == Date(timeIntervalSince1970: 1_763_020_800 + 365 * 86_400))
        #expect(LaunchOptions(arguments: ["-now", "2026-11-13T09:00"]).now
                == LaunchOptions.parseNow("2026-11-13T09:00"))
    }

    @Test func seedEquipmentIsOffByDefault() {
        #expect(!LaunchOptions(arguments: ["Sourdough"]).seedEquipment)
    }

    @Test func seedAllTurnsTheDemoEquipmentOn() {
        #expect(LaunchOptions(arguments: ["-seedEquipment", "all"]).seedEquipment)
    }

    @Test func unknownOrMissingSeedValueMeansNoSeed() {
        #expect(!LaunchOptions(arguments: ["-seedEquipment", "x"]).seedEquipment)
        #expect(!LaunchOptions(arguments: ["-seedEquipment", "none"]).seedEquipment)
        #expect(!LaunchOptions(arguments: ["-seedEquipment"]).seedEquipment)
    }

    @Test func demoStartersAreOffByDefault() {
        #expect(!LaunchOptions(arguments: ["Sourdough"]).seedDemoStarters)
    }

    @Test func seedStartersDemoTurnsThemOn() {
        #expect(LaunchOptions(arguments: ["-seedStarters", "demo"]).seedDemoStarters)
    }

    @Test func otherOrMissingStarterSeedsAreIgnored() {
        #expect(!LaunchOptions(arguments: ["-seedStarters", "x"]).seedDemoStarters)
        #expect(!LaunchOptions(arguments: ["-seedStarters"]).seedDemoStarters)
    }

    @Test func splashSecondsStretchTheSplash() {
        #expect(LaunchOptions(arguments: ["-splashSeconds", "4"]).splashDuration == .seconds(4))
    }

    @Test func splashSecondsWithoutAValidNumberKeepTheDefault() {
        #expect(LaunchOptions(arguments: ["-splashSeconds"]).splashDuration == .seconds(1.6))
        #expect(LaunchOptions(arguments: ["-splashSeconds", "x"]).splashDuration == .seconds(1.6))
    }

    @Test func recognisesBothParameters() {
        let options = LaunchOptions(arguments: ["Sourdough", "-skipSplash", "-resetData"])
        #expect(options.skipSplash)
        #expect(options.resetData)
    }

    @Test func parametersAreIndependent() {
        #expect(LaunchOptions(arguments: ["-skipSplash"]) ==
                LaunchOptions(arguments: ["-skipSplash", "-other"]))
        #expect(LaunchOptions(arguments: ["-resetData"]).resetData)
        #expect(!LaunchOptions(arguments: ["-resetData"]).skipSplash)
    }
}
