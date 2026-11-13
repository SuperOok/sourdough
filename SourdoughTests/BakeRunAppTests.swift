import Foundation
import Testing
import SourdoughKit
@testable import Sourdough

// Expected values are worked out by hand, never taken from a program run.

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// November 2026, UTC; the 13th is a Friday.
private func nov(_ day: Int, _ hour: Int, _ minute: Double = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))! + minute * 60
}

private let rye = Starter(name: "Roggensauerteig", flour: .rye, createdAt: nov(1, 8))

/// The demo bake: Roggenmischbrot 50 in the Römertopf (oval 30 × 20 cm:
/// 823 g dough, 448 g flour), proofed in the Gärkörbchen, kneaded by the
/// Thermomix, planned on Friday 09:00 for Saturday 18:00.
private func demo() -> BakeRun {
    BakeRunDemo.run(now: nov(13, 9), starters: [rye], items: EquipmentDemo.items(), calendar: utc)
}

struct BakeRunDemoTests {
    @Test func theDemoIsTheProposalForTheDemoEquipment() {
        let bake = demo()
        #expect(bake.bread == .ryeMixedBread50)
        #expect(bake.totalGrams == 448)
        #expect(bake.setup.vessel == .pot)
        #expect(bake.setup.pot?.name == "Römertopf")
        #expect(bake.setup.basket?.name == "Gärkörbchen")
        #expect(bake.setup.kneader?.name == "Thermomix")
        #expect(bake.starter == rye)
        #expect(bake.target == nov(14, 18))
        #expect(bake.status == .active)
    }

    @Test func theFinishedDemoHasEveryStepDone() {
        let bake = BakeRunDemo.finished(now: nov(13, 9), starters: [], items: [], calendar: utc)
        #expect(bake.status == .finished)
        #expect(bake.done.count == BakeProcess.StepID.allCases.count)
        #expect(bake.starter == nil)
        #expect(bake.setup.vessel == .tray)
    }

    @Test func aPanWithALidIsFinishedBelowTheRim() {
        let pan = EquipmentItem(kind: .pan, name: "Guss", hasLid: true)
        let bake = BakeRunDemo.finished(now: nov(13, 9), starters: [], items: [pan], calendar: utc)
        #expect(bake.answers[.checkProof] == .belowRim)
        #expect(bake.status == .finished)
    }
}

struct BakeRunTextTests {
    @Test func theSourdoughStageNamesAmountsTemperatureAndTime() {
        // 448 g, rye 224 g, 35 % soured: 78.4 g rye whole grain, as much water,
        // starter 15.7 g. The sourdough ripens at the cool place (16 °C) for
        // 8 × 3^0.6 = 15.465 h = 15 h 28 min, until Saturday 08:04.
        let values = BakeRunText.values(for: demo(), step: .mixSourdough)
        #expect(values[.starter] == "„Roggensauerteig“")
        #expect(values[.sourdoughFlour] == "78 g Roggenvollkorn")
        #expect(values[.sourdoughWater] == "78 g")
        #expect(values[.starterGrams] == "16 g")
        #expect(values[.restTemperature] == "bei etwa 16 °C")
        #expect(values[.restDuration] == "15 Std. 28 Min.")
        #expect(values[.restUntil] == "Sa 08:04")
    }

    @Test func theMainDoughNamesTheRestAndWarmWater() {
        // Main dough: rye 1150 112 g, rye whole grain 112 − 78.4 = 33.6 g,
        // spelt 1050 134.4 g, spelt whole grain 89.6 g; water 448 × 0.816 −
        // 78.4 = 287.2 g; salt 8.96 g. The bulk rest is warm (27 °C), 1.75 h ×
        // 3^−0.5 = 60.6 min, until 09:25; water 2 × 27 − 22 = 32 °C.
        let values = BakeRunText.values(for: demo(), step: .knead)
        #expect(values[.mainFlour] == "112 g Roggen 1150, 34 g Roggenvollkorn, 134 g Dinkel 1050, 90 g Dinkelvollkorn")
        #expect(values[.mainWater] == "287 g")
        #expect(values[.salt] == "9 g")
        #expect(values[.kneading] == "mit „Thermomix“")
        #expect(values[.waterCelsius] == "32 °C")
        #expect(values[.restTemperature] == "bei etwa 27 °C")
        #expect(values[.restDuration] == "1 Std. 1 Min.")
        #expect(values[.restUntil] == "Sa 09:25")
    }

