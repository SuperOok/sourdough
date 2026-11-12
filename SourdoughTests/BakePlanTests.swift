import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

// Expected values are worked out by hand, never taken from a program run.

private func close(_ a: Double?, _ b: Double) -> Bool { a.map { abs($0 - b) < 1e-9 } ?? false }

struct BakeTextTests {
    @Test func flourNames() {
        #expect(Flour.allCases.map(\.germanName) == [
            "Roggen 997", "Roggen 1150", "Roggen 1370", "Roggenvollkorn",
            "Dinkel 630", "Dinkel 1050", "Dinkelvollkorn",
            "Weizen 405", "Weizen 550", "Weizen 1050", "Weizenvollkorn",
            "Buchweizenmehl",
        ])
    }

    @Test func breadNamesAndCharacters() {
        #expect(BreadType.allCases.map(\.germanName) == [
            "Weizenbrot", "Weizenvollkornbrot", "Weizenmischbrot", "Dinkelbrot", "Dinkel-Mischbrot", "Roggenmischbrot 50",
            "Roggenmischbrot 70", "Roggenbrot 80", "Roggenvollkornbrot",
            "Buchweizen-Roggenbrot", "Buchweizen-Dinkelbrot",
        ])
        #expect(BreadType.allCases.map(\.character) == [
            "Locker, mild, mit knuspriger Kruste.", "Saftig, kräftig, leicht nussig.",
            "Locker mit Roggenwürze, bleibt länger frisch.",
            "Luftig, mild-nussig, schnittfest.", "Locker bis mittel, leicht säuerlich.",
            "Mitteldicht und würzig.", "Dicht, feucht, kräftig-säuerlich.",
            "Dicht, saftig, aromatisch.", "Sehr dicht, feucht und herb.",
            "Dicht, feucht, nussig-herb.", "Mitteldicht, feucht, mild-nussig.",
        ])
    }

    @Test func addInNamesAndAmounts() {
        #expect(AddIn.allCases.map(\.germanName)
                == ["Saaten", "Nüsse", "Trockenfrüchte", "Röstzwiebeln", "Kräuter"])
        // 15 % of 400 g = 60 g.
        #expect(BakeText.addInAmount(share: 15, totalGrams: 400) == "15 % · 60 g")
        #expect(BakeText.addInAmount(share: 15, totalGrams: nil) == "15 %")
        #expect(BakeText.soakAmount(Recipe.AddInPortion(addIn: .seeds, grams: 60, waterGrams: 60))
                == "60 g in 60 g Wasser")
    }

    @Test func percentsHaveAtMostOneDecimal() {
        #expect(BakeText.percent(30) == "30 %")
        #expect(BakeText.percent(28.48) == "28,5 %")
        #expect(BakeText.percent(81.6) == "81,6 %")
        #expect(BakeText.percent(84.04) == "84 %")
    }

    @Test func gramsAreWhole() {
        #expect(BakeText.grams(247.5) == "248 g")
        #expect(BakeText.grams(206.25) == "206 g")
    }

    @Test func ranges() {
        #expect(BakeText.range(0...40) == "0–40 %")
    }

    @Test func issues() {
        #expect(BakeText.issue(.tooLittleRye(minimum: 60), bread: .ryeMixedBread70)
                == "Zu wenig Roggen: Ein Roggenmischbrot 70 braucht mindestens 60 % Roggen.")
        #expect(BakeText.issue(.tooMuchRye(maximum: 10), bread: .speltBread)
                == "Zu viel Roggen: Ein Dinkelbrot verträgt höchstens 10 % Roggen.")
        #expect(BakeText.issue(.tooMuchBuckwheat(maximum: 30), bread: .buckwheatSpeltBread)
                == "Zu viel Buchweizen: Ohne Gluten wird das Brot ab 30 % dicht und schwer. Nimm höchstens 30 %.")
        #expect(BakeText.issue(.needsRyeStarter, bread: .ryeMixedBread50)
                == "Ab 30 % Roggen braucht der Teig einen Roggensauerteig. Wähle einen Roggenstarter oder nimm weniger Roggen.")
        #expect(BakeText.issue(.overLimit(.rye1150), bread: .ryeWholeGrainBread)
                == "Roggen 1150 liegt über deiner Grenze, und kein anderes Mehl kann den Rest übernehmen.")
    }

    @Test func mixSummary() {
        #expect(BakeText.mixSummary(BreadType.ryeMixedBread50.preset, bread: .ryeMixedBread50)
                == "Roggen 50 % (erlaubt 40–60 %) · Vollkorn 45 %")
    }
}

