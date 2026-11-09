import Foundation
import SourdoughKit

/// A bake for the UI tests (`-seedRun active` or `-seedRun finished`): a
/// Roggenmischbrot 50 with the equipment and starters already saved, as the
/// planning would propose it at `now`.
enum BakeRunDemo {
    static func run(now: Date, starters: [Starter], items: [EquipmentItem],
                    calendar: Calendar = .current) -> BakeRun {
        let bread = BreadType.ryeMixedBread50
        let setup = BakeSetup.proposal(for: items, ryeShare: bread.preset.ryeShare)
        let flour = DoughAmount.flourGrams(doughGrams: DoughAmount.grams(for: setup), hydration: bread.preset.hydration)
        let temperatures = Temperatures()
        let target = Schedule.proposedTarget(after: now, ryeShare: bread.preset.ryeShare, vessel: setup.vessel,
                                             temperatures: temperatures, calendar: calendar)
        return BakeRun(startedAt: now, bread: bread, mix: bread.preset, totalGrams: flour.rounded(), limits: [:],
                       starter: starters.first { $0.flour == .rye }, setup: setup, temperatures: temperatures,
                       window: InteractionWindow(), target: target, choices: [:], timeZone: calendar.timeZone)
    }

    /// The same bake with every step done at `now`.
    static func finished(now: Date, starters: [Starter], items: [EquipmentItem],
                         calendar: Calendar = .current) -> BakeRun {
        var bake = run(now: now, starters: starters, items: items, calendar: calendar)
        while let step = bake.current {
            // A decision takes its first answer that goes on.
            if let answer = BakeProcess.answers(step, setup: bake.setup).first(where: { !$0.waits }) {
                bake.answer(answer, at: now)
            } else {
                bake.complete(at: now)
            }
        }
        return bake
    }
}
