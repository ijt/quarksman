import SwiftUI

/// A sampled quadratic Bézier between two points, with arc-length lookup.
struct EdgeGeometry {
    let samples: [CGPoint]
    let cumulative: [CGFloat]

    var length: CGFloat { cumulative.last ?? 0 }
    var minX: CGFloat { samples.map(\.x).min() ?? 0 }
    var maxX: CGFloat { samples.map(\.x).max() ?? 0 }

    init(from a: CGPoint, to b: CGPoint, bend: CGFloat = 0, count: Int = 96) {
        let dx = b.x - a.x, dy = b.y - a.y
        let control = CGPoint(x: (a.x + b.x) / 2 - dy * bend, y: (a.y + b.y) / 2 + dx * bend)
        var pts: [CGPoint] = []
        pts.reserveCapacity(count + 1)
        for i in 0...count {
            let t = CGFloat(i) / CGFloat(count), u = 1 - t
            pts.append(CGPoint(x: u * u * a.x + 2 * u * t * control.x + t * t * b.x,
                               y: u * u * a.y + 2 * u * t * control.y + t * t * b.y))
        }
        var cum: [CGFloat] = [0]
        for i in 1..<pts.count { cum.append(cum[i - 1] + hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)) }
        samples = pts
        cumulative = cum
    }

    /// Point and unit tangent at arc length `s`.
    func locate(_ s: CGFloat) -> (point: CGPoint, tangent: CGVector) {
        let s = min(max(s, 0), length)
        var lo = 0, hi = cumulative.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if cumulative[mid] <= s { lo = mid } else { hi = mid }
        }
        let p0 = samples[lo], p1 = samples[hi]
        let seg = max(cumulative[hi] - cumulative[lo], 1e-9)
        let f = (s - cumulative[lo]) / seg
        let d = hypot(p1.x - p0.x, p1.y - p0.y)
        let tangent = d > 1e-9 ? CGVector(dx: (p1.x - p0.x) / d, dy: (p1.y - p0.y) / d) : CGVector(dx: 1, dy: 0)
        return (CGPoint(x: p0.x + (p1.x - p0.x) * f, y: p0.y + (p1.y - p0.y) * f), tangent)
    }

    func distance(to p: CGPoint) -> CGFloat {
        var best = CGFloat.infinity
        for i in 1..<samples.count {
            best = min(best, segmentDistance(p, samples[i - 1], samples[i]))
        }
        return best
    }

    private func segmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let abx = b.x - a.x, aby = b.y - a.y
        let len2 = abx * abx + aby * aby
        let t = len2 > 0 ? min(max(((p.x - a.x) * abx + (p.y - a.y) * aby) / len2, 0), 1) : 0
        return hypot(p.x - (a.x + abx * t), p.y - (a.y + aby * t))
    }
}

/// Maps a diagram's normalized coordinates into a view, preserving its aspect ratio.
struct DiagramLayout {
    let diagram: Diagram
    let frame: CGRect

    init(diagram: Diagram, size: CGSize, inset: CGFloat = 30, bottomInset: CGFloat = 44) {
        self.diagram = diagram
        let availW = max(size.width - 2 * inset, 10)
        let availH = max(size.height - inset - bottomInset, 10)
        var h = availH, w = h * diagram.aspect
        if w > availW { w = availW; h = w / diagram.aspect }
        frame = CGRect(x: (size.width - w) / 2, y: inset + (availH - h) / 2, width: w, height: h)
    }

    /// Layout in "aspect space": width = aspect, height = 1.
    init(unit diagram: Diagram) {
        self.diagram = diagram
        frame = CGRect(x: 0, y: 0, width: diagram.aspect, height: 1)
    }

    func point(_ id: String) -> CGPoint {
        let n = diagram.node(id)
        return CGPoint(x: frame.minX + n.x * frame.width, y: frame.minY + n.y * frame.height)
    }

    func geometry(_ e: Edge) -> EdgeGeometry {
        EdgeGeometry(from: point(e.from), to: point(e.to), bend: e.bend)
    }

