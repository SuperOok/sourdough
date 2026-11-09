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
    @Test func theSourdoughStageNamesAmountsPlaceAndTime() {
        // 448 g, rye 224 g, 35 % soured: 78.4 g rye whole grain, as much water,
        // starter 15.7 g. The sourdough ripens at room temperature from
        // Friday 21:00 to Saturday 08:04 (11 h 4 min).
        let values = BakeRunText.values(for: demo(), step: .mixSourdough)
        #expect(values[.starter] == "„Roggensauerteig“")
        #expect(values[.sourdoughFlour] == "78 g Roggenvollkorn")
        #expect(values[.sourdoughWater] == "78 g")
        #expect(values[.starterGrams] == "16 g")
        #expect(values[.restPlace] == "bei Raumtemperatur (22 °C)")
        #expect(values[.restDuration] == "11 Std. 4 Min.")
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
        #expect(values[.restPlace] == "an einem warmen Ort (27 °C)")
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
                           temperatures: Temperatures(), window: InteractionWindow(), target: nov(15, 12),
                           choices: [.bulk: RestChoice(place: .room, hours: 3)], timeZone: utc.timeZone)
        let values = BakeRunText.values(for: bake, step: .knead)
        #expect(values[.starter] == "deinen Starter")
        #expect(values[.kneading] == "von Hand")
        #expect(values[.vessel] == "das Blech")
        #expect(values[.proofVessel] == "eine Schüssel")
        // A bulk rest at room temperature: water 2 × 26 − 22 = 30 °C.
        #expect(values[.waterCelsius] == "30 °C")
    }

    @Test func markdownTitlesAndWaiting() {
        let bake = demo()
        #expect(BakeRunText.markdown(bake, .mixSourdough).contains("- 78 g Roggenvollkorn"))
        #expect(BakeRunText.markdown(bake, .mixSourdough).contains("16 g Anstellgut von „Roggensauerteig“"))
        #expect(!BakeRunText.markdown(bake, .knead).contains("{"))
        #expect(BakeRunText.waitMarkdown(bake, .checkStarter)?.contains("Füttere „Roggensauerteig“") == true)
        #expect(BakeRunText.waitMarkdown(bake, .knead) == nil)
        // 50 % rye: mixed, not kneaded and folded.
        #expect(BakeRunText.title(bake, .knead) == "Hauptteig mischen")
    }

    @Test func answersPlacesPortionsAndStatus() {
        #expect(BakeProcess.Answer.allCases.map(BakeRunText.answer)
                == ["Ja", "Noch nicht", "Unter dem Rand", "Am Deckel oder darüber"])
        let temperatures = Temperatures(roomCelsius: 20, fridgeCelsius: 4)
        #expect(Place.allCases.map { BakeRunText.placePhrase($0, temperatures) }
                == ["an einem warmen Ort (27 °C)", "bei Raumtemperatur (20 °C)", "im Kühlschrank (4 °C)"])
        #expect(BakeRunText.portions([], separator: ", ") == "")
        #expect([BakeRun.Status.active, .finished, .cancelled].map(BakeRunText.status)
                == ["läuft", "fertig", "abgebrochen"])
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
        // The sourdough is mixed at 20:50 on Friday.
        #expect(BakeLogText.times(bake, .checkStarter) == "geplant Fr 20:50")
        bake.answer(.yes, at: nov(13, 21))
        #expect(BakeLogText.times(bake, .checkStarter) == "geplant Fr 20:50 · erledigt Fr 21:00 · Ja")
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