struct BakePlanModelTests {
    @Test func startsWithTheRyeMixedBread50ForAKilo() {
        let model = BakePlanModel()
        #expect(model.bread == .ryeMixedBread50)
        #expect(model.mix == BreadType.ryeMixedBread50.preset)
        #expect(model.totalText == "1000")
        #expect(model.totalGrams == 1000)
        #expect(model.limits.isEmpty)
        #expect(model.errorText == nil)
        #expect(model.starterID == nil)
    }

    @Test func anotherBreadStartsFromItsPreset() {
        let model = BakePlanModel()
        model.setShare(.rye1150, 15)
        model.bread = .ryeMixedBread50
        #expect(model.mix.share(of: .rye1150) == 15)
        model.bread = .speltBread
        #expect(model.mix == BreadType.speltBread.preset)
    }

    @Test(arguments: ["", "0", "abc", "-5"])
    func theTotalMustBeAboveZero(text: String) {
        let model = BakePlanModel()
        model.totalText = text
        #expect(model.totalGrams == nil)
        #expect(model.errorText == BakePlanModel.needsFlour)
        #expect(model.effectiveMix == model.mix)
        #expect(model.grams(of: .rye1150) == nil)
        #expect(model.waterGrams == nil)
        #expect(model.range(of: .rye1150) == nil)
    }

    @Test func limitsAreTypedInGrams() {
        let model = BakePlanModel()
        model.setLimitText(.spelt1050, "235")
        #expect(model.limitText(.spelt1050) == "235")
        #expect(model.limits == [.spelt1050: 235])
        model.setLimitText(.spelt1050, "0")
        #expect(model.limits.isEmpty)
        #expect(model.errorText == nil)
        model.setLimitText(.spelt1050, "viel")
        #expect(model.errorText == StarterFormModel.numbersOnly)
        model.setLimitText(.spelt1050, "")
        #expect(model.limitText(.spelt1050) == "")
        #expect(model.errorText == nil)
    }

    @Test func theLimitAppliesToTheEffectiveMix() {
        // 825 g, spelt 1050 at most 235 g: the other 12.5 g go to spelt whole
        // grain, 165 + 12.5 = 177.5 g.
        let model = BakePlanModel()
        model.totalText = "825"
        model.setLimitText(.spelt1050, "235")
        #expect(close(model.grams(of: .spelt1050), 235))
        #expect(close(model.grams(of: .speltWholeGrain), 177.5))
        #expect(model.mix == BreadType.ryeMixedBread50.preset)
    }

    @Test func changesStartFromTheEffectiveMix() {
        let model = BakePlanModel()
        model.totalText = "825"
        model.setLimitText(.spelt1050, "235")
        model.setShare(.rye1150, 15)
        #expect(close(model.mix.share(of: .spelt1050) * 8.25, 235))
        #expect(model.mix.share(of: .ryeWholeGrain) == 35)
    }

    @Test func sharesMoveAsThePackageSays() {
        // Rye 1150 25 → 15: rye whole grain 25 → 35.
        let model = BakePlanModel()
        model.setShare(.rye1150, 15)
        #expect(model.effectiveMix.share(of: .ryeWholeGrain) == 35)
        model.remove(.rye1150)
        #expect(model.effectiveMix.share(of: .ryeWholeGrain) == 50)
        #expect(model.effectiveMix.share(of: .rye1150) == 0)
    }