    func hitTest(_ p: CGPoint) -> DiagramSelection? {
        for v in diagram.vertices {
            let q = point(v.id)
            if hypot(q.x - p.x, q.y - p.y) < 14 { return .vertex(v.id) }
        }
        let scored = diagram.edges.map { ($0.id, geometry($0).distance(to: p)) }
        if let best = scored.min(by: { $0.1 < $1.1 }), best.1 < 12 { return .edge(best.0) }
        return nil
    }
}

enum LinePainter {
    static func path(_ style: LineStyle, _ g: EdgeGeometry) -> Path {
        switch style {
        case .fermion, .higgs: return polyline(g.samples)
        case .photon: return wave(g, amplitude: 5, halfWave: 8)
        case .weak: return wave(g, amplitude: 6, halfWave: 13)
        case .gluon: return coil(g, along: 5, across: 6.5, pitch: 11)
        }
    }

    static func strokeStyle(_ style: LineStyle) -> StrokeStyle {
        switch style {
        case .higgs: return StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [8, 6])
        case .fermion: return StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        default: return StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
        }
    }

    static func draw(_ style: LineStyle, arrow: Arrow, geometry g: EdgeGeometry, in ctx: inout GraphicsContext,
                     highlighted: Bool = false, selected: Bool = false) {
        let p = path(style, g)
        if selected {
            ctx.stroke(p, with: .color(.accentColor.opacity(0.35)), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
        }
        if highlighted {
            ctx.stroke(p, with: .color(style.color.opacity(0.3)), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
        }
        ctx.stroke(p, with: .color(style.color), style: strokeStyle(style))
        if arrow != .none {
            ctx.fill(arrowHead(g, reversed: arrow == .backward), with: .color(style.color))
        }
    }

    static func polyline(_ pts: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(pts)
        return path
    }

    static func wave(_ g: EdgeGeometry, amplitude: CGFloat, halfWave: CGFloat) -> Path {
        let L = g.length
        guard L > 1 else { return polyline(g.samples) }
        let n = max(1, (L / halfWave).rounded())
        let steps = max(Int(L / 1.5), 8)
        let pts = (0...steps).map { i -> CGPoint in
            let s = L * CGFloat(i) / CGFloat(steps)
            let (p, t) = g.locate(s)
            let off = amplitude * sin(.pi * n * s / L)
            return CGPoint(x: p.x - t.dy * off, y: p.y + t.dx * off)
        }
        return polyline(pts)
    }

    /// A prolate cycloid along the curve, giving the familiar gluon "spring".
    static func coil(_ g: EdgeGeometry, along: CGFloat, across: CGFloat, pitch: CGFloat) -> Path {
        let L = g.length
        guard L > 1 else { return polyline(g.samples) }
        let n = max(2, (L / pitch).rounded())
        let steps = Int(n) * 28
        let pts = (0...steps).map { i -> CGPoint in
            let s0 = L * CGFloat(i) / CGFloat(steps)
            let phi = 2 * .pi * n * s0 / L
            // Fade the coil in and out so it meets the endpoints cleanly.
            let envelope = min(1, s0 / pitch, (L - s0) / pitch)
            let u = min(max(s0 + envelope * along * (cos(phi) - 1), 0), L)
            let (p, t) = g.locate(u)
            let off = envelope * across * sin(phi)
            return CGPoint(x: p.x - t.dy * off, y: p.y + t.dx * off)
        }
        return polyline(pts)
    }

    static func arrowHead(_ g: EdgeGeometry, reversed: Bool) -> Path {
        let (p, t0) = g.locate(g.length / 2)
        let t = reversed ? CGVector(dx: -t0.dx, dy: -t0.dy) : t0
        let n = CGVector(dx: -t.dy, dy: t.dx)
        var path = Path()
        path.move(to: CGPoint(x: p.x + t.dx * 7, y: p.y + t.dy * 7))
        path.addLine(to: CGPoint(x: p.x - t.dx * 5 + n.dx * 5.5, y: p.y - t.dy * 5 + n.dy * 5.5))
        path.addLine(to: CGPoint(x: p.x - t.dx * 2, y: p.y - t.dy * 2))
        path.addLine(to: CGPoint(x: p.x - t.dx * 5 - n.dx * 5.5, y: p.y - t.dy * 5 - n.dy * 5.5))
        path.closeSubpath()
        return path
    }
}
