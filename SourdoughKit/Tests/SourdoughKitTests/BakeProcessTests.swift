import Foundation
import Testing
@testable import SourdoughKit

// Expected values are worked out by hand, never taken from a program run.

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func nov(_ day: Int, _ hour: Int, _ minute: Double = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))! + minute * 60
}

private let lidPan = EquipmentItem(kind: .pan, name: "Guss", hasLid: true)
private let openPan = EquipmentItem(kind: .pan, name: "Blech")
private let basket = EquipmentItem(kind: .basket, name: "Körbchen")
private let panWithLid = BakeSetup(vessel: .loafPan, pan: lidPan)
private let panWithoutLid = BakeSetup(vessel: .loafPan, pan: openPan)
private let potAndBasket = BakeSetup(vessel: .pot, basket: basket)
private let trayAndBowl = BakeSetup(vessel: .tray)

struct BakeProcessTextTests {
    @Test func everyTextHasAFileWithATitleAndContent() {
        for text in BakeProcess.Text.allCases {
            let blocks = TipsParser.parse(BakeProcess.markdown(text))
            guard case .title = blocks.first else {
                Issue.record("\(text) beginnt nicht mit einer #-Überschrift.")
                continue
            }
            #expect(blocks.count > 1, "\(text) hat keinen Inhalt.")
        }
    }

    @Test func everyPlaceholderIsKnown() {
        let known = Set(BakeProcess.Placeholder.allCases.map(\.rawValue))
        for text in BakeProcess.Text.allCases {
            for name in BakeProcess.placeholders(in: BakeProcess.markdown(text)) {
                #expect(known.contains(name), "\(text): {\(name)} ist unbekannt.")
            }
        }
    }

    @Test func titlesComeFromTheFirstHeading() {
        #expect(BakeProcess.title(.checkStarter) == "Ist dein Starter aktiv?")
        #expect(BakeProcess.title(.bakePanOpen) == "Backen ohne Deckel, mit Dampf")
        #expect(BakeProcess.title(ofMarkdown: "Nur Text.", fallback: "cool") == "cool")
    }

    @Test func placeholdersAreFoundAndFilled() {
        let markdown = "Mit {starter} und {salt}, nicht {unbekannt}. {offen"
        #expect(BakeProcess.placeholders(in: markdown) == ["starter", "salt", "unbekannt"])
        #expect(BakeProcess.fill(markdown, [.starter: "Opa", .salt: "9 g"])
                == "Mit Opa und 9 g, nicht {unbekannt}. {offen")
    }
}

