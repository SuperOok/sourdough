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
    @Test func bothKneadingStepsLinkToTheKneadingPage() {
        for text in [BakeProcess.Text.kneadFold, .kneadRye] {
            #expect(BakeProcess.markdown(text).contains("[Kneten](tip:kneading)"))
        }
    }

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
        #expect(BakeProcess.StepID.allCases == [.checkStarter, .mixSourdough, .checkSourdough, .knead, .fold,
                                               .shape, .checkProof, .preheat, .bake, .cool])
    }

    @Test func decisionsAndTheirAnswers() {
        #expect(BakeProcess.answers(.checkStarter, in: .init(setup: trayAndBowl)) == [.yes, .notYet])
        #expect(BakeProcess.answers(.checkSourdough, in: .init(setup: trayAndBowl)) == [.yes, .notYet])
        #expect(BakeProcess.answers(.checkProof, in: .init(setup: panWithLid)) == [.belowRim, .overRim])
        #expect(BakeProcess.answers(.checkProof, in: .init(setup: panWithoutLid)) == [.yes, .notYet])
        #expect(BakeProcess.answers(.checkProof, in: .init(setup: potAndBasket)) == [.yes, .notYet])
        for step in [BakeProcess.StepID.mixSourdough, .knead, .fold, .shape, .preheat, .bake, .cool] {
            #expect(BakeProcess.answers(step, in: .init(setup: panWithLid)).isEmpty)
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
        #expect(BakeProcess.text(.shape, setup: potAndBasket, ryeShare: 0, answers: [:]) == .shapeBasketRound)
        #expect(BakeProcess.text(.shape, setup: trayAndBowl, ryeShare: 0, answers: [:]) == .shapeBowl)
        #expect(BakeProcess.text(.shape, setup: BakeSetup(vessel: .tray, basket: basket), ryeShare: 0,
                                 answers: [:]) == .shapeBasketRound)
        // An oval or rectangular banneton takes a long loaf.
        for shape in [Dimensions.Shape.oval, .rectangular] {
            let long = EquipmentItem(kind: .basket, name: "Lang", shape: shape)
            #expect(BakeProcess.text(.shape, setup: BakeSetup(vessel: .pot, basket: long), ryeShare: 0,
                                     answers: [:]) == .shapeBasketLong)
        }
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

    @Test func aPotWithoutALidBakesOpenWithSteam() {
        let closed = BakeSetup(vessel: .pot, pot: EquipmentItem(kind: .pot, name: "", hasLid: true), basket: basket)
        let open = BakeSetup(vessel: .pot, pot: EquipmentItem(kind: .pot, name: "", hasLid: false), basket: basket)
        #expect(BakeProcess.text(.preheat, setup: closed, ryeShare: 0, answers: [:]) == .preheatPot)
        #expect(BakeProcess.text(.bake, setup: closed, ryeShare: 0, answers: [:]) == .bakePot)
        #expect(BakeProcess.text(.preheat, setup: open, ryeShare: 0, answers: [:]) == .preheatPotOpen)
        #expect(BakeProcess.text(.bake, setup: open, ryeShare: 0, answers: [:]) == .bakePotOpen)
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
        #expect(BakeProcess.StepID.allCases.map { BakeProcess.waitText($0, in: .init(setup: trayAndBowl)) } == [
            .waitStarter, nil, .waitSourdough, nil, nil, nil, .waitProof, nil, nil, nil])
        // The rim cannot be answered "not yet", so there is nothing to wait for.
        #expect(BakeProcess.waitText(.checkProof, in: .init(setup: panWithLid)) == nil)
    }

    @Test func theStoredNamesOfStepsAndAnswersStay() {
        // Files of bakes hold these raw values; renaming one would lose them.
        #expect(BakeProcess.StepID.allCases.map(\.rawValue) == [
            "checkStarter", "mixSourdough", "checkSourdough", "knead", "fold", "shape", "checkProof", "preheat",
            "bake", "cool"])
        #expect(BakeProcess.Answer.allCases.map(\.rawValue) == ["yes", "notYet", "belowRim", "overRim"])
        #expect(BakeProcess.Answer.allCases.map(\.label) == ["Ja", "Noch nicht", "Unter dem Rand",
                                                            "Am Deckel oder darüber"])
    }

    @Test func theDefinitionHasEveryStepOnceInItsOrder() {
        #expect(BakeProcess.steps.map(\.id) == BakeProcess.StepID.allCases)
        #expect(BakeProcess.step(.preheat).timing == .action(.preheat, overlapsRest: true))
        #expect(BakeProcess.step(.checkProof).timing == .beforeNextAction)
        #expect(BakeProcess.step(.cool).timing == .cooling)
        #expect(BakeProcess.step(.fold).timing == .withinRest(.bulk))
        #expect(BakeProcess.step(.fold).skippedWhen == .ryeShareAtLeast(50))
        #expect(BakeProcess.step(.knead).skippedWhen == nil)
    }

    @Test func foldingOffersTheMachineOnlyWithAHook() {
        let hook = BakeSetup(vessel: .tray, kneader: EquipmentItem(kind: .kneader, name: "Bosch"))
        let blade = BakeSetup(vessel: .tray, kneader: EquipmentItem(kind: .kneader, name: "TM", kneadingTool: .blade))
        #expect(BakeProcess.text(.fold, setup: hook, ryeShare: 0, answers: [:]) == .foldHook)
        #expect(BakeProcess.text(.fold, setup: blade, ryeShare: 0, answers: [:]) == .foldBlade)
        #expect(BakeProcess.text(.fold, setup: trayAndBowl, ryeShare: 0, answers: [:]) == .fold)
        #expect(BakeProcess.markdown(.foldHook).contains("niedrigsten Stufe"))
        #expect(!BakeProcess.markdown(.foldBlade).contains("niedrigsten Stufe"))
        #expect(!BakeProcess.markdown(.fold).contains("Maschine"))
        // Each its own title, so that the branches of the diagram differ.
        #expect([BakeProcess.Text.fold, .foldHook, .foldBlade].map(BakeProcess.title)
                == ["Dehnen und Falten", "Dehnen und Falten oder kurz kneten", "Dehnen und Falten von Hand"])
        for text in [BakeProcess.Text.fold, .foldHook, .foldBlade] {
            #expect(BakeProcess.markdown(text).contains("{afterFold}"))
        }
        #expect(BakeProcess.markdown(.kneadFold).contains("{folding}"))
    }

    @Test func theScheduleTakesItsActionsAndRestsFromTheDefinition() {
        // Decisions are left out; preheating runs during the end of the proof.
        #expect(BakeProcess.timeline == [
            .action(.mixSourdough, overlapsRest: false), .rest(.sourdough),
            .action(.knead, overlapsRest: false), .folding(.bulk), .rest(.bulk),
            .action(.shape, overlapsRest: false), .rest(.proof),
            .action(.preheat, overlapsRest: true), .action(.bake, overlapsRest: false), .cooling])
        let layout = Schedule.layout
        #expect(layout.rests == [.sourdough, .bulk, .proof])
        #expect(layout.foldingRest == .bulk)
        #expect(layout.blocks == [Schedule.Block(following: [.mixSourdough]), Schedule.Block(following: [.knead]),
                                  Schedule.Block(following: [.shape]),
                                  Schedule.Block(overlapping: [.preheat], following: [.bake])])
    }

    @Test func conditionsHaveGermanLabels() {
        let labels: [(BakeProcess.Condition, String)] = [
            (.ryeShareAtLeast(50), "Roggen ab 50 %"),
            (.ryeShareAtLeast(49.5), "Roggen ab 49,5 %"),
            (.vessel(.loafPan), "Kastenform"),
            (.vessel(.pot), "Bräter"),
            (.vessel(.tray), "Blech"),
            (.panWithLid, "Kastenform mit Deckel"),
            (.potWithLid, "Bräter mit Deckel"),
            (.potWithoutLid, "Bräter ohne Deckel"),
            (.basket(long: true), "längliches Gärkörbchen"),
            (.basket(long: false), "rundes Gärkörbchen"),
            (.kneadingTool(.hook), "Küchenmaschine mit Knethaken"),
            (.kneadingTool(.blade), "Küchenmaschine mit Messer"),
            (.answer(.checkProof, .overRim), "Antwort „Am Deckel oder darüber“"),
            (.all([.panWithLid, .answer(.checkProof, .belowRim)]), "Kastenform mit Deckel und Antwort „Unter dem Rand“"),
        ]
        for (condition, label) in labels {
            #expect(condition.label == label)
        }
        #expect(BakeProcess.Condition.all([.panWithLid, .all([.vessel(.pot)])]).atoms == [.panWithLid, .vessel(.pot)])
    }

    @Test func conditionsAreEvaluatedAgainstSetupDoughAndAnswers() {
        let tray = BakeProcess.Context(setup: trayAndBowl)
        #expect(BakeProcess.Condition.vessel(.tray).holds(in: tray))
        #expect(!BakeProcess.Condition.vessel(.pot).holds(in: tray))
        #expect(BakeProcess.Condition.ryeShareAtLeast(50).holds(in: .init(setup: trayAndBowl, ryeShare: 50)))
        #expect(!BakeProcess.Condition.ryeShareAtLeast(50).holds(in: .init(setup: trayAndBowl, ryeShare: 49.9)))
        // A pot not known to have no lid has one; a pan only with a lid saved.
        #expect(BakeProcess.Condition.potWithLid.holds(in: .init(setup: potAndBasket)))
        #expect(!BakeProcess.Condition.potWithoutLid.holds(in: .init(setup: potAndBasket)))
        #expect(!BakeProcess.Condition.potWithLid.holds(in: tray))
        #expect(!BakeProcess.Condition.panWithLid.holds(in: .init(setup: panWithoutLid)))
        #expect(!BakeProcess.Condition.basket(long: false).holds(in: tray))
        #expect(BakeProcess.Condition.basket(long: false).holds(in: .init(setup: potAndBasket)))
        // The tool of the kneading machine; by hand there is none.
        let hook = BakeSetup(vessel: .tray, kneader: EquipmentItem(kind: .kneader, name: "Bosch"))
        let blade = BakeSetup(vessel: .tray, kneader: EquipmentItem(kind: .kneader, name: "TM", kneadingTool: .blade))
        #expect(BakeProcess.Condition.kneadingTool(.hook).holds(in: .init(setup: hook)))
        #expect(!BakeProcess.Condition.kneadingTool(.blade).holds(in: .init(setup: hook)))
        #expect(BakeProcess.Condition.kneadingTool(.blade).holds(in: .init(setup: blade)))
        #expect(!BakeProcess.Condition.kneadingTool(.hook).holds(in: tray))
        #expect(!BakeProcess.Condition.kneadingTool(.blade).holds(in: tray))
        let overRim = BakeProcess.Context(setup: panWithLid, answers: [.checkProof: .overRim])
        #expect(BakeProcess.Condition.all([.panWithLid, .answer(.checkProof, .overRim)]).holds(in: overRim))
        #expect(!BakeProcess.Condition.all([.vessel(.pot), .answer(.checkProof, .overRim)]).holds(in: overRim))
    }

    @Test func stepsAreDueAtTheirActionsAndRestsFollowThem() {
        #expect(BakeProcess.StepID.allCases.map(BakeProcess.plannedAction) == [
            .mixSourdough, .mixSourdough, .knead, .knead, .fold, .shape, .preheat, .preheat, .bake, nil])
        // Kneading is followed by the bulk rest, past the folds within it.
        #expect(BakeProcess.StepID.allCases.map(BakeProcess.followingRest) == [
            nil, .sourdough, nil, .bulk, .bulk, .proof, nil, nil, nil, nil])
        // The schedule of the first ScheduleTests case: mixed 08:10, kneaded
        // 16:20, shaped 18:25, preheated 19:25, baked 20:10, cooling from 21:00.
        // Without folds, folding is due when the bulk rest starts: 16:20 + 20 min.
        let schedule = Schedule(target: nov(15, 12), ryeShare: 50, vessel: .pot,
                                temperatures: Temperatures(), calendar: utc)
        #expect(BakeProcess.StepID.allCases.map { BakeProcess.plannedTime($0, in: schedule) } == [
            nov(14, 8, 10), nov(14, 8, 10), nov(14, 16, 20), nov(14, 16, 20), nov(14, 16, 40), nov(14, 18, 25),
            nov(14, 19, 25), nov(14, 19, 25), nov(14, 20, 10), nov(14, 21)])
    }

    @Test func theDiagramIsAPlantUMLActivityDiagram() {
        let diagram = BakeProcess.plantUML()
        #expect(diagram.hasPrefix("@startuml\n"))
        #expect(diagram.hasSuffix("\nstop\n@enduml\n"))
        #expect(diagram.contains("\nstart\n"))
        for text in BakeProcess.Text.allCases {
            #expect(diagram.contains(BakeProcess.title(text)), "\(text) fehlt im Diagramm.")
        }
        for rest in ["Sauerteig reift", "Stockgare", "Stückgare"] {
            #expect(diagram.contains("\n:Ruhe: \(rest); <<#E8E8E8>>\n"))
        }
    }

    @Test func aDecisionThatCanWaitLoopsBackThroughWhatToDoMeanwhile() {
        #expect(BakeProcess.plantUML().contains("""
            repeat
              :Ist dein Starter aktiv?;
            backward :Erst auffrischen;
            repeat while () is (Noch nicht) not (Ja)
            """))
    }

    @Test func everyBranchOfTheDiagramCarriesItsCondition() {
        let diagram = BakeProcess.plantUML()
        #expect(diagram.contains("""
            switch ()
            case (Roggen ab 50 %)
              :Hauptteig mischen;
            case (sonst)
              :Hauptteig kneten;
            endswitch
            """))
        // The answers about the rim branch right at their decision ...
        #expect(diagram.contains("""
            case (Kastenform mit Deckel)
              :Wie hoch ist der Teig?;
              if () then (Unter dem Rand)
              else (Am Deckel oder darüber)
              endif
            case (sonst)
              repeat
            """))
        // ... and the bake that depends on them names the answer in its condition.
        #expect(diagram.contains("""
            case (Kastenform mit Deckel und Antwort „Am Deckel oder darüber“)
              :Backen ohne Deckel, mit Dampf;
            case (Kastenform mit Deckel)
              :Backen mit Deckel;
            """))
        // Preheating runs while the proof ends.
        #expect(diagram.contains("""
            case (Kastenform)
              :Ofen vorheizen\\n//noch während der Ruhe davor//;
            """))
    }

    @Test func everyConditionOfTheDefinitionIsInTheDiagram() {
        let diagram = BakeProcess.plantUML()
        var used: [BakeProcess.Condition] = []
        for step in BakeProcess.steps {
            for rule in step.variants.rules {
                used += rule.condition.atoms
                #expect(diagram.contains("case (\(rule.condition.label))"), "\(rule.condition.label) fehlt.")
            }
        }
        // Worked out from the rules of shaping, the proof check, preheating,
        // baking, kneading and folding.
        #expect(Set(used.map(\.label)) == ["Roggen ab 50 %", "Kastenform", "längliches Gärkörbchen",
                                           "rundes Gärkörbchen", "Kastenform mit Deckel", "Bräter mit Deckel",
                                           "Bräter ohne Deckel", "Antwort „Am Deckel oder darüber“",
                                           "Küchenmaschine mit Knethaken", "Küchenmaschine mit Messer"])
        // A step that can be left out says when.
        #expect(diagram.contains("if (Roggen ab 50 %) then (ja)\nelse (sonst)\n  repeat\n"))
        for answer in BakeProcess.Answer.allCases {
            #expect(diagram.contains("(\(answer.label))"), "\(answer) fehlt.")
        }
    }

    @Test func everyNodeOfTheProcessCanBeReached() {
        let edges = BakeProcess.edges()
        var reached: Set<String> = ["start"]
        var queue = ["start"]
        while let node = queue.popLast() {
            for edge in edges where edge.from == node && reached.insert(edge.to).inserted {
                queue.append(edge.to)
            }
        }
        let nodes = Set(BakeProcess.Text.allCases.map(\.rawValue) + ["rest.sourdough", "rest.bulk", "rest.proof",
                                                                     "stop"])
        #expect(reached == nodes.union(["start"]))
        // Each answer that goes on leaves its decision; "not yet" loops back.
        #expect(edges.contains(.init(from: "checkProofRim", to: "preheatPan", label: "Unter dem Rand, Kastenform")))
        #expect(edges.contains(.init(from: "checkProofRim", to: "preheatPan",
                                     label: "Am Deckel oder darüber, Kastenform")))
        #expect(edges.contains(.init(from: "checkSourdough", to: "waitSourdough", label: "Noch nicht")))
        #expect(edges.contains(.init(from: "waitSourdough", to: "checkSourdough", label: nil)))
        #expect(edges.contains(.init(from: "checkSourdough", to: "kneadRye", label: "Ja, Roggen ab 50 %")))
        #expect(edges.contains(.init(from: "mixSourdough", to: "rest.sourdough", label: nil)))
        #expect(edges.contains(.init(from: "cool", to: "stop", label: nil)))
        #expect(!edges.contains { $0.from == "checkProofRim" && $0.label?.hasPrefix("Noch nicht") == true })
    }

    @Test func theDiagramInTheDocsIsUpToDate() throws {
        // docs/ablauf.puml holds the diagram. tools/diagrams.sh runs this
        // test with UPDATE_DIAGRAMS=1, which writes it from `plantUML()`,
        // and then draws the SVG.
        let docs = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("docs")
        if ProcessInfo.processInfo.environment["UPDATE_DIAGRAMS"] == "1" {
            try BakeProcess.plantUML().write(to: docs.appendingPathComponent("ablauf.puml"), atomically: true,
                                             encoding: .utf8)
        }
        let source = try String(contentsOf: docs.appendingPathComponent("ablauf.puml"), encoding: .utf8)
        #expect(source == BakeProcess.plantUML())
        let prose = try String(contentsOf: docs.appendingPathComponent("ablauf.md"), encoding: .utf8)
        #expect(prose.contains("ablauf.puml") && prose.contains("ablauf.svg"))
        #expect(!prose.contains("mermaid"))
    }
}

struct BakeRunTests {
    private func run(_ setup: BakeSetup = panWithLid) -> BakeRun {
        BakeRun(startedAt: nov(13, 9), bread: .ryeMixedBread50, mix: BreadType.ryeMixedBread50.preset,
                totalGrams: 825, limits: [.spelt1050: 235],
                starter: Starter(name: "Opa", flour: .rye, createdAt: nov(1, 8)),
                setup: setup, temperatures: Temperatures(), window: InteractionWindow(), time: nov(15, 12),
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
            if BakeProcess.answers(step, in: .init(setup: potAndBasket)).isEmpty {
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

    @Test func undoOpensTheLastDoneStepAgain() {
        var bake = run()
        #expect(bake.previous == nil)
        bake.undo()
        #expect(bake.current == .checkStarter)
        bake.answer(.yes, at: nov(14, 8))
        bake.complete(at: nov(14, 9))
        #expect(bake.current == .checkSourdough)
        #expect(bake.previous == .mixSourdough)
        // "Erledigt" on the sourdough by mistake: it is open again.
        bake.undo()
        #expect(bake.current == .mixSourdough)
        #expect(bake.done[.mixSourdough] == nil)
        #expect(bake.done[.checkStarter] == nov(14, 8))
        #expect(bake.answers[.checkStarter] == .yes)
        // Back once more: the decision forgets its answer.
        bake.undo()
        #expect(bake.current == .checkStarter)
        #expect(bake.answers.isEmpty)
        #expect(bake.done.isEmpty)
    }

    @Test func undoForgetsAWaitingAnswerAfterTheStep() {
        var bake = run()
        bake.answer(.yes, at: nov(14, 8))
        bake.complete(at: nov(14, 9))
        bake.answer(.notYet, at: nov(14, 20))
        #expect(bake.isWaiting)
        bake.undo()
        #expect(bake.current == .mixSourdough)
        #expect(bake.answers == [.checkStarter: .yes])
    }

    @Test func undoReopensAFinishedBakeButNotACancelledOne() {
        var bake = run(potAndBasket)
        for step in BakeProcess.StepID.allCases {
            if BakeProcess.answers(step, in: .init(setup: potAndBasket)).isEmpty {
                bake.complete(at: nov(15, 12))
            } else {
                bake.answer(.yes, at: nov(15, 12))
            }
        }
        #expect(bake.status == .finished)
        #expect(bake.previous == .cool)
        bake.undo()
        #expect(bake.status == .active)
        #expect(bake.endedAt == nil)
        #expect(bake.current == .cool)
        #expect(bake.done.count == 8)

        bake.cancel(at: nov(15, 13))
        #expect(bake.previous == nil)
        bake.undo()
        #expect(bake.status == .cancelled)
        #expect(bake.done.count == 8)
    }

    @Test func survivesAJSONRoundTrip() throws {
        var bake = run()
        bake.answer(.yes, at: nov(14, 8))
        let data = try JSONEncoder().encode(bake)
        #expect(try JSONDecoder().decode(BakeRun.self, from: data) == bake)
    }

    @Test func aSavedBakeNamesItsStepsAndAnswersByTheirRawValues() throws {
        // As files of version 1.1 hold them: done steps and answers as
        // alternating keys and values, the keys by raw value.
        var bake = run()
        bake.answer(.yes, at: nov(14, 8))
        let object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(bake)) as? [String: Any])
        #expect((object["done"] as? [Any])?.first as? String == "checkStarter")
        #expect((object["answers"] as? [Any])?.compactMap { $0 as? String } == ["checkStarter", "yes"])
        var edited = object
        edited["answers"] = ["checkProof", "overRim"]
        let old = try JSONDecoder().decode(BakeRun.self, from: JSONSerialization.data(withJSONObject: edited))
        #expect(old.answers == [.checkProof: .overRim])
        #expect(old.text(.bake) == .bakePanOpen)
    }

    @Test func theAddInsGoIntoTheRecipe() {
        let bake = BakeRun(startedAt: nov(13, 9), bread: .ryeMixedBread50, mix: BreadType.ryeMixedBread50.preset,
                           totalGrams: 800, limits: [:], starter: nil, setup: potAndBasket,
                           temperatures: Temperatures(), window: InteractionWindow(), time: nov(15, 12),
                           choices: [:], timeZone: TimeZone(identifier: "UTC")!, addIns: AddIns([.nuts: 10]))
        #expect(bake.addIns == AddIns([.nuts: 10]))
        // 10 % of 800 g.
        #expect(bake.recipe.addIns == [Recipe.AddInPortion(addIn: .nuts, grams: 80, waterGrams: 0)])
    }

    @Test func aBakeSavedBeforeAddInsHasNone() throws {
        let data = try JSONEncoder().encode(run())
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["addInShares"] = nil
        let old = try JSONDecoder().decode(BakeRun.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.addIns.isEmpty)
    }

    /// Roggenmischbrot 50 in the pot, room 22 °C, the proof fixed at room
    /// temperature for 1.8 h, the most its range at 22 °C allows.
    private func run(anchor: ScheduleAnchor, time: Date) -> BakeRun {
        BakeRun(startedAt: nov(13, 7), bread: .ryeMixedBread50, mix: BreadType.ryeMixedBread50.preset,
                totalGrams: 800, limits: [:], starter: nil, setup: potAndBasket, temperatures: Temperatures(),
                window: InteractionWindow(), anchor: anchor, time: time,
                choices: [.proof: RestChoice(place: .room, hours: 1.8)], timeZone: TimeZone(identifier: "UTC")!)
    }

    @Test func aBakePlannedForwardsKeepsItsStartAndKnowsItsTarget() throws {
        // From Friday 08:00: mixing to 08:10, sourdough 8 h to 16:10, kneading
        // to 16:30, bulk 1.75 h to 18:15, shaping to 18:30, proof 1.8 h to
        // 20:18, baking to 21:08 — outside the window, but fixed by the
        // choice —, cooling 6 h: ready Saturday 03:08.
        let bake = run(anchor: .start, time: nov(13, 8))
        #expect(bake.anchor == .start)
        #expect(abs(bake.target.timeIntervalSince(nov(14, 3, 8))) < 0.001)
        #expect(bake.schedule == Schedule(start: nov(13, 8), ryeShare: 50, vessel: .pot,
                                          temperatures: Temperatures(),
                                          choices: [.proof: RestChoice(place: .room, hours: 1.8)], calendar: utc))
        let decoded = try JSONDecoder().decode(BakeRun.self, from: JSONEncoder().encode(bake))
        #expect(decoded == bake)
        #expect(decoded.schedule.start == nov(13, 8))
    }

    @Test func aBakeRemembersTheTargetTemperatureOfEachRest() {
        // Backwards from Saturday 18:00 the proof is fixed at room temperature
        // for 1.8 h instead of 1.5 h: 22 − 10 × log₃(1.8 / 1.5) =
        // 22 − 10 × 0.18232 / 1.09861 = 20.340 °C.
        let bake = run(anchor: .ready, time: nov(14, 18))
        #expect(bake.anchor == .ready)
        #expect(bake.target == nov(14, 18))
        #expect(abs(bake.celsius(.proof) - 20.340) < 0.001)
    }

    @Test func aBakeSavedBeforeTargetTemperaturesTakesThoseOfItsPlaces() throws {
        let data = try JSONEncoder().encode(run(anchor: .ready, time: nov(14, 18)))
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["restCelsius"] != nil && object["scheduleAnchor"] != nil)
        object["restCelsius"] = nil
        object["scheduleAnchor"] = nil
        let old = try JSONDecoder().decode(BakeRun.self, from: JSONSerialization.data(withJSONObject: object))
        // The proof is at room temperature: 22 °C, not the 20.3 °C its time needs.
        #expect(old.celsius(.proof) == 22)
        #expect(old.anchor == .ready)
        #expect(old.target == nov(14, 18))
        // The same with the plan given. With the proof 1.8 h from 09:22,
        // shaping starts at 09:07; no place brings kneading into the window
        // (even warm at its shortest, 0.859 h, it would start 07:55), so the
        // bulk rest keeps room temperature, 22 °C. The sourdough before
        // kneading at 07:02 goes to the cool place, 16 °C.
        let schedule = old.schedule
        #expect(old.celsius(.proof, in: schedule) == 22)
        #expect(old.celsius(.sourdough, in: schedule) == 16)
        #expect(old.celsius(.bulk, in: schedule) == 22)
    }

    @Test func aRestWithoutPlaceFallsBackToTheRoom() {
        // A plan always has every rest; without a place the room counts.
        let kitchen = Temperatures(roomCelsius: 20, fridgeCelsius: 4, coolCelsius: 15)
        #expect(BakeRun.celsius(at: nil, temperatures: kitchen) == 20)
        #expect(BakeRun.celsius(at: .cool, temperatures: kitchen) == 15)
        #expect(BakeRun.celsius(at: .fridge, temperatures: kitchen) == 4)
    }

    @Test func aBakeWhoseSavedTemperaturesLackARestTakesThatOfItsPlace() throws {
        // A file with target temperatures, but none for any rest: each rest
        // falls back to its place, the proof at room temperature 22 °C. One
        // that has the value keeps it, given a plan or not (20.340 °C, above).
        let bake = run(anchor: .ready, time: nov(14, 18))
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(bake))
                                  as? [String: Any])
        object["restCelsius"] = [Any]()
        let partial = try JSONDecoder().decode(BakeRun.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(partial.celsius(.proof) == 22)
        #expect(abs(bake.celsius(.proof, in: bake.schedule) - 20.340) < 0.001)
    }

    @Test func aForwardBakeSavedBeforeItsAnchorHadStartAndTargetLoads() throws {
        // A forward bake from a file of that time has neither anchor nor
        // start: it is read as planned backwards from its target, Saturday
        // 03:08 (see `aBakePlannedForwardsKeepsItsStartAndKnowsItsTarget`).
        var object = try #require(try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(run(anchor: .start, time: nov(13, 8)))) as? [String: Any])
        #expect(object["startTime"] != nil)
        for key in ["scheduleAnchor", "startTime", "restCelsius"] { object[key] = nil }
        let old = try JSONDecoder().decode(BakeRun.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.anchor == .ready)
        #expect(abs(old.schedule.target.timeIntervalSince(nov(14, 3, 8))) < 0.001)
        #expect(old.celsius(.proof) == 22)
    }
}
