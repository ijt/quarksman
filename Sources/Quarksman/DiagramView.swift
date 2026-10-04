import SwiftUI

enum DiagramSelection: Hashable {
    case edge(Int)
    case vertex(String)
}

struct DiagramView: View {
    let diagram: Diagram
    var showLabels = true
    var showTimeArrow = true
    var timeSlice: CGFloat? = nil
    var selection: DiagramSelection? = nil
    var onSelect: ((DiagramSelection?) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let layout = DiagramLayout(diagram: diagram, size: geo.size, bottomInset: showTimeArrow ? 44 : 30)
            Canvas { ctx, _ in
                draw(in: &ctx, layout: layout)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                onSelect?(layout.hitTest(location))
            }
        }
    }

    private func draw(in ctx: inout GraphicsContext, layout: DiagramLayout) {
        let frame = layout.frame

        if showTimeArrow {
            let y = frame.maxY + 30
            var axis = Path()
            axis.move(to: CGPoint(x: frame.minX, y: y))
            axis.addLine(to: CGPoint(x: frame.minX + 70, y: y))
            axis.move(to: CGPoint(x: frame.minX + 63, y: y - 4))
            axis.addLine(to: CGPoint(x: frame.minX + 70, y: y))
            axis.addLine(to: CGPoint(x: frame.minX + 63, y: y + 4))
            ctx.stroke(axis, with: .color(.secondary), lineWidth: 1.2)
            ctx.draw(Text("time").font(.caption).foregroundStyle(.secondary),
                     at: CGPoint(x: frame.minX + 78, y: y), anchor: .leading)
        }

        var crossing: Set<Int> = []
        if let t = timeSlice {
            crossing = Set(diagram.edgesCrossing(time: t).map(\.id))
            let x = frame.minX + t * frame.width
            var line = Path()
            line.move(to: CGPoint(x: x, y: frame.minY - 18))
            line.addLine(to: CGPoint(x: x, y: frame.maxY + 18))
            ctx.stroke(line, with: .color(.accentColor.opacity(0.8)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            ctx.draw(Text("now").font(.caption2.bold()).foregroundStyle(Color.accentColor),
                     at: CGPoint(x: x, y: frame.minY - 24))
        }

        for edge in diagram.edges {
            let g = layout.geometry(edge)
            LinePainter.draw(edge.particle.style, arrow: edge.arrow, geometry: g, in: &ctx,
                             highlighted: crossing.contains(edge.id),
                             selected: selection == .edge(edge.id))
            if showLabels {
                let (p, t) = g.locate(g.length / 2)
                let wavy = edge.particle.style != .fermion && edge.particle.style != .higgs
                // Push long labels further out when they sit beside a steep line.
                let extra = CGFloat(max(0, edge.label.count - 2)) * 4 * abs(t.dy)
                let d: CGFloat = ((wavy ? 22 : 18) + extra) * edge.labelSide
                let pos = CGPoint(x: p.x - t.dy * d, y: p.y + t.dx * d)
                ctx.draw(Text(edge.label)
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(edge.particle.style.color),
                         at: pos)
            }
        }

        for v in diagram.vertices {
            let p = layout.point(v.id)
            if selection == .vertex(v.id) {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)),
                         with: .color(.accentColor.opacity(0.35)))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)), with: .color(.primary))
        }
    }
}

/// A rounded card behind diagrams.
struct DiagramCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 14).fill(.background.secondary))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }
}