    @Test func vesselsByName() {
        let values = BakeRunText.values(for: demo(), step: .shape)
        #expect(values[.vessel] == "„Römertopf“")
        #expect(values[.proofVessel] == "das Gärkörbchen „Gärkörbchen“")
        // Cooling ends at the target.
        #expect(BakeRunText.values(for: demo(), step: .cool)[.restUntil] == "Sa 18:00")
    }

    @Test func withoutAnythingChosenTheTextsStillRead() {
        let bake = BakeRun(startedAt: nov(13, 9), bread: .speltBread, mix: BreadType.speltBread.preset,
                           totalGrams: 500, limits: [:], starter: nil, setup: BakeSetup(vessel: .tray),
                           temperatures: Temperatures(), window: InteractionWindow(), time: nov(15, 12),
                           choices: [.bulk: RestChoice(place: .room, hours: 3)], timeZone: utc.timeZone)
        let values = BakeRunText.values(for: bake, step: .knead)
        #expect(values[.starter] == "deinen Starter")
        #expect(values[.kneading] == "von Hand")
        #expect(values[.vessel] == "das Blech")
        #expect(values[.proofVessel] == "eine Schüssel")
        // A bulk rest at room temperature: water 2 × 26 − 22 = 30 °C.
        #expect(values[.waterCelsius] == "30 °C")
        // The starter stands where an accusative fits, with or without a name.
        #expect(BakeRunText.markdown(bake, .mixSourdough).contains("Anstellgut – nimm dafür deinen Starter"))
    }

    @Test func markdownTitlesAndWaiting() {
        let bake = demo()
        #expect(BakeRunText.markdown(bake, .mixSourdough).contains("- 78 g Roggenvollkorn"))
        #expect(BakeRunText.markdown(bake, .mixSourdough).contains("16 g Anstellgut – nimm dafür „Roggensauerteig“"))
        #expect(!BakeRunText.markdown(bake, .knead).contains("{"))
        #expect(BakeRunText.waitMarkdown(bake, .checkStarter)?.contains("Füttere „Roggensauerteig“") == true)
        #expect(BakeRunText.waitMarkdown(bake, .knead) == nil)
        // 50 % rye: mixed, not kneaded and folded.
        #expect(BakeRunText.title(bake, .knead) == "Hauptteig mischen")
        #expect(BakeRunText.undoLabel(bake, .mixSourdough) == "Zurück zu „Sauerteigstufe ansetzen“")
    }

    @Test func answersTemperaturesPortionsAndStatus() {
        #expect(BakeProcess.Answer.allCases.map(BakeRunText.answer)
                == ["Ja", "Noch nicht", "Unter dem Rand", "Am Deckel oder darüber"])
        // Whole degrees, half a degree rounds up; no place.
        #expect([19.38, 19.5, 2.946, 27, -0.3].map(BakeRunText.restTemperature)
                == ["bei etwa 19 °C", "bei etwa 20 °C", "bei etwa 3 °C", "bei etwa 27 °C", "bei etwa 0 °C"])
        #expect(BakeRunText.portions([], separator: ", ") == "")
        #expect([BakeRun.Status.active, .finished, .cancelled].map(BakeRunText.status)
                == ["läuft", "fertig", "abgebrochen"])
    }
}

struct BakeRunAddInTextTests {
    /// 500 g Weizen 550 with seeds, nuts and dried fruit 10 % each (50 g)
    /// and herbs 2 % (10 g); seeds soak in 50 g water, the fruit in 25 g.
    private let recipe = Recipe(mix: FlourMix([.wheat550: 100]), totalGrams: 500, starterFlour: .wheat,
                                addIns: AddIns([.seeds: 10, .nuts: 10, .driedFruit: 10, .herbs: 2]))
    private let plain = Recipe(mix: FlourMix([.wheat550: 100]), totalGrams: 500, starterFlour: .wheat)