struct BakeProcessTests {
    @Test func stepsInTheirOrder() {
        #expect(BakeProcess.StepID.allCases == [.checkStarter, .mixSourdough, .checkSourdough, .knead, .shape,
                                               .checkProof, .preheat, .bake, .cool])
    }

    @Test func decisionsAndTheirAnswers() {
        #expect(BakeProcess.answers(.checkStarter, setup: trayAndBowl) == [.yes, .notYet])
        #expect(BakeProcess.answers(.checkSourdough, setup: trayAndBowl) == [.yes, .notYet])
        #expect(BakeProcess.answers(.checkProof, setup: panWithLid) == [.belowRim, .overRim])
        #expect(BakeProcess.answers(.checkProof, setup: panWithoutLid) == [.yes, .notYet])
        #expect(BakeProcess.answers(.checkProof, setup: potAndBasket) == [.yes, .notYet])
        for step in [BakeProcess.StepID.mixSourdough, .knead, .shape, .preheat, .bake, .cool] {
            #expect(BakeProcess.answers(step, setup: panWithLid).isEmpty)
        }
        #expect(BakeProcess.Answer.allCases.filter(\.waits) == [.notYet])
    }

    @Test func plainStepsHaveTheirOwnText() {
        #expect(BakeProcess.text(.checkStarter, setup: trayAndBowl, ryeShare: 0, answers: [:]) == .checkStarter)
        #expect(BakeProcess.text(.mixSourdough, setup: trayAndBowl, ryeShare: 0, answers: [:]) == .mixSourdough)
        #expect(BakeProcess.text(.checkSourdough, setup: trayAndBowl, ryeShare: 0, answers: [:]) == .checkSourdough)
        #expect(BakeProcess.text(.cool, setup: trayAndBowl, ryeShare: 0, answers: [:]) == .cool)
    }

    @Test func fromFiftyPercentRyeThereIsNoFolding() {
        #expect(BakeProcess.text(.knead, setup: trayAndBowl, ryeShare: 49.9, answers: [:]) == .kneadFold)
        #expect(BakeProcess.text(.knead, setup: trayAndBowl, ryeShare: 50, answers: [:]) == .kneadRye)
    }

    @Test func shapingFollowsTheVessel() {
        #expect(BakeProcess.text(.shape, setup: panWithLid, ryeShare: 0, answers: [:]) == .shapePan)
        #expect(BakeProcess.text(.shape, setup: potAndBasket, ryeShare: 0, answers: [:]) == .shapeBasket)
        #expect(BakeProcess.text(.shape, setup: trayAndBowl, ryeShare: 0, answers: [:]) == .shapeBowl)
        #expect(BakeProcess.text(.shape, setup: BakeSetup(vessel: .tray, basket: basket), ryeShare: 0,
                                 answers: [:]) == .shapeBasket)
    }

    @Test func theProofCheckAsksAboutTheRimOnlyWithALid() {
        #expect(BakeProcess.text(.checkProof, setup: panWithLid, ryeShare: 0, answers: [:]) == .checkProofRim)
        #expect(BakeProcess.text(.checkProof, setup: panWithoutLid, ryeShare: 0, answers: [:]) == .checkProofRipe)
        #expect(BakeProcess.text(.checkProof, setup: trayAndBowl, ryeShare: 0, answers: [:]) == .checkProofRipe)
    }

    @Test func preheatingFollowsTheVessel() {
        #expect(BakeProcess.text(.preheat, setup: panWithLid, ryeShare: 0, answers: [:]) == .preheatPan)
        #expect(BakeProcess.text(.preheat, setup: potAndBasket, ryeShare: 0, answers: [:]) == .preheatPot)
        #expect(BakeProcess.text(.preheat, setup: trayAndBowl, ryeShare: 0, answers: [:]) == .preheatTray)
    }

    @Test func aDoughOverTheRimBakesWithoutTheLid() {
        #expect(BakeProcess.text(.bake, setup: panWithLid, ryeShare: 0, answers: [.checkProof: .belowRim])
                == .bakePanLid)
        #expect(BakeProcess.text(.bake, setup: panWithLid, ryeShare: 0, answers: [:]) == .bakePanLid)
        #expect(BakeProcess.text(.bake, setup: panWithLid, ryeShare: 0, answers: [.checkProof: .overRim])
                == .bakePanOpen)
        #expect(BakeProcess.text(.bake, setup: panWithoutLid, ryeShare: 0, answers: [:]) == .bakePanOpen)
        #expect(BakeProcess.text(.bake, setup: potAndBasket, ryeShare: 0, answers: [:]) == .bakePot)
        #expect(BakeProcess.text(.bake, setup: trayAndBowl, ryeShare: 0, answers: [:]) == .bakeTray)
    }

    @Test func onlyDecisionsHaveSomethingToDoWhileWaiting() {
        #expect(BakeProcess.StepID.allCases.map(BakeProcess.waitText) == [
            .waitStarter, nil, .waitSourdough, nil, nil, .waitProof, nil, nil, nil])
    }

    @Test func stepsAreDueAtTheirActionsAndRestsFollowThem() {
        #expect(BakeProcess.StepID.allCases.map(BakeProcess.plannedAction) == [
            .mixSourdough, .mixSourdough, .knead, .knead, .shape, .preheat, .preheat, .bake, nil])
        #expect(BakeProcess.StepID.allCases.map(BakeProcess.followingRest) == [
            nil, .sourdough, nil, .bulk, .proof, nil, nil, nil, nil])
        // The schedule of the first ScheduleTests case: mixed 08:10, kneaded
        // 16:20, shaped 18:25, preheated 19:25, baked 20:10, cooling from 21:00.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot,
                                temperatures: Temperatures(), calendar: utc)
        #expect(BakeProcess.StepID.allCases.map { BakeProcess.plannedTime($0, in: schedule) } == [
            nov(14, 8, 10), nov(14, 8, 10), nov(14, 16, 20), nov(14, 16, 20), nov(14, 18, 25),
            nov(14, 19, 25), nov(14, 19, 25), nov(14, 20, 10), nov(14, 21)])
    }

    @Test func theDiagramHasEveryTextAndTheBranches() {
        let diagram = BakeProcess.mermaid()
        #expect(diagram.hasPrefix("flowchart TD\n"))
        for text in BakeProcess.Text.allCases {
            #expect(diagram.contains("    \(text.rawValue)"), "\(text) fehlt im Diagramm.")
        }
        #expect(diagram.contains("    checkStarter{\"Ist dein Starter aktiv?\"}"))
        #expect(diagram.contains("    kneadRye[\"Hauptteig mischen\"]"))
        #expect(diagram.contains("    checkProofRim -->|overRim| preheatPan"))
        #expect(diagram.contains("    checkProofRim -->|belowRim| preheatPan"))
        // Which bake follows the preheating depends on the rim.
        #expect(diagram.contains("    preheatPan -->|overRim| bakePanOpen"))
        #expect(diagram.contains("    preheatPan -->|belowRim| bakePanLid"))
        // A pan without a lid always bakes open.
        #expect(diagram.contains("    preheatPan --> bakePanOpen"))
        #expect(diagram.contains("    checkSourdough -->|notYet| waitSourdough"))
        #expect(diagram.contains("    waitSourdough --> checkSourdough"))
        // The rim cannot be answered "not yet".
        #expect(!diagram.contains("    checkProofRim -->|notYet|"))
        #expect(diagram.contains("    checkProofRipe -->|notYet| waitProof"))
        // Each edge once.
        let edges = diagram.split(separator: "\n").filter { $0.contains("-->") }
        #expect(Set(edges).count == edges.count)
    }

    @Test func theDiagramInTheDocsIsUpToDate() throws {
        // docs/ablauf.md holds the diagram; regenerate it from `mermaid()`
        // when the process changes.
        let docs = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("docs/ablauf.md")
        let content = try String(contentsOf: docs, encoding: .utf8)
        #expect(content.contains("```mermaid\n" + BakeProcess.mermaid() + "```"))
    }
}

