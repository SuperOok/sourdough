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
        #expect(LaunchOptions(arguments: ["Sourdough"]).seedEquipment == nil)
    }

    @Test func seedAllMeansEverythingInTheNonDefaultVariants() {
        let seed = LaunchOptions(arguments: ["-seedEquipment", "all"]).seedEquipment
        #expect(seed == Equipment(
            hasKneadingMachine: true,
            pot: .init(hasSiliconeLiner: true),
            loafPan: .init(material: .castIron, hasLid: true, hasSiliconeLiner: true),
            hasProvingBasket: true))
    }

    @Test func seedNoneMeansConfiguredWithNothing() {
        #expect(LaunchOptions(arguments: ["-seedEquipment", "none"]).seedEquipment == Equipment())
    }

    @Test func unknownOrMissingSeedValueMeansNoSeed() {
        #expect(LaunchOptions(arguments: ["-seedEquipment", "x"]).seedEquipment == nil)
        #expect(LaunchOptions(arguments: ["-seedEquipment"]).seedEquipment == nil)
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
