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