    @Test func replacing() {
        let model = BakePlanModel()
        model.replace(.spelt1050, with: .wheat1050)
        #expect(model.effectiveMix.share(of: .wheat1050) == 30)
        #expect(model.effectiveMix.share(of: .spelt1050) == 0)
    }

    @Test func addableFloursAreThoseNotInTheMix() {
        #expect(BakePlanModel().addableFlours == [.rye997, .rye1370, .spelt630,
                                                  .wheat405, .wheat550, .wheat1050, .wheatWholeGrain, .buckwheat])
    }

    @Test func anAddedFlourTakesTenPercentFromAll() {
        // 25 / 25 / 30 / 20 each give a tenth: 22.5 / 22.5 / 27 / 18. Rye 45 is allowed.
        let model = BakePlanModel()
        model.add(.wheat1050)
        #expect(model.effectiveMix.share(of: .wheat1050) == 10)
        #expect(close(model.effectiveMix.share(of: .rye1150), 22.5))
        #expect(close(model.effectiveMix.share(of: .spelt1050), 27))
        #expect(close(model.effectiveMix.share(of: .speltWholeGrain), 18))
    }

    @Test func anAddedFlourStaysWithinItsLimit() {
        // 1000 g with wheat 1050 at most 50 g: 5 %.
        let model = BakePlanModel()
        model.setLimitText(.wheat1050, "50")
        model.add(.wheat1050)
        #expect(close(model.effectiveMix.share(of: .wheat1050), 5))
    }

    @Test func aFlourWithNoRoomIsNotAdded() {
        // At most 1 g of 1000 g: not even 1 %.
        let model = BakePlanModel()
        model.setLimitText(.wheat1050, "1")
        model.add(.wheat1050)
        #expect(model.effectiveMix == BreadType.ryeMixedBread50.preset)
    }

    @Test func rangesComeFromTheRules() {
        let model = BakePlanModel(bread: .ryeMixedBread70)
        #expect(model.range(of: .spelt1050) == 0...40)
    }

    @Test func waterFollowsTheHydration() {
        // 81.6 % of 825 g = 673.2 g.
        let model = BakePlanModel()
        model.totalText = "825"
        #expect(close(model.hydration, 81.6))
        #expect(close(model.waterGrams, 673.2))
    }

    @Test func theStarterDecidesAboutRye() {
        let now = Date(timeIntervalSince1970: 0)
        let rye = Starter(name: "R", flour: .rye, createdAt: now)
        let wheat = Starter(name: "W", flour: .wheat, createdAt: now)
        let model = BakePlanModel()
        #expect(model.starter(in: [rye, wheat]) == nil)
        model.starterID = wheat.id
        #expect(model.starter(in: [rye, wheat]) == wheat)
        #expect(model.issues(starters: [rye, wheat]) == [.needsRyeStarter])
        model.starterID = rye.id
        #expect(model.issues(starters: [rye, wheat]).isEmpty)
        #expect(model.issues(starters: []).isEmpty)
    }
}

private let kneader = EquipmentItem(kind: .kneader, name: "Bosch")
private let pot = EquipmentItem(kind: .pot, name: "Bräter",
                                dimensions: Dimensions(shape: .round, lengthCm: 27, heightCm: 7.5))
private let pan = EquipmentItem(kind: .pan, name: "Guss",
                                dimensions: Dimensions(shape: .rectangular, lengthCm: 27, widthCm: 10, heightCm: 11))
private let basket = EquipmentItem(kind: .basket, name: "Körbchen")
private let items = [kneader, pot, pan, basket]

struct BakeSetupTextTests {
    @Test func vesselNames() {
        #expect(BakeSetup.Vessel.allCases.map(\.germanName) == ["Kastenform", "Bräter", "Blech"])
    }

