import Testing
@testable import SourdoughKit

// Expected values are worked out by hand, never taken from a program run.

private func close(_ a: Double, _ b: Double, _ eps: Double = 1e-9) -> Bool { abs(a - b) < eps }

private func same(_ mix: FlourMix, _ expected: [Flour: Double]) -> Bool {
    mix.flours == Flour.allCases.filter { expected[$0] != nil }
        && expected.allSatisfy { close(mix.share(of: $0.key), $0.value) }
}

struct FlourTests {
    @Test func elevenFloursOfThreeGrains() {
        #expect(Flour.allCases.count == 11)
        #expect(Flour.allCases.filter { $0.grain == .rye } == [.rye997, .rye1150, .rye1370, .ryeWholeGrain])
        #expect(Flour.allCases.filter { $0.grain == .spelt } == [.spelt630, .spelt1050, .speltWholeGrain])
        #expect(Flour.allCases.filter { $0.grain == .wheat } == [.wheat405, .wheat550, .wheat1050, .wheatWholeGrain])
    }

    @Test func typeNumbersAndWholeGrain() {
        #expect(Flour.allCases.map(\.typeNumber) == [997, 1150, 1370, nil, 630, 1050, nil, 405, 550, 1050, nil])
    }

    @Test func darkerFlourTakesMoreWaterAndSpeltLessThanWheat() {
        for grain in FlourType.allCases {
            let uptakes = Flour.allCases.filter { $0.grain == grain }.map(\.waterUptake)
            #expect(uptakes == uptakes.sorted())
            #expect(Set(uptakes).count == uptakes.count)
        }
        #expect(Flour.spelt1050.waterUptake < Flour.wheat1050.waterUptake)
        #expect(Flour.speltWholeGrain.waterUptake < Flour.wheatWholeGrain.waterUptake)
    }

    @Test func wheatAndSpeltStandInForEachOtherButRyeDoesNot() {
        #expect(Flour.allCases.map(\.counterpart) == [
            nil, nil, nil, nil,
            .wheat550, .wheat1050, .wheatWholeGrain,
            .spelt630, .spelt630, .spelt1050, .speltWholeGrain,
        ])
    }
}

struct FlourMixTests {
    let ryeMixed50 = BreadType.ryeMixedBread50.preset
    let ryeMixed70 = BreadType.ryeMixedBread70.preset

    @Test func emptySharesAreDropped() {
        let mix = FlourMix([.rye1150: 0, .spelt1050: 100])
        #expect(mix.flours == [.spelt1050])
        #expect(mix.share(of: .rye1150) == 0)
    }

    @Test func sharesOfGrainAndWholeGrain() {
        // 25 / 25 / 30 / 20: rye 25 + 25 = 50, whole grain 25 + 20 = 45.
        #expect(ryeMixed50.total == 100)
        #expect(ryeMixed50.ryeShare == 50)
        #expect(ryeMixed50.share(of: .spelt) == 50)
        #expect(ryeMixed50.share(of: .wheat) == 0)
        #expect(ryeMixed50.wholeGrainShare == 45)
    }

    @Test func gramsForATotal() {
        // 825 g flour: 25 % = 206.25 g, 30 % = 247.5 g, 20 % = 165 g.
        #expect(ryeMixed50.grams(of: .rye1150, totalGrams: 825) == 206.25)
        #expect(ryeMixed50.grams(of: .ryeWholeGrain, totalGrams: 825) == 206.25)
        #expect(ryeMixed50.grams(of: .spelt1050, totalGrams: 825) == 247.5)
        #expect(ryeMixed50.grams(of: .speltWholeGrain, totalGrams: 825) == 165)
        #expect(ryeMixed50.grams(of: .wheat405, totalGrams: 825) == 0)
    }

    @Test func hydrationIsTheWeightedWaterUptake() {
        // 0.25 × 85 + 0.25 × 95 + 0.30 × 70 + 0.20 × 78 = 21.25 + 23.75 + 21 + 15.6 = 81.6
        #expect(close(ryeMixed50.hydration, 81.6))
    }

