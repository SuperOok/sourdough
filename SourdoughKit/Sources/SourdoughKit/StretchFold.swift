import Foundation

/// The timing of the stretch-and-fold animation on the kneading page: a
/// pure function from time to what the picture shows, so the app only draws.
///
/// The picture is a bowl seen from the front and a little from above, the
/// dough a mound in it, and a hand that comes from above. The hand grips the
/// dough's left shoulder, pulls it up into a strand, carries the strand over
/// the dough and lays it down past the centre; then it lets go and the bowl
/// turns a quarter turn, four times round. Lengths are in dough radii: x to
/// the right from the bowl's centre, y upwards from its rim. The strand is
/// rooted at `handAtEdge` and ends at `flapEnd`, arching through
/// `flapControl`.
public struct StretchFold: Equatable, Sendable {
    /// The stages of one side, numbered as the picture labels them.
    public enum Stage: Int, CaseIterable, Sendable {
        /// The hand comes down to the dough's shoulder.
        case grab = 1
        /// The hand pulls the shoulder up into a strand.
        case stretch
        /// The hand carries the strand over the dough and lays it down.
        case fold
        /// The hand lets go and the bowl turns a quarter turn.
        case turn
    }

    /// A point in dough radii, x to the right and y upwards.
    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double

        public init(_ x: Double, _ y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// Seconds of each stage, one side after the other.
    public static let grabSeconds = 0.8
    public static let stretchSeconds = 1.2
    public static let foldSeconds = 1.2
    public static let turnSeconds = 0.8
    /// Seconds for one side.
    public static let sideSeconds = grabSeconds + stretchSeconds + foldSeconds + turnSeconds
    /// Sides of one round: stretch and fold on all four.
    public static let sides = 4
    /// Seconds for one round; the picture then starts again.
    public static let roundSeconds = sideSeconds * Double(sides)
    /// The moment the still picture shows with "Reduce Motion": half way
    /// through the first fold, the strand arching over the dough.
    public static let stillSeconds = grabSeconds + stretchSeconds + foldSeconds / 2

    /// Where the hand comes in, where it grips the dough's shoulder (the root
    /// of the strand), how high it pulls, the arc it carries the strand on,
    /// where it lays the strand down (past the centre, on top of the dough)
    /// and where it lifts off to.
    public static let handStart = Point(-1.2, 1.0)
    public static let handAtEdge = Point(-0.95, 0.3)
    public static let handStretched = Point(-0.8, 1.4)
    public static let foldArc = Point(0, 1.8)
    public static let handFolded = Point(0.55, 0.65)
    public static let handReleased = Point(0.75, 1.3)

    /// The side being worked, 0 to 3.
    public let side: Int
    public let stage: Stage
    /// How far into the stage, 0 to 1.
    public let progress: Double
    /// Where the hand grips.
    public let hand: Point
    /// 1 while the hand is on the dough, 0 once it has lifted off.
    public let handOpacity: Double
    /// Where the strand ends: at the hand until it lets go, then where the
    /// strand was laid down.
    public let flapEnd: Point
    /// The control point of the strand's arc from `handAtEdge` to `flapEnd`:
    /// half way across, a little more than half way up, and lifted a fifth
    /// of the way across, so the strand arches over the dough and lies on
    /// it once laid down.
    public let flapControl: Point
    /// 1 while the strand shows, 0 before the stretch and once it has merged
    /// with the dough during the turn.
    public let flapOpacity: Double
    /// Quarter turns of the bowl so far, growing steadily through a round.
    public let turns: Double
    /// The arrow that shows the bowl turning: up and down again during the
    /// turn, 0 otherwise.
    public let arrowOpacity: Double

    /// What the picture shows `seconds` after the start; time repeats every
    /// round and is taken modulo the round also for negative values.
    public init(at seconds: Double) {
        let round = ((seconds.truncatingRemainder(dividingBy: Self.roundSeconds)) + Self.roundSeconds)
            .truncatingRemainder(dividingBy: Self.roundSeconds)
        let sideIndex = Int(round / Self.sideSeconds)
        let t = round - Double(sideIndex) * Self.sideSeconds
        side = sideIndex
        let grabEnd = Self.grabSeconds
        let stretchEnd = grabEnd + Self.stretchSeconds
        let foldEnd = stretchEnd + Self.foldSeconds
        // The stage, how far into it, and the path of the hand: from, via, to.
        let (stage, raw, from, via, to): (Stage, Double, Point, Point, Point)
        switch t {
        case ..<grabEnd:
            (stage, raw, from, via, to) = (.grab, t / Self.grabSeconds,
                                           Self.handStart, Self.between(Self.handStart, Self.handAtEdge),
                                           Self.handAtEdge)
        case ..<stretchEnd:
            (stage, raw, from, via, to) = (.stretch, (t - grabEnd) / Self.stretchSeconds,
                                           Self.handAtEdge, Self.between(Self.handAtEdge, Self.handStretched),
                                           Self.handStretched)
        case ..<foldEnd:
            (stage, raw, from, via, to) = (.fold, (t - stretchEnd) / Self.foldSeconds,
                                           Self.handStretched, Self.foldArc, Self.handFolded)
        default:
            (stage, raw, from, via, to) = (.turn, (t - foldEnd) / Self.turnSeconds,
                                           Self.handFolded, Self.between(Self.handFolded, Self.handReleased),
                                           Self.handReleased)
        }
        self.stage = stage
        progress = raw
        let eased = Self.smooth(raw)
        hand = Self.along(from, via, to, at: eased)
        let turning = stage == .turn
        handOpacity = turning ? 1 - raw : 1
        flapEnd = turning ? Self.handFolded : hand
        let root = Self.handAtEdge
        let dx = flapEnd.x - root.x, dy = flapEnd.y - root.y
        flapControl = Point(root.x + 0.5 * dx, root.y + 0.55 * dy + 0.2 * abs(dx))
        flapOpacity = turning ? 1 - eased : (stage == .grab ? 0 : 1)
        turns = Double(sideIndex) + (turning ? eased : 0)
        arrowOpacity = turning ? 4 * raw * (1 - raw) : 0
    }

    /// Slow start and end: `3t² − 2t³`.
    public static func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }

    /// The point of the quadratic curve from `a` via `c` to `b` at `t`:
    /// `(1 − t)² a + 2 (1 − t) t c + t² b`. With `c` half way between `a`
    /// and `b` this is the straight line.
    public static func along(_ a: Point, _ c: Point, _ b: Point, at t: Double) -> Point {
        let wa = (1 - t) * (1 - t), wc = 2 * (1 - t) * t, wb = t * t
        return Point(wa * a.x + wc * c.x + wb * b.x, wa * a.y + wc * c.y + wb * b.y)
    }

    /// Half way between two points.
    public static func between(_ a: Point, _ b: Point) -> Point {
        Point((a.x + b.x) / 2, (a.y + b.y) / 2)
    }
}