    @Test func whereTheDoughAmountComesFrom() {
        let small = EquipmentItem(kind: .pan, name: "Klein",
                                  dimensions: Dimensions(shape: .rectangular, lengthCm: 30, widthCm: 10, heightCm: 8))
        #expect(BakeText.doughSource(BakeSetup(vessel: .loafPan, pan: small))
                == "Aus dem Volumen von „Klein“ (2,4 l), zu etwa 60 % gefüllt.")
        #expect(BakeText.doughSource(BakeSetup(vessel: .pot, pot: pot))
                == "Aus der Bodenfläche von „Bräter“: Ein runder Bräter mit 27 cm Durchmesser fasst etwa 1 kg Teig.")
        #expect(BakeText.doughSource(BakeSetup(vessel: .tray))
                == "Ohne Innenmaße rechnet die App mit 1000 g Teig.")
        #expect(BakeText.doughSource(BakeSetup(vessel: .pot, pot: EquipmentItem(kind: .pot, name: "X")))
                == "Ohne Innenmaße rechnet die App mit 1000 g Teig.")
    }

    @Test func setupIssues() {
        #expect(BakeText.issue(.tooMuchRyeToStandFree, bread: .ryeMixedBread70)
                == "Mit mehr als 50 % Roggen läuft ein freigeschobenes Brot auseinander. Nimm die Kastenform oder weniger Roggen.")
        #expect(BakeText.issue(.missingEquipment(.pan), bread: .ryeMixedBread70)
                == "Für diesen Backweg fehlt ein Utensil: Kastenform.")
    }
}

struct BakePlanSetupTests {
    @Test func thereIsNoSetupBeforeStepTwo() {
        let model = BakePlanModel()
        #expect(model.setup == nil)
        #expect(model.doughGrams == nil)
        model.changeSetup { $0.vessel = .tray }
        #expect(model.setup == nil)
    }

    @Test func stepTwoProposesThePotAndItsAmount() {
        // Roggenmischbrot 50 in the 27 cm pot: 1000 g dough at 81.6 % water and
        // 2 % salt: 1000 / 1.836 = 544.66 g flour.
        let model = BakePlanModel()
        model.proposeSetup(from: items)
        #expect(model.setup == BakeSetup(vessel: .pot, pot: pot, basket: basket, kneader: kneader))
        #expect(model.doughGrams.map { abs($0 - 1000) < 1e-9 } == true)
        #expect(model.totalText == "545")
    }

    @Test func addInsTakeTheirShareOfTheDough() {
        // 1000 g dough; seeds 15 % with as much water add 0.30 per gram of
        // flour: 1000 / (1.836 + 0.30) = 468.16 g flour.
        let model = BakePlanModel()
        model.proposeSetup(from: items)
        model.addIns.add(.seeds)
        #expect(model.totalText == "468")
        model.addIns.remove(.seeds)
        #expect(model.totalText == "545")
        // The recipe and the bake get them too: 15 % of 545 g = 81.75 g.
        model.addIns.add(.nuts)
        #expect(model.recipe(starters: [])?.addIns.map(\.addIn) == [.nuts])
    }

    @Test func aProposalDoesNotOverrideAChoice() {
        let model = BakePlanModel()
        model.proposeSetup(from: items)
        model.chooseVessel(.loafPan, from: items)
        model.proposeSetup(from: items)
        #expect(model.setup?.vessel == .loafPan)
    }

    @Test func theLoafPanTakesItsAmount() {
        // 2970 ml × 0.5 = 1485 g dough / 1.836 = 808.82 g flour.
        let model = BakePlanModel()
        model.proposeSetup(from: items)
        model.chooseVessel(.loafPan, from: items)
        #expect(model.setup?.pan == pan)
        #expect(model.setup?.pot == pot)
        #expect(model.doughGrams == 1485)
        #expect(model.totalText == "809")
        model.chooseVessel(.pot, from: items)
        #expect(model.setup?.pot == pot)
        #expect(model.totalText == "545")
    }

    @Test func choosingWithoutAProposalStartsFresh() {
        let model = BakePlanModel()
        model.chooseVessel(.pot, from: items)
        #expect(model.setup == BakeSetup(vessel: .pot, pot: pot))
        model.chooseVessel(.tray, from: [])
        #expect(model.setup?.vessel == .tray)
    }