    @Test func replacingKeepsTheShare() {
        #expect(same(ryeMixed70.replacing(.spelt1050, with: .wheat1050),
                     [.rye1150: 35, .ryeWholeGrain: 35, .wheat1050: 30]))
    }

    @Test func replacingWithAFlourInTheMixAddsUp() {
        #expect(same(ryeMixed50.replacing(.speltWholeGrain, with: .spelt1050),
                     [.rye1150: 25, .ryeWholeGrain: 25, .spelt1050: 50]))
    }

    @Test func replacingAMissingFlourOrWithItselfChangesNothing() {
        #expect(ryeMixed50.replacing(.wheat405, with: .wheat550) == ryeMixed50)
        #expect(ryeMixed50.replacing(.rye1150, with: .rye1150) == ryeMixed50)
    }

    @Test func settingTheSameShareChangesNothing() {
        #expect(ryeMixed50.setting(.rye1150, to: 25) == ryeMixed50)
    }

    @Test func lessGoesToTheSameGrainFirst() {
        // Rye 1150 25 → 15: the 10 go to rye whole grain, 25 → 35. Rye stays 50.
        let mix = ryeMixed50.setting(.rye1150, to: 15)
        #expect(same(mix, [.rye1150: 15, .ryeWholeGrain: 35, .spelt1050: 30, .speltWholeGrain: 20]))
        #expect(mix.ryeShare == 50)
    }

    @Test func theSameGrainSharesInProportion() {
        // Wheat 405 40 → 20 frees 20; wheat 1050 (30) and whole grain (10)
        // take it 3 : 1, so 15 and 5: 45 and 15.
        let mix = FlourMix([.wheat405: 40, .wheat1050: 30, .wheatWholeGrain: 10, .rye1150: 20])
        #expect(same(mix.setting(.wheat405, to: 20),
                     [.wheat405: 20, .wheat1050: 45, .wheatWholeGrain: 15, .rye1150: 20]))
    }

    @Test func withoutTheSameGrainTheCounterpartStepsIn() {
        // Spelt 1050 30 → 20 with no other spelt: wheat 1050 comes in at 10.
        let mix = ryeMixed70.setting(.spelt1050, to: 20)
        #expect(same(mix, [.rye1150: 35, .ryeWholeGrain: 35, .spelt1050: 20, .wheat1050: 10]))
    }

    @Test func ryeWithoutOtherRyeGoesToEveryoneInProportion() {
        // Rye 40 → 20 frees 20; spelt 30 and wheat 30 take 10 each.
        let mix = FlourMix([.rye1150: 40, .spelt1050: 30, .wheat1050: 30])
        #expect(same(mix.setting(.rye1150, to: 20), [.rye1150: 20, .spelt1050: 40, .wheat1050: 40]))
    }

    @Test func aLockedCounterpartIsPassedOver() {
        // Spelt 30 → 20, wheat 1050 locked: rye 35 and 35 take 5 each.
        let mix = ryeMixed70.setting(.spelt1050, to: 20, locked: [.wheat1050])
        #expect(same(mix, [.rye1150: 40, .ryeWholeGrain: 40, .spelt1050: 20]))
    }

    @Test func aSingleFlourWithoutCounterpartCannotShrink() {
        let mix = FlourMix([.rye1150: 100])
        #expect(mix.setting(.rye1150, to: 50) == mix)
    }

    @Test func moreIsTakenFromTheSameGrainFirst() {
        // Rye whole grain 25 → 40 takes 15 from rye 1150: 25 → 10.
        #expect(same(ryeMixed50.setting(.ryeWholeGrain, to: 40),
                     [.rye1150: 10, .ryeWholeGrain: 40, .spelt1050: 30, .speltWholeGrain: 20]))
    }

    @Test func whatTheSameGrainCannotGiveComesFromTheOthers() {
        // Rye whole grain 25 → 60 needs 35: rye 1150 gives all 25, the other
        // 10 come from spelt 30 and 20 in proportion 3 : 2, so 6 and 4.
        #expect(same(ryeMixed50.setting(.ryeWholeGrain, to: 60),
                     [.ryeWholeGrain: 60, .spelt1050: 24, .speltWholeGrain: 16]))
    }

    @Test func aNewFlourTakesFromAllInProportion() {
        // Wheat 550 at 10 %, no wheat in the mix: 35 / 35 / 30 give 3.5 / 3.5 / 3.
        #expect(same(ryeMixed70.setting(.wheat550, to: 10),
                     [.rye1150: 31.5, .ryeWholeGrain: 31.5, .spelt1050: 27, .wheat550: 10]))
    }

    @Test func targetsAreClampedAndLimitedByWhatThereIs() {
        let mix = FlourMix([.rye1150: 50, .spelt1050: 50])
        #expect(same(mix.setting(.rye1150, to: 150), [.rye1150: 100]))
        #expect(same(mix.setting(.rye1150, to: -5), [.spelt1050: 100]))
        #expect(mix.setting(.rye1150, to: 80, locked: [.spelt1050]) == mix)
    }

    @Test func aLimitMovesTheRestToTheSameGrain() {
        // 825 g, spelt 1050 at most 235 g instead of 247.5 g: the 12.5 g go to
        // spelt whole grain, 165 → 177.5 g.
        let mix = ryeMixed50.limited(totalGrams: 825, limits: [.spelt1050: 235])
        #expect(close(mix.grams(of: .spelt1050, totalGrams: 825), 235))
        #expect(close(mix.grams(of: .speltWholeGrain, totalGrams: 825), 177.5))
        #expect(close(mix.grams(of: .rye1150, totalGrams: 825), 206.25))
        #expect(mix.floursOverLimit(totalGrams: 825, limits: [.spelt1050: 235]).isEmpty)
    }

    @Test func limitsChainOnToTheCounterpart() {
        // As above, and spelt whole grain at most 165 g: its 12.5 g extra
        // cannot go back to the limited spelt 1050, so wheat whole grain gets them.
        let limits: [Flour: Double] = [.spelt1050: 235, .speltWholeGrain: 165]
        let mix = ryeMixed50.limited(totalGrams: 825, limits: limits)
        #expect(close(mix.grams(of: .spelt1050, totalGrams: 825), 235))
        #expect(close(mix.grams(of: .speltWholeGrain, totalGrams: 825), 165))
        #expect(close(mix.grams(of: .wheatWholeGrain, totalGrams: 825), 12.5))
        #expect(close(mix.ryeShare, 50))
    }

    @Test func aLimitThatCannotBeMetStaysOver() {
        let mix = FlourMix([.rye1150: 100])
        #expect(mix.limited(totalGrams: 1000, limits: [.rye1150: 500]) == mix)
        #expect(mix.floursOverLimit(totalGrams: 1000, limits: [.rye1150: 500]) == [.rye1150])
    }

    @Test func withoutFlourNothingIsLimited() {
        #expect(ryeMixed50.limited(totalGrams: 0, limits: [.rye1150: 1]) == ryeMixed50)
    }

    @Test func limitsAboveTheAmountChangeNothing() {
        #expect(ryeMixed50.limited(totalGrams: 825, limits: [.rye1150: 500]) == ryeMixed50)
        #expect(ryeMixed50.floursOverLimit(totalGrams: 825, limits: [.rye1150: 206.25]).isEmpty)
    }
}