struct BakeRunTests {
    private func run(_ setup: BakeSetup = panWithLid) -> BakeRun {
        BakeRun(startedAt: nov(13, 9), bread: .ryeMixedBread50, mix: BreadType.ryeMixedBread50.preset,
                totalGrams: 825, limits: [.spelt1050: 235],
                starter: Starter(name: "Opa", flour: .rye, createdAt: nov(1, 8)),
                setup: setup, temperatures: Temperatures(), window: InteractionWindow(), target: nov(15, 12),
                choices: [:], timeZone: TimeZone(identifier: "UTC")!)
    }

    @Test func theScheduleAndRecipeComeFromThePlan() {
        let bake = run(potAndBasket)
        #expect(bake.calendar.timeZone == TimeZone(identifier: "UTC")!)
        #expect(bake.schedule == Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot,
                                          temperatures: Temperatures(), calendar: utc))
        #expect(bake.recipe == Recipe(mix: BreadType.ryeMixedBread50.preset, totalGrams: 825, starterFlour: .rye))
        #expect(bake.status == .active)
        #expect(bake.endedAt == nil)
    }

    @Test func aDecisionIsAnsweredNotCompleted() {
        var bake = run()
        #expect(bake.current == .checkStarter)
        bake.complete(at: nov(14, 8))
        #expect(bake.current == .checkStarter)
        bake.answer(.overRim, at: nov(14, 8))
        #expect(bake.current == .checkStarter)
        bake.answer(.notYet, at: nov(14, 8))
        #expect(bake.isWaiting)
        #expect(bake.current == .checkStarter)
        bake.answer(.yes, at: nov(14, 9))
        #expect(!bake.isWaiting)
        #expect(bake.done[.checkStarter] == nov(14, 9))
        #expect(bake.current == .mixSourdough)
        bake.answer(.yes, at: nov(14, 9))
        #expect(bake.current == .mixSourdough)
    }

    @Test func theAnswerOverTheRimChangesTheBake() {
        var bake = run()
        #expect(bake.text(.bake) == .bakePanLid)
        bake.answer(.yes, at: nov(14, 8))
        for step in [BakeProcess.StepID.mixSourdough, .checkSourdough, .knead, .shape] {
            if step == .checkSourdough { bake.answer(.yes, at: nov(14, 9)) } else { bake.complete(at: nov(14, 9)) }
        }
        #expect(bake.current == .checkProof)
        bake.answer(.overRim, at: nov(14, 19))
        #expect(bake.text(.bake) == .bakePanOpen)
        #expect(bake.answers[.checkProof] == .overRim)
    }

    @Test func theLastStepFinishesTheBake() {
        var bake = run(potAndBasket)
        for step in BakeProcess.StepID.allCases {
            if BakeProcess.answers(step, setup: potAndBasket).isEmpty {
                bake.complete(at: nov(15, 12))
            } else {
                bake.answer(.yes, at: nov(15, 12))
            }
        }
        #expect(bake.current == nil)
        #expect(bake.status == .finished)
        #expect(bake.endedAt == nov(15, 12))
        #expect(bake.done.count == 9)
        bake.complete(at: nov(16, 12))
        bake.cancel(at: nov(16, 12))
        #expect(bake.status == .finished)
        #expect(bake.endedAt == nov(15, 12))
    }

    @Test func aCancelledBakeTakesNoMoreSteps() {
        var bake = run()
        bake.cancel(at: nov(14, 10))
        #expect(bake.status == .cancelled)
        #expect(bake.endedAt == nov(14, 10))
        bake.answer(.yes, at: nov(14, 11))
        bake.cancel(at: nov(14, 12))
        #expect(bake.done.isEmpty)
        #expect(bake.endedAt == nov(14, 10))
    }

    @Test func survivesAJSONRoundTrip() throws {
        var bake = run()
        bake.answer(.yes, at: nov(14, 8))
        let data = try JSONEncoder().encode(bake)
        #expect(try JSONDecoder().decode(BakeRun.self, from: data) == bake)
    }
}