    @Test func changingTheSetupKeepsTheRest() {
        let model = BakePlanModel()
        model.proposeSetup(from: items)
        model.changeSetup { $0.basket = nil }
        #expect(model.setup == BakeSetup(vessel: .pot, pot: pot, kneader: kneader))
    }

    @Test func tooMuchRyeForThePotIsAnIssue() {
        let model = BakePlanModel(bread: .ryeMixedBread70)
        model.proposeSetup(from: [pot])
        #expect(model.issues(starters: []) == [.tooMuchRyeToStandFree])
    }

    @Test func theRecipeFollowsTheMix() {
        let model = BakePlanModel()
        model.totalText = "825"
        #expect(model.recipe(starters: []) == Recipe(mix: BreadType.ryeMixedBread50.preset, totalGrams: 825,
                                                    starterFlour: nil))
        model.totalText = ""
        #expect(model.recipe(starters: []) == nil)
    }
}

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// November 2026, UTC; the 13th is a Friday.
private func nov(_ day: Int, _ hour: Int) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
}

/// The mixing of the plan for Saturday 18:00: shaping at 09:25, before it the
/// warm bulk rest 1.75 / √3 h, kneading 20 min, the sourdough at the cool
/// place 8 × 3^0.6 h and the mixing 10 min; Friday about 16:26.
private let referenceStart: Date = {
    let bulk: Double = 1.75 / 3.0.squareRoot()
    let sourdough: Double = 8 * pow(3, 0.6)
    let hours: Double = 25.0 / 60 - bulk - 20.0 / 60 - sourdough - 10.0 / 60
    return nov(14, 9) + hours * 3600
}()

struct BakePlanScheduleTests {
    @Test func temperaturesComeFromWhatWasRemembered() {
        let model = BakePlanModel()
        model.useTemperatures(Temperatures(roomCelsius: 19.5, fridgeCelsius: 4))
        #expect(model.roomText == "19,5")
        #expect(model.fridgeText == "4")
        #expect(model.temperatures == Temperatures(roomCelsius: 19.5, fridgeCelsius: 4))
        #expect(model.temperatureError == nil)
    }

    @Test func onlyValidTemperaturesAreTaken() {
        let model = BakePlanModel()
        model.useTemperatures(Temperatures())
        model.roomText = "5"
        #expect(model.temperatureError == StarterFormModel.roomRange)
        #expect(model.temperatures.roomCelsius == 22)
        model.roomText = "20"
        model.fridgeText = "20"
        #expect(model.temperatureError == StarterFormModel.fridgeRange)
        #expect(model.temperatures == Temperatures(roomCelsius: 20, fridgeCelsius: 5))
        model.fridgeText = "6"
        #expect(model.temperatures.fridgeCelsius == 6)
    }

    @Test func theCoolPlaceIsRememberedAndChecked() {
        let model = BakePlanModel()
        model.useTemperatures(Temperatures(roomCelsius: 21, fridgeCelsius: 4, coolCelsius: 13.5, usesCoolPlace: true))
        #expect(model.coolText == "13,5")
        #expect(model.usesCoolPlace)
        #expect(model.temperatures.coolCelsius == 13.5 && model.temperatures.usesCoolPlace)
        // Only 8 to 18 °C are taken.
        model.coolText = "20"
        #expect(model.temperatureError == StarterFormModel.coolRange)
        #expect(model.temperatures.coolCelsius == 13.5)
        model.coolText = "7"
        #expect(model.temperatureError == StarterFormModel.coolRange)
        model.coolText = "12"
        #expect(model.temperatureError == nil)
        #expect(model.temperatures.coolCelsius == 12)
        // Without a cool place its field does not matter.
        model.coolText = "kalt"
        model.usesCoolPlace = false
        #expect(model.temperatureError == nil)
        #expect(!model.temperatures.usesCoolPlace)
        model.usesCoolPlace = true
        #expect(model.temperatureError == StarterFormModel.coolRange)
    }