struct BreadTypeTests {
    @Test func sixBreadTypes() {
        #expect(BreadType.allCases == [.speltBread, .speltMixedBread, .ryeMixedBread50,
                                       .ryeMixedBread70, .ryeBread80, .ryeWholeGrainBread])
    }

    @Test func presetsAreCompleteWithTheRyeOfTheirName() {
        for bread in BreadType.allCases {
            #expect(bread.preset.total == 100)
        }
        // Dinkelbrot 0/0, Dinkel-Mischbrot 20 + 10, then 50, 70, 80, 100.
        #expect(BreadType.allCases.map(\.preset.ryeShare) == [0, 30, 50, 70, 80, 100])
    }

    @Test func presetHydrationsLieInTheRangesOfTheNotes() {
        // Dinkelbrot 0.7 × 70 + 0.3 × 78 = 72.4 (notes: 70–75)
        // Dinkel-Mischbrot 0.2 × 85 + 0.1 × 95 + 0.5 × 70 + 0.2 × 78 = 77.1 (75–80)
        // Roggenmischbrot 50: 81.6 (about 80)
        // Roggenmischbrot 70: 0.35 × 85 + 0.35 × 95 + 0.3 × 70 = 84 (about 85)
        // Roggenbrot 80: 0.4 × 85 + 0.4 × 95 + 0.2 × 70 = 86 (85–90)
        // Roggenvollkorn: 0.2 × 85 + 0.8 × 95 = 93 (90–100)
        let expected = [72.4, 77.1, 81.6, 84, 86, 93]
        for (bread, hydration) in zip(BreadType.allCases, expected) {
            #expect(close(bread.preset.hydration, hydration, 1e-9))
        }
    }

    @Test func ryeRangesAreThePresetGiveOrTakeTen() {
        #expect(BreadType.allCases.map(\.ryeRange) == [0...10, 20...40, 40...60, 60...80, 70...90, 90...100])
    }
}