    @Test func seedsAndFruitSoakWithTheSourdough() {
        #expect(BakeRunText.soaker(recipe) == """
            Weiche gleichzeitig in einer zweiten Schüssel ein und decke sie ab:

            - 50 g Saaten in 50 g Wasser
            - 50 g Trockenfrüchte in 25 g Wasser
            """)
        #expect(BakeRunText.soaker(plain) == "")
    }

    @Test func seedsGoInFirstTheRestAtTheEnd() {
        #expect(BakeRunText.addIns(recipe) == "Gib gleich 50 g Saaten (eingeweicht) mit dazu. "
                + "Arbeite am Ende des Knetens 50 g Nüsse, 50 g Trockenfrüchte (eingeweicht) und 10 g Kräuter "
                + "kurz unter.")
        let onlyNuts = Recipe(mix: FlourMix([.wheat550: 100]), totalGrams: 500, starterFlour: .wheat,
                              addIns: AddIns([.nuts: 10]))
        #expect(BakeRunText.addIns(onlyNuts) == "Arbeite am Ende des Knetens 50 g Nüsse kurz unter.")
        let onlySeeds = Recipe(mix: FlourMix([.wheat550: 100]), totalGrams: 500, starterFlour: .wheat,
                               addIns: AddIns([.seeds: 10]))
        #expect(BakeRunText.addIns(onlySeeds) == "Gib gleich 50 g Saaten (eingeweicht) mit dazu.")
        #expect(BakeRunText.addIns(plain) == "")
    }

    @Test func listsJoinWithUnd() {
        #expect(BakeRunText.list([]) == "")
        #expect(BakeRunText.list(["a"]) == "a")
        #expect(BakeRunText.list(["a", "b"]) == "a und b")
        #expect(BakeRunText.list(["a", "b", "c"]) == "a, b und c")
    }

    @Test func theLogNamesTheAddIns() {
        #expect(BakeLogText.addIns(recipe) == "50 g Saaten, 50 g Nüsse, 50 g Trockenfrüchte, 10 g Kräuter")
        #expect(BakeLogText.addIns(plain) == "keine")
    }

    @Test func withoutAddInsNoPlaceholderIsLeft() {
        #expect(!BakeRunText.markdown(demo(), .mixSourdough).contains("{"))
    }
}

struct BakeLogTextTests {
    @Test func starterAndEquipment() {
        #expect(BakeLogText.starter(rye) == "Roggensauerteig (Roggen)")
        #expect(BakeLogText.starter(nil) == "keiner")
        #expect(BakeLogText.equipment(demo().setup) == "Römertopf, Gärkörbchen, Thermomix")
        #expect(BakeLogText.equipment(BakeSetup(vessel: .tray)) == "Blech, Schüssel, von Hand")
        #expect(BakeLogText.equipment(BakeSetup(vessel: .loafPan, pan: EquipmentItem(kind: .pan, name: "Guss")))
                == "Guss, von Hand")
    }

    @Test func temperaturesAndTimes() {
        #expect(BakeLogText.temperatures(Temperatures(roomCelsius: 19.5, fridgeCelsius: 4))
                == "Raum 19,5 °C, Kühlschrank 4 °C")
        var bake = demo()
        // The sourdough rests until 08:04:23 on Saturday, 15 h 27 min 56 s: it
        // starts at 16:36:27 on Friday and is mixed 10 min before, at 16:26.
        #expect(BakeLogText.times(bake, .checkStarter) == "geplant Fr 16:26")
        bake.answer(.yes, at: nov(13, 21))
        #expect(BakeLogText.times(bake, .checkStarter) == "geplant Fr 16:26 · erledigt Fr 21:00 · Ja")
    }

    @Test func stepsARestFollowsNameItsTemperature() {
        // Sourdough at the cool place (16 °C), bulk warm (27 °C, kneading
        // 08:04), proof at room temperature (22 °C, shaping 09:25).
        let bake = demo()
        #expect(BakeLogText.times(bake, .mixSourdough) == "geplant Fr 16:26 · Ruhe bei etwa 16 °C")
        #expect(BakeLogText.times(bake, .knead) == "geplant Sa 08:04 · Ruhe bei etwa 27 °C")
        #expect(BakeLogText.times(bake, .shape) == "geplant Sa 09:25 · Ruhe bei etwa 22 °C")
    }
}

struct BakeRunStoreTests {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("BakeRunStoreTests-\(UUID().uuidString)")
    }

    @Test func startsEmpty() {
        let store = BakeRunStore(directory: makeDirectory())
        #expect(store.runs.isEmpty)
        #expect(store.active == nil)
        #expect(store.startSubtitle == "Noch kein Durchgang")
        #expect(BakeRunStore.defaultDirectory.lastPathComponent == "bakes")
    }

    @Test func onlyOneBakeRunsAtATime() {
        let store = BakeRunStore(directory: makeDirectory())
        let first = demo()
        store.start(first)
        store.start(demo())
        #expect(store.runs.map(\.id) == [first.id])
        #expect(store.active?.id == first.id)
        #expect(store.run(first.id) == first)
        #expect(store.run(UUID()) == nil)
    }

    @Test func progressIsSavedAndReadBack() {
        let directory = makeDirectory()
        let store = BakeRunStore(directory: directory)
        let bake = demo()
        store.start(bake)
        store.answer(bake.id, .yes, at: nov(13, 21))
        store.complete(bake.id, at: nov(13, 21, 5))
        store.complete(UUID(), at: nov(13, 22))
        let reopened = BakeRunStore(directory: directory).run(bake.id)
        #expect(reopened?.done[.checkStarter] == nov(13, 21))
        #expect(reopened?.done[.mixSourdough] == nov(13, 21, 5))
        #expect(reopened?.current == .checkSourdough)
    }

    @Test func aCancelledBakeMakesRoomForTheNext() {
        let directory = makeDirectory()
        let store = BakeRunStore(directory: directory)
        let first = BakeRunDemo.run(now: nov(13, 9), starters: [], items: [], calendar: utc)
        store.start(first)
        store.cancel(first.id, at: nov(13, 10))
        #expect(store.active == nil)
        #expect(store.startSubtitle == "1 Durchgang")
        let second = BakeRunDemo.run(now: nov(14, 9), starters: [], items: [], calendar: utc)
        store.start(second)
        #expect(store.startSubtitle == "1 Durchgang")
        store.cancel(second.id, at: nov(14, 10))
        #expect(store.startSubtitle == "2 Durchgänge")
        // Newest first, also when read back.
        #expect(BakeRunStore(directory: directory).runs.map(\.id) == [second.id, first.id])
    }

    @Test func aStepIsUndoneAndSaved() {
        let directory = makeDirectory()
        let store = BakeRunStore(directory: directory)
        let bake = demo()
        store.start(bake)
        store.answer(bake.id, .yes, at: nov(13, 21))
        store.complete(bake.id, at: nov(13, 21))
        store.undo(bake.id)
        #expect(BakeRunStore(directory: directory).run(bake.id)?.current == .mixSourdough)
    }

    @Test func aFinishedBakeRunsAgainOnlyWhileNoOtherDoes() {
        let store = BakeRunStore(directory: makeDirectory())
        let finished = BakeRunDemo.finished(now: nov(13, 9), starters: [], items: [], calendar: utc)
        store.start(finished)
        let next = BakeRunDemo.run(now: nov(14, 9), starters: [], items: [], calendar: utc)
        store.start(next)
        store.undo(finished.id)
        #expect(store.run(finished.id)?.status == .finished)
        store.cancel(next.id, at: nov(14, 10))
        store.undo(finished.id)
        #expect(store.run(finished.id)?.status == .active)
        #expect(store.active?.id == finished.id)
    }

    @Test func removingAndResetting() {
        let directory = makeDirectory()
        let store = BakeRunStore(directory: directory)
        let bake = demo()
        store.start(bake)
        store.remove(bake.id)
        #expect(BakeRunStore(directory: directory).runs.isEmpty)
        store.start(demo())
        store.reset()
        #expect(store.runs.isEmpty)
        #expect(BakeRunStore(directory: directory).runs.isEmpty)
    }

    @Test func unreadableFilesAreLeftOut() throws {
        let directory = makeDirectory()
        let store = BakeRunStore(directory: directory)
        store.start(demo())
        try Data("kaputt".utf8).write(to: directory.appendingPathComponent("kaputt.json"))
        #expect(BakeRunStore(directory: directory).runs.count == 1)
    }
}

struct BakePlanRunTests {
    @Test func aBakeStartsOnlyFromACompletePlan() {
        let model = BakePlanModel()
        #expect(model.makeRun(starters: [rye], now: nov(13, 9), calendar: utc) == nil)
        model.proposeSetup(from: EquipmentDemo.items())
        model.useTemperatures(Temperatures())
        #expect(model.makeRun(starters: [rye], now: nov(13, 9), calendar: utc) == nil)
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        model.starterID = rye.id
        let bake = model.makeRun(starters: [rye], now: nov(13, 9), calendar: utc)
        #expect(bake?.startedAt == nov(13, 9))
        #expect(bake?.bread == .ryeMixedBread50)
        #expect(bake?.totalGrams == 448)
        #expect(bake?.starter == rye)
        #expect(bake?.target == nov(14, 18))
        #expect(bake?.setup == model.setup)
        #expect(bake?.timeZone == utc.timeZone)
        #expect(bake?.anchor == .ready)
    }

    @Test func aBakePlannedForwardsKeepsItsStart() {
        // Switched to the start, the plan keeps its rests and its target,
        // Saturday 18:00; the bake starts where the plan does and aims for the
        // same temperatures. On whole minutes the sourdough takes 928 min
        // instead of 8 × 3^0.6 h = 927.93 min at 16 °C: 22 − 10 × log₃(928 /
        // 60 / 8) = 15.9993 °C, still 16 °C in whole degrees.
        let model = BakePlanModel()
        model.proposeSetup(from: EquipmentDemo.items())
        model.useTemperatures(Temperatures())
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        model.starterID = rye.id
        model.setAnchor(.start, calendar: utc)
        let bake = model.makeRun(starters: [rye], now: nov(13, 9), calendar: utc)
        #expect(bake?.anchor == .start)
        #expect(bake?.schedule.start == model.anchorTime)
        #expect(bake.map { abs($0.target.timeIntervalSince(nov(14, 18))) < 0.001 } == true)
        let sourdough = 22 - 10 * log(928.0 / 60 / 8) / log(3)
        #expect(bake.map { abs($0.celsius(.sourdough) - sourdough) < 1e-9 } == true)
        #expect(bake.map { BakeRunText.restTemperature($0.celsius(.sourdough)) } == "bei etwa 16 °C")
        #expect(bake?.choices == model.choices)
    }

    @Test func theBakeTakesTheAddIns() {
        // The Römertopf takes 823.04 g dough; herbs 3 % add 0.03 per gram of
        // flour: 823.04 / (1.836 + 0.03) = 441.07 g flour.
        let model = BakePlanModel()
        model.addIns.add(.herbs)
        model.proposeSetup(from: EquipmentDemo.items())
        model.useTemperatures(Temperatures())
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        model.starterID = rye.id
        let bake = model.makeRun(starters: [rye], now: nov(13, 9), calendar: utc)
        #expect(bake?.totalGrams == 441)
        #expect(bake?.addIns == AddIns([.herbs: 3]))
    }

    @Test func noBakeWithIssuesOrWrongTemperatures() {
        let wheat = Starter(name: "W", flour: .wheat, createdAt: nov(1, 8))
        let model = BakePlanModel()
        model.proposeSetup(from: EquipmentDemo.items())
        model.useTemperatures(Temperatures())
        model.proposeTarget(now: nov(13, 9), calendar: utc)
        model.starterID = wheat.id
        #expect(model.makeRun(starters: [wheat], now: nov(13, 9), calendar: utc) == nil)
        model.starterID = nil
        model.roomText = "5"
        #expect(model.makeRun(starters: [wheat], now: nov(13, 9), calendar: utc) == nil)
        model.roomText = "22"
        model.totalText = "0"
        #expect(model.makeRun(starters: [wheat], now: nov(13, 9), calendar: utc) == nil)
    }
}