    @Test func noScheduleWithoutEquipmentAndTarget() {
        let model = BakePlanModel()
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        #expect(model.anchorTime == nil)
        #expect(model.chosenTime == .distantPast)
        model.chosenTime = nov(15, 12)
        #expect(model.anchorTime == nov(15, 12))
        model.anchorTime = nil
        #expect(model.schedule(calendar: utc) == nil)
        #expect(model.target(calendar: utc) == nil)
        model.setHours(2, of: .proof, calendar: utc)
        model.stepHours(0.5, of: .proof, calendar: utc)
        #expect(model.choices.isEmpty)
        #expect(model.wishes.isEmpty)
        // Without a plan the anchor changes alone.
        #expect(model.anchor == .ready)
        model.setAnchor(.start, calendar: utc)
        #expect(model.anchor == .start)
        #expect(model.anchorTime == nil && model.choices.isEmpty)
    }

    @Test func switchingTheAnchorKeepsThePlan() {
        // Saturday 18:00 backwards (see `theTargetIsProposedOnce`): sourdough
        // 8 × 3^0.6 h at the cool place, bulk 1.75 / √3 h warm, proof 1.5 h at
        // room temperature; mixed on Friday at 09:25 on Saturday minus
        // 1.75 / √3 h, 20 min, 8 × 3^0.6 h and 10 min.
        let model = BakePlanModel()
        model.proposeSetup(from: [pot])
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        let before = model.schedule(calendar: utc)!
        let start = referenceStart
        #expect(abs(before.start.timeIntervalSince(start)) < 0.001)
        model.setAnchor(.start, calendar: utc)
        #expect(model.anchor == .start)
        #expect(model.anchorTime == before.start)
        #expect(model.choices[.sourdough]?.place == .cool && model.choices[.bulk]?.place == .warm
                && model.choices[.proof]?.place == .room)
        let after = model.schedule(calendar: utc)!
        for (step, old) in zip(after.steps, before.steps) {
            #expect(step.kind == old.kind && abs(step.start.timeIntervalSince(old.start)) < 0.001)
        }
        #expect(abs(model.target(calendar: utc)!.timeIntervalSince(nov(14, 18))) < 0.001)
        model.setAnchor(.start, calendar: utc)
        #expect(model.anchorTime == before.start)
        // Forwards, half an hour more for the sourdough (15.97 h, still at the
        // cool place, 12.37 to 19.33 h) moves the rest: ready at 18:30.
        model.stepHours(0.5, of: .sourdough, calendar: utc)
        #expect(model.choices[.sourdough]?.place == .cool)
        #expect(abs(model.target(calendar: utc)!.timeIntervalSince(nov(14, 18) + 1800)) < 0.001)
        #expect(model.schedule(calendar: utc)!.start == before.start)
        #expect(model.schedule(calendar: utc)!.conflicts.isEmpty)
        // Back to planning backwards: the field takes the new target.
        model.setAnchor(.ready, calendar: utc)
        #expect(model.anchor == .ready)
        #expect(abs(model.anchorTime!.timeIntervalSince(nov(14, 18) + 1800)) < 0.001)
        #expect(abs(model.schedule(calendar: utc)!.start.timeIntervalSince(before.start)) < 0.001)
    }

    @Test func forwardsTheStartOfTheProposedPlanIsProposed() {
        // The start of the plan for Saturday 18:00. Forwards without fixed
        // rests the sourdough again goes to the cool place (at room
        // temperature kneading would fall between 23:00 and 03:00), but the bulk
        // rest stays at room temperature: from the end of kneading, 08:24 on
        // Saturday, 1.75 h until 10:09, and shaping until 10:24 fits. That is
        // 1.75 − 1.75 / √3 h longer than warm, and the bread is ready that much
        // later.
        let model = BakePlanModel()
        model.setAnchor(.start, calendar: utc)
        model.proposeSetup(from: [pot])
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        let start = referenceStart
        #expect(abs(model.anchorTime!.timeIntervalSince(start)) < 0.001)
        let schedule = model.schedule(calendar: utc)!
        #expect(schedule.rest(.bulk)?.kind == .rest(.bulk, .room))
        let later = (1.75 - 1.75 / 3.0.squareRoot()) * 3600
        #expect(abs(model.target(calendar: utc)!.timeIntervalSince(nov(14, 18) + later)) < 0.001)
    }

    @Test func theTargetIsProposedOnce() {
        // As in the package: Friday 09:00, Roggenmischbrot 50 in the pot at
        // 22 °C → Saturday 18:00.
        let model = BakePlanModel()
        model.proposeSetup(from: [pot])
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        #expect(model.anchorTime == nov(14, 18))
        model.anchorTime = nov(15, 12)
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        #expect(model.anchorTime == nov(15, 12))
        #expect(model.schedule(calendar: utc) == Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot,
                                                          temperatures: Temperatures(), calendar: utc))
    }

    @Test func restsCanBeFixedMovedAndReset() {
        // Saturday 18:00: the proof is at room temperature.
        let model = BakePlanModel()
        model.proposeSetup(from: [pot])
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        model.setHours(2, of: .proof, calendar: utc)
        #expect(model.choices == [.proof: RestChoice(place: .room, hours: 2)])
        // In the fridge at 5 °C the proof takes 1.5 h × 3^1.7.
        model.setPlace(.fridge, of: .proof)
        #expect(model.choices[.proof]?.place == .fridge)
        #expect(abs(model.choices[.proof]!.hours - 1.5 * pow(3, 1.7)) < 1e-9)
        model.resetChoices()
        #expect(model.choices.isEmpty)
    }

    @Test func aTimeBeyondTheRangeMovesTheRestToAnotherPlace() {
        // The proof at room temperature takes 1.275 to 1.8 h, at the cool place
        // (16 °C) 2.46 to 3.48 h. 2.5 h is in the second range.
        let model = BakePlanModel()
        model.proposeSetup(from: [pot])
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        model.setHours(2.5, of: .proof, calendar: utc)
        #expect(model.choices == [.proof: RestChoice(place: .cool, hours: 2.5)])
        #expect(model.schedule(calendar: utc)?.rest(.proof)?.kind == .rest(.proof, .cool))
        #expect(model.needed(for: .proof, in: model.schedule(calendar: utc)!) == nil)
    }

    @Test func plusAndMinusStepFromTheTimeAsked() {
        let model = BakePlanModel()
        model.proposeSetup(from: [pot])
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        // 1.5 h + 0.5 h = 2 h: no place gives that (room up to 1.8 h, cool from
        // 2.46 h), the closest is the room. The plan keeps 1.8 h and says that
        // 2 h would take 22 − 10 × log₃(2 / 1.5) = 19.4 °C.
        model.stepHours(0.5, of: .proof, calendar: utc)
        #expect(model.choices == [.proof: RestChoice(place: .room, hours: 2)])
        var schedule = model.schedule(calendar: utc)!
        #expect(abs(schedule.rest(.proof)!.hours - 1.8) < 1e-9)
        var needed = model.needed(for: .proof, in: schedule)!
        #expect(needed.hours == 2)
        #expect(abs(needed.celsius - (22 - 10 * log(4.0 / 3) / log(3))) < 1e-9)
        // Another half hour is asked from the 2 h, not from the 1.8 h: 2.5 h
        // are in the cool range.
        model.stepHours(0.5, of: .proof, calendar: utc)
        #expect(model.choices == [.proof: RestChoice(place: .cool, hours: 2.5)])
        schedule = model.schedule(calendar: utc)!
        #expect(model.needed(for: .proof, in: schedule) == nil)
        // And back again.
        model.stepHours(-0.5, of: .proof, calendar: utc)
        #expect(model.choices[.proof]?.place == .room)
        // Never shorter than a quarter of an hour; the warm place is closest
        // and the plan says what that would take: 22 + 10 × log₃(6) = 38.3 °C.
        model.stepHours(-10, of: .proof, calendar: utc)
        #expect(model.choices == [.proof: RestChoice(place: .warm, hours: 0.25)])
        needed = model.needed(for: .proof, in: model.schedule(calendar: utc)!)!
        #expect(needed.hours == 0.25)
        #expect(abs(needed.celsius - (22 + 10 * log(6) / log(3))) < 1e-9)
    }

    @Test func choosingAPlaceOrResettingForgetsTheWish() {
        let model = BakePlanModel()
        model.proposeSetup(from: [pot])
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        model.setHours(2, of: .proof, calendar: utc)
        #expect(model.wishes == [.proof: 2])
        model.setPlace(.fridge, of: .proof)
        #expect(model.wishes.isEmpty)
        #expect(model.needed(for: .proof, in: model.schedule(calendar: utc)!) == nil)
        model.setHours(2, of: .bulk, calendar: utc)
        model.resetChoices()
        #expect(model.wishes.isEmpty && model.choices.isEmpty)
    }
}