struct BakeRulesTests {
    @Test func aRyeStarterSuitsEverything() {
        #expect(BakeRules.suits(.rye, mix: BreadType.ryeWholeGrainBread.preset))
    }

    @Test func otherStartersSuitLessThanThirtyPercentRye() {
        #expect(BakeRules.suits(.spelt, mix: FlourMix([.rye1150: 29, .spelt1050: 71])))
        #expect(!BakeRules.suits(.spelt, mix: BreadType.speltMixedBread.preset))
        #expect(!BakeRules.suits(.wheat, mix: BreadType.ryeMixedBread50.preset))
    }

    @Test func aPresetWithASuitableStarterHasNoIssues() {
        for bread in BreadType.allCases {
            #expect(BakeRules.issues(mix: bread.preset, bread: bread, starterFlour: .rye,
                                     totalGrams: 1000, limits: [:]).isEmpty)
            #expect(BakeRules.issues(mix: bread.preset, bread: bread, starterFlour: nil,
                                     totalGrams: 1000, limits: [:]).isEmpty)
        }
        #expect(BakeRules.issues(mix: BreadType.speltBread.preset, bread: .speltBread, starterFlour: .spelt,
                                 totalGrams: 1000, limits: [:]).isEmpty)
    }

    @Test func issuesNameWhatIsWrong() {
        #expect(BakeRules.issues(mix: BreadType.ryeMixedBread50.preset, bread: .ryeMixedBread50,
                                 starterFlour: .wheat, totalGrams: 1000, limits: [:]) == [.needsRyeStarter])
        #expect(BakeRules.issues(mix: FlourMix([.rye1150: 20, .spelt1050: 80]), bread: .speltBread,
                                 starterFlour: nil, totalGrams: 1000, limits: [:]) == [.tooMuchRye(maximum: 10)])
        #expect(BakeRules.issues(mix: FlourMix([.rye1150: 80, .spelt1050: 20]), bread: .ryeWholeGrainBread,
                                 starterFlour: .rye, totalGrams: 1000, limits: [:]) == [.tooLittleRye(minimum: 90)])
        #expect(BakeRules.issues(mix: FlourMix([.rye1150: 100]), bread: .ryeWholeGrainBread,
                                 starterFlour: .rye, totalGrams: 1000, limits: [.rye1150: 500]) == [.overLimit(.rye1150)])
    }

    @Test func lessSpeltFlowsToWheatSoOnlyMoreSpeltIsBounded() {
        // Roggenmischbrot 70, spelt 30: less spelt goes to wheat 1050, the rye
        // stays at 70. More spelt is taken from the rye, 100 − spelt, which
        // must stay ≥ 60: spelt at most 40.
        #expect(BakeRules.range(of: .spelt1050, in: BreadType.ryeMixedBread70.preset, bread: .ryeMixedBread70,
                                totalGrams: 1000, limits: [:]) == 0...40)
    }

    @Test func ryeIsBoundedOnceTheOtherRyeIsUsedUp() {
        // Rye 1150 up to 70 only takes from rye whole grain (rye stays 70);
        // beyond, it takes spelt and the rye share is the rye 1150 share: at most 80.
        #expect(BakeRules.range(of: .rye1150, in: BreadType.ryeMixedBread70.preset, bread: .ryeMixedBread70,
                                totalGrams: 1000, limits: [:]) == 0...80)
    }

    @Test func aLimitBoundsTheRange() {
        // 1000 g with rye 1150 at most 300 g: never above 30 %.
        let limits: [Flour: Double] = [.rye1150: 300]
        let mix = BreadType.ryeMixedBread70.preset.limited(totalGrams: 1000, limits: limits)
        #expect(BakeRules.range(of: .rye1150, in: mix, bread: .ryeMixedBread70,
                                totalGrams: 1000, limits: limits) == 0...30)
    }

    @Test func noRangeWhereNothingFits() {
        #expect(BakeRules.range(of: .rye1150, in: FlourMix([.rye1150: 100]), bread: .speltBread,
                                totalGrams: 1000, limits: [:]) == nil)
    }
}
