import SwiftUI
import SourdoughKit

/// A tips-page animation: the picture of `TipsAnimation`, with its caption.
struct TipsAnimationView: View {
    let animation: TipsAnimation
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch animation {
            case .stretchFold: StretchFoldView()
            }
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityIdentifier("tips-animation-\(animation.rawValue)")
    }
}

/// A bowl seen from the front and a little from above, the dough a mound in
/// it: a hand comes from above, grips the dough's left shoulder, pulls it up
/// into a strand, lays the strand over the dough past the centre, lets go,
/// and the bowl turns a quarter turn, four times round. A label names the
/// stage and the side. All timing is in `StretchFold`; this only draws, and
/// without branches, so every line runs on every frame. With "Reduce Motion"
/// the picture stands still at `StretchFold.stillSeconds`.
struct StretchFoldView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let seconds = reduceMotion ? StretchFold.stillSeconds : timeline.date.timeIntervalSinceReferenceDate
                Self.draw(StretchFold(at: seconds), in: &context, size: size)
            }
        }
        .frame(height: 290)
        .frame(maxWidth: .infinity)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    /// The German names of the stages, by their number.
    static let stageNames: [StretchFold.Stage: String] = [
        .grab: "Greifen", .stretch: "Dehnen", .fold: "Falten", .turn: "Drehen",
    ]

    // Fixed colours: dough and skin look the same in the dark; everything
    // else takes its colour from the system so it reads in both modes.
    private static let dough = Color(red: 0.93, green: 0.82, blue: 0.62)
    private static let strand = Color(red: 0.97, green: 0.89, blue: 0.72)
    private static let speckle = Color(red: 0.78, green: 0.63, blue: 0.40)
    private static let skin = Color(red: 0.90, green: 0.69, blue: 0.56)
    private static let outline = Color.primary.opacity(0.45)

    /// Half the bowl's width and depth, and half the depth of its rim seen
    /// from a little above, in dough radii.
    private static let bowlHalfWidth = 1.45
    private static let bowlDepth = 1.0
    private static let rimDepth = 0.38

    static func draw(_ frame: StretchFold, in context: inout GraphicsContext, size: CGSize) {
        // The labels take the top left; below them the picture spans from
        // the hand's highest point (about 1.7 radii above the rim) to the
        // bowl's base, one radius below it.
        let labelBand = 46.0
        let unit = min((size.height - labelBand - 10) / 2.75, size.width / 3.4)
        let rim = CGPoint(x: size.width / 2, y: size.height - 8 - bowlDepth * unit)
        func at(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rim.x + x * unit, y: rim.y - y * unit) }
        func at(_ point: StretchFold.Point) -> CGPoint { at(point.x, point.y) }
        func disc(_ middle: CGPoint, radius: Double) -> Path {
            Path(ellipseIn: CGRect(x: middle.x - radius * unit, y: middle.y - radius * unit,
                                   width: 2 * radius * unit, height: 2 * radius * unit))
        }
        /// A point on the rim, `angle` radians round from the front; the
        /// front of the rim is the lowest point of its ellipse.
        func onRim(_ angle: Double, halfWidth: Double = bowlHalfWidth, depth: Double = rimDepth) -> CGPoint {
            at(halfWidth * sin(angle), -depth * cos(angle))
        }

        // The labels: the stage, and the side below it. The hand comes from
        // the upper right and never covers them.
        let stage = Text("\(frame.stage.rawValue) \(stageNames[frame.stage, default: ""])")
            .font(.callout.weight(.semibold))
        context.draw(stage, at: CGPoint(x: 12, y: 10), anchor: .topLeading)
        let side = Text("Seite \(frame.side + 1) von \(StretchFold.sides)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        context.draw(side, at: CGPoint(x: 12, y: 30), anchor: .topLeading)

        // The bowl: its body with the inside of the rim, drawn behind the
        // dough; the front wall comes after the dough and hides its base.
        // The grey is translucent, so each part is painted on the system
        // background first to be opaque.
        let rimRect = CGRect(x: rim.x - bowlHalfWidth * unit, y: rim.y - rimDepth * unit,
                             width: 2 * bowlHalfWidth * unit, height: 2 * rimDepth * unit)
        /// The bowl's sides and base, closed by half of its rim: the back
        /// half for the whole body, the front half for the front wall.
        func walls(closedByBack: Bool) -> Path {
            var path = Path()
            path.move(to: at(-bowlHalfWidth, 0))
            path.addCurve(to: at(-0.8, -bowlDepth), control1: at(-bowlHalfWidth, -0.7), control2: at(-1.1, -bowlDepth))
            path.addLine(to: at(0.8, -bowlDepth))
            path.addCurve(to: at(bowlHalfWidth, 0), control1: at(1.1, -bowlDepth), control2: at(bowlHalfWidth, -0.7))
            path.addArc(center: rim, radius: 1, startAngle: .zero, endAngle: .degrees(180), clockwise: closedByBack,
                        transform: CGAffineTransform(translationX: rim.x, y: rim.y)
                            .scaledBy(x: bowlHalfWidth * unit, y: rimDepth * unit)
                            .translatedBy(x: -rim.x, y: -rim.y))
            path.closeSubpath()
            return path
        }
        let body = walls(closedByBack: true)
        context.fill(body, with: .style(.background))
        context.fill(body, with: .color(.gray.opacity(0.35)))
        context.fill(Path(ellipseIn: rimRect), with: .color(.gray.opacity(0.5)))
        context.stroke(Path(ellipseIn: rimRect), with: .color(outline), lineWidth: 1.5)

        // The dough: a mound with a few specks on top that turn with the bowl.
        let quarter = frame.turns * Double.pi / 2
        let mound = Path(ellipseIn: CGRect(x: rim.x - unit, y: rim.y - 0.57 * unit,
                                           width: 2 * unit, height: 0.9 * unit))
        context.fill(mound, with: .color(dough))
        context.stroke(mound, with: .color(speckle), lineWidth: 1.5)
        for (radius, angle) in [(0.55, 0.4), (0.7, 2.0), (0.3, 3.4), (0.62, 4.6), (0.75, 5.6)] {
            let speck = at(radius * sin(angle + quarter), 0.2 - 0.3 * radius * cos(angle + quarter))
            context.fill(disc(speck, radius: 0.05), with: .color(speckle))
        }

        // The strand: a band from the dough's shoulder to the hand, wide
        // where it leaves the dough and thinner towards the hand.
        // Fading is done per colour, not with a context of its own opacity:
        // one less layer, and the strand is a single shape anyway.
        let band = Self.band(from: at(StretchFold.handAtEdge), via: at(frame.flapControl), to: at(frame.flapEnd),
                             width: 0.5 * unit, to: 0.22 * unit)
        context.fill(band, with: .color(strand.opacity(frame.flapOpacity)))
        context.stroke(band, with: .color(speckle.opacity(frame.flapOpacity)), lineWidth: 1.5)

        // The front wall of the bowl, with the marks on its rim that show it
        // turning: one per side, each visible while it is on the front.
        let front = walls(closedByBack: false)
        context.fill(front, with: .style(.background))
        context.fill(front, with: .color(.gray.opacity(0.4)))
        context.stroke(front, with: .color(outline), lineWidth: 1.5)
        for mark in 0..<StretchFold.sides {
            let angle = quarter + Double(mark) * Double.pi / 2
            let middle = onRim(angle, depth: rimDepth + 0.12)
            let stripe = Path(roundedRect: CGRect(x: middle.x - 0.06 * unit, y: middle.y - 0.15 * unit,
                                                  width: 0.12 * unit, height: 0.3 * unit),
                              cornerRadius: 0.06 * unit)
            context.fill(stripe, with: .color(outline.opacity(max(0, cos(angle)))))
        }

        // The arrow round the front of the bowl, just outside its rim, while
        // it turns.
        var arrow = Path()
        let arrowStart = -0.9, arrowEnd = 0.9
        let arrowWidth = bowlHalfWidth + 0.22, arrowDepth = rimDepth + 0.3
        arrow.move(to: onRim(arrowStart, halfWidth: arrowWidth, depth: arrowDepth))
        for step in 1...12 {
            let angle = arrowStart + (arrowEnd - arrowStart) * Double(step) / 12
            arrow.addLine(to: onRim(angle, halfWidth: arrowWidth, depth: arrowDepth))
        }
        let tip = onRim(arrowEnd, halfWidth: arrowWidth, depth: arrowDepth)
        let before = onRim(arrowEnd - 0.1, halfWidth: arrowWidth, depth: arrowDepth)
        let heading = atan2(tip.y - before.y, tip.x - before.x)
        for wing in [heading + 2.6, heading - 2.6] {
            arrow.move(to: tip)
            arrow.addLine(to: CGPoint(x: tip.x + 0.3 * unit * cos(wing), y: tip.y + 0.3 * unit * sin(wing)))
        }
        context.stroke(arrow, with: .color(.accentColor.opacity(frame.arrowOpacity)),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

        // The hand: a forearm from above the picture, a palm, four fingers
        // reaching down to the grip and a thumb across.
        let skin = Self.skin.opacity(frame.handOpacity), handOutline = outline.opacity(frame.handOpacity)
        let grip = at(frame.hand)
        let palm = CGPoint(x: grip.x + 0.08 * unit, y: grip.y - 0.42 * unit)
        var arm = Path()
        arm.move(to: at(frame.hand.x + 1.6, 3.2))
        arm.addLine(to: palm)
        context.stroke(arm, with: .color(handOutline), style: StrokeStyle(lineWidth: 0.36 * unit + 3, lineCap: .round))
        context.stroke(arm, with: .color(skin), style: StrokeStyle(lineWidth: 0.36 * unit, lineCap: .round))
        let palmPath = Path(ellipseIn: CGRect(x: palm.x - 0.27 * unit, y: palm.y - 0.22 * unit,
                                              width: 0.54 * unit, height: 0.46 * unit))
        var fingers = Path()
        for finger in 0..<4 {
            let spread = Double(finger) - 1.5
            fingers.move(to: CGPoint(x: palm.x + spread * 0.12 * unit, y: palm.y + 0.12 * unit))
            fingers.addLine(to: CGPoint(x: grip.x + spread * 0.08 * unit, y: grip.y + 0.02 * unit))
        }
        var thumb = Path()
        thumb.move(to: CGPoint(x: palm.x - 0.22 * unit, y: palm.y + 0.02 * unit))
        thumb.addLine(to: CGPoint(x: grip.x - 0.24 * unit, y: grip.y - 0.06 * unit))
        for path in [fingers, thumb] {
            context.stroke(path, with: .color(handOutline), style: StrokeStyle(lineWidth: 0.1 * unit + 3, lineCap: .round))
        }
        context.fill(palmPath, with: .color(skin))
        context.stroke(palmPath, with: .color(handOutline), lineWidth: 1.5)
        for path in [fingers, thumb] {
            context.stroke(path, with: .color(skin), style: StrokeStyle(lineWidth: 0.1 * unit, lineCap: .round))
        }
    }

    /// A band along the quadratic curve from `a` via `c` to `b`, `width`
    /// wide at `a` and `end` wide at `b`, as a closed path.
    static func band(from a: CGPoint, via c: CGPoint, to b: CGPoint, width: Double, to end: Double) -> Path {
        let steps = 16
        var left: [CGPoint] = [], right: [CGPoint] = []
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let wa = (1 - t) * (1 - t), wc = 2 * (1 - t) * t, wb = t * t
            let point = CGPoint(x: wa * a.x + wc * c.x + wb * b.x, y: wa * a.y + wc * c.y + wb * b.y)
            let tangent = CGPoint(x: 2 * (1 - t) * (c.x - a.x) + 2 * t * (b.x - c.x),
                                  y: 2 * (1 - t) * (c.y - a.y) + 2 * t * (b.y - c.y))
            // A degenerate curve (all points alike) has no direction; any
            // normal does, the band is invisible then anyway.
            let length = max(hypot(tangent.x, tangent.y), 1e-6)
            let half = (width + (end - width) * t) / 2
            let normal = CGPoint(x: -tangent.y / length * half, y: tangent.x / length * half)
            left.append(CGPoint(x: point.x + normal.x, y: point.y + normal.y))
            right.append(CGPoint(x: point.x - normal.x, y: point.y - normal.y))
        }
        var path = Path()
        path.move(to: left[0])
        for point in left.dropFirst() { path.addLine(to: point) }
        for point in right.reversed() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}

#Preview {
    TipsAnimationView(animation: .stretchFold,
                      caption: "Dehnen und Falten: Teig an einer Seite greifen, hochziehen, zur Mitte falten, "
                      + "Schüssel eine Vierteldrehung drehen")
        .padding()
}
