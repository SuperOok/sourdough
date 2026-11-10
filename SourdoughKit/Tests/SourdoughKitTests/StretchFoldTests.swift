import Testing
@testable import SourdoughKit

/// Expected values are worked out by hand from the timing: a side takes
/// 0.8 + 1.2 + 1.2 + 0.8 = 4.0 s (grab until 0.8, stretch until 2.0, fold
/// until 3.2, turn until 4.0), a round of four sides 16 s. The hand runs
/// from (−1.2, 1.0) to the shoulder (−0.95, 0.3) (grab), up to (−0.8, 1.4)
/// (stretch), on the arc via (0, 1.8) to (0.55, 0.65) (fold) and lifts off
/// to (0.75, 1.3) (turn). The strand's control point is
/// (root.x + 0.5 dx, root.y + 0.55 dy + 0.2 |dx|) with the root at the
/// shoulder.
struct StretchFoldTests {
    typealias Point = StretchFold.Point

    private func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }
    private func near(_ a: Point, _ b: Point) -> Bool { near(a.x, b.x) && near(a.y, b.y) }

    @Test func theTimingAddsUp() {
        #expect(near(StretchFold.sideSeconds, 4.0))
        #expect(near(StretchFold.roundSeconds, 16.0))
        // Half way through the first fold: 0.8 + 1.2 + 0.6.
        #expect(near(StretchFold.stillSeconds, 2.6))
        #expect(StretchFold.Stage.allCases.map(\.rawValue) == [1, 2, 3, 4])
    }

    @Test func smoothStartsAndEndsSlowly() {
        #expect(StretchFold.smooth(0) == 0)
        #expect(StretchFold.smooth(1) == 1)
        #expect(near(StretchFold.smooth(0.5), 0.5))
        // 3 × 0.25² − 2 × 0.25³ = 0.1875 − 0.03125
        #expect(near(StretchFold.smooth(0.25), 0.15625))
    }

    @Test func theCurveRunsFromStartToEndAndIsStraightViaTheMiddle() {
        let a = Point(0, 0), b = Point(4, 2)
        #expect(near(StretchFold.between(a, b), Point(2, 1)))
        #expect(near(StretchFold.along(a, Point(0, 4), b, at: 0), a))
        #expect(near(StretchFold.along(a, Point(0, 4), b, at: 1), b))
        // t = 0.5: 0.25 × (0, 0) + 0.5 × (0, 4) + 0.25 × (4, 2) = (1, 2.5)
        #expect(near(StretchFold.along(a, Point(0, 4), b, at: 0.5), Point(1, 2.5)))
        // Via the middle, t = 0.25 is a quarter of the way: (1, 0.5)
        #expect(near(StretchFold.along(a, StretchFold.between(a, b), b, at: 0.25), Point(1, 0.5)))
    }

    @Test func theHandComesDownToTheShoulder() {
        let start = StretchFold(at: 0)
        #expect(start.side == 0 && start.stage == .grab && start.progress == 0)
        #expect(near(start.hand, Point(-1.2, 1.0)) && start.handOpacity == 1)
        #expect(start.flapOpacity == 0 && start.turns == 0 && start.arrowOpacity == 0)
        // The strand ends at the hand even while hidden.
        #expect(near(start.flapEnd, Point(-1.2, 1.0)))
        // Half way through the grab (0.4 / 0.8, eased 0.5): the middle of
        // (−1.2, 1.0) and (−0.95, 0.3).
        let half = StretchFold(at: 0.4)
        #expect(half.stage == .grab && near(half.progress, 0.5) && near(half.hand, Point(-1.075, 0.65)))
    }

    @Test func theHandPullsTheShoulderUpIntoAStrand() {
        // (1.4 − 0.8) / 1.2 = 0.5 of the stretch, eased 0.5: the middle of
        // (−0.95, 0.3) and (−0.8, 1.4).
        let stretch = StretchFold(at: 1.4)
        #expect(stretch.stage == .stretch && near(stretch.progress, 0.5))
        #expect(near(stretch.hand, Point(-0.875, 0.85)) && stretch.flapOpacity == 1 && stretch.handOpacity == 1)
        #expect(near(stretch.flapEnd, stretch.hand))
        // dx = 0.075, dy = 0.55: (−0.95 + 0.0375, 0.3 + 0.3025 + 0.015)
        #expect(near(stretch.flapControl, Point(-0.9125, 0.6175)))
        #expect(stretch.arrowOpacity == 0)
    }

    @Test func theHandCarriesTheStrandOverTheDough() {
        // (2.6 − 2.0) / 1.2 = 0.5 of the fold, eased 0.5, on the arc:
        // 0.25 × (−0.8, 1.4) + 0.5 × (0, 1.8) + 0.25 × (0.55, 0.65)
        // = (−0.2 + 0.1375, 0.35 + 0.9 + 0.1625)
        let fold = StretchFold(at: 2.6)
        #expect(fold.stage == .fold && near(fold.progress, 0.5))
        #expect(near(fold.hand, Point(-0.0625, 1.4125)) && fold.flapOpacity == 1 && fold.turns == 0)
        #expect(near(fold.flapEnd, fold.hand))
        // dx = 0.8875, dy = 1.1125: (−0.95 + 0.44375, 0.3 + 0.611875 + 0.1775)
        #expect(near(fold.flapControl, Point(-0.50625, 1.089375)))
        // This is the still picture.
        #expect(fold == StretchFold(at: StretchFold.stillSeconds))
    }

    @Test func theHandLetsGoAndTheBowlTurnsAQuarterWhileTheStrandMerges() {
        // Just into the turn, (3.3 − 3.2) / 0.8 = 0.125, eased
        // 3 × 0.125² − 2 × 0.125³ = 0.04296875: the hand barely off
        // (0.55, 0.65) towards (0.75, 1.3), the arrow at 4 × 0.125 × 0.875.
        // (3.2 itself is not tested: 0.8 + 1.2 + 1.2 rounds to a hair above
        // 3.2 in floating point, so it still counts as the end of the fold.)
        let start = StretchFold(at: 3.3)
        #expect(start.stage == .turn && near(start.progress, 0.125))
        #expect(near(start.hand, Point(0.55859375, 0.6779296875)))
        #expect(near(start.handOpacity, 0.875) && near(start.flapOpacity, 0.95703125))
        #expect(near(start.turns, 0.04296875) && near(start.arrowOpacity, 0.4375))
        // The strand stays where it was laid down, from the shoulder to
        // (0.55, 0.65): dx = 1.5, dy = 0.35, control
        // (−0.95 + 0.75, 0.3 + 0.1925 + 0.3).
        #expect(near(start.flapEnd, Point(0.55, 0.65)) && near(start.flapControl, Point(-0.2, 0.7925)))
        // (3.6 − 3.2) / 0.8 = 0.5 of the turn: the hand half way up to
        // (0.75, 1.3) and half faded, the arrow at 4 × 0.5 × 0.5.
        let half = StretchFold(at: 3.6)
        #expect(half.stage == .turn && half.side == 0 && near(half.progress, 0.5))
        #expect(near(half.hand, Point(0.65, 0.975)) && near(half.handOpacity, 0.5))
        #expect(near(half.flapEnd, Point(0.55, 0.65)) && near(half.flapOpacity, 0.5))
        #expect(near(half.turns, 0.5) && near(half.arrowOpacity, 1))
        // A quarter in (3.4 s): eased 0.15625, the arrow at 4 × 0.25 × 0.75,
        // the hand at (0.55 + 0.2 × 0.15625, 0.65 + 0.65 × 0.15625).
        let quarter = StretchFold(at: 3.4)
        #expect(near(quarter.handOpacity, 0.75) && near(quarter.flapOpacity, 0.84375))
        #expect(near(quarter.turns, 0.15625) && near(quarter.arrowOpacity, 0.75))
        #expect(near(quarter.hand, Point(0.58125, 0.7515625)))
    }

    @Test func theNextSideStartsAfterAQuarterTurn() {
        let next = StretchFold(at: 4.0)
        #expect(next.side == 1 && next.stage == .grab && near(next.turns, 1))
        // Side 3, half way through its turn (12 + 3.6): 3 + 0.5 quarter turns.
        let last = StretchFold(at: 15.6)
        #expect(last.side == 3 && last.stage == .turn && near(last.turns, 3.5))
    }

    @Test func theRoundStartsAgainAndNegativeTimeCountsFromTheEnd() {
        #expect(StretchFold(at: 16) == StretchFold(at: 0))
        #expect(StretchFold(at: 16.4) == StretchFold(at: 0.4))
        // −12 s is 4 s into the round: the second side.
        #expect(StretchFold(at: -12) == StretchFold(at: 4))
    }
}