struct ScheduleTextTests {
    @Test func timesAndDays() {
        #expect(ScheduleText.time(nov(14, 8) + 600, calendar: utc) == "Sa 08:10")
        #expect(ScheduleText.time(nov(15, 21), calendar: utc) == "So 21:00")
        #expect(ScheduleText.day(nov(14, 18), calendar: utc) == "Sa 14.11. 18:00")
        #expect(ScheduleText.day(nov(9, 7), calendar: utc) == "Mo 09.11. 07:00")
        #expect(ScheduleText.weekday(nov(14, 8), calendar: utc) == "Sa")
        #expect(ScheduleText.weekday(nov(15, 21), calendar: utc) == "So")
        #expect(ScheduleText.dayMonth(nov(14, 18), calendar: utc) == "14.11.")
        #expect(ScheduleText.dayMonth(nov(9, 7), calendar: utc) == "09.11.")
    }

    @Test func titles() {
        let kinds: [ScheduleStep.Kind] = [.action(.mixSourdough), .rest(.sourdough, .room), .action(.knead),
                                          .rest(.bulk, .warm), .action(.shape), .rest(.proof, .fridge),
                                          .action(.preheat), .action(.bake), .cooling]
        #expect(kinds.map { ScheduleText.title($0, vessel: .pot) } == [
            "Sauerteig ansetzen", "Sauerteig reift", "Hauptteig kneten", "Stockgare", "Teig formen",
            "Stückgare", "Ofen vorheizen", "Backen", "Auskühlen"])
        #expect(ScheduleText.title(.action(.shape), vessel: .loafPan) == "Teig in die Form geben")
    }

    @Test func places() {
        let temperatures = Temperatures(roomCelsius: 19.5, fridgeCelsius: 4)
        #expect(Place.allCases.map { $0.germanName(temperatures) }
                == ["Warm (27 °C)", "Raumtemperatur (19,5 °C)", "Kühl (16 °C)", "Kühlschrank (4 °C)"])
    }

    @Test func theTemperatureANeededPlaceWouldHave() {
        #expect(ScheduleText.needed(hours: 2, celsius: 19.38) == "Für 2 Std. 0 Min. wären etwa 19 °C nötig.")
        #expect(ScheduleText.needed(hours: 0.25, celsius: 38.3) == "Für 15 Min. wären etwa 38 °C nötig.")
    }

    @Test func rangesAndConflicts() {
        #expect(ScheduleText.range(1.05...2.25) == "1 Std. 3 Min. bis 2 Std. 15 Min.")
        // 0.7 × 1.5 is 1.0499… in floating point; still 63 minutes.
        #expect(ScheduleText.range((0.7 * 1.5)...2.25) == "1 Std. 3 Min. bis 2 Std. 15 Min.")
        #expect(ScheduleText.duration(hours: 9.7095) == "9 Std. 43 Min.")
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot, temperatures: Temperatures(),
                                choices: [.sourdough: RestChoice(place: .room, hours: 10)], calendar: utc)
        // 10 h before 16:20 is 06:20, the mixing 06:10.
        let late = schedule.steps[0]
        #expect(ScheduleText.conflict(late, vessel: .pot, window: InteractionWindow(), calendar: utc)
                == "Sauerteig ansetzen um Sa 06:10 liegt außerhalb von 8 bis 21 Uhr.")
    }
}
