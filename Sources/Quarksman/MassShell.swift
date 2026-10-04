import SwiftUI

/// Energy vs. momentum (one spatial direction, units with c = 1): the mass shell of a massive particle,
/// the photon's shell, and where real and virtual particles sit.
struct MassShellView: View {
    private let pRange: ClosedRange<CGFloat> = -3...3
    private let eMax: CGFloat = 3.4
    private let mass: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DiagramCard {
                Canvas { ctx, size in draw(&ctx, size) }
                    .adaptiveHeight(280, compact: 240)
                    .accessibilityLabel("Plot of energy against momentum showing the mass shell, the photon's light cone, and on-shell and off-shell points")
            }
            legend
            ProseText("In three dimensions of momentum the curve becomes a bowl-shaped surface, a hyperboloid. That surface is the \"shell\". A virtual particle can sit anywhere energy and momentum conservation puts it, on or off its shell.", markdown: false)
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            legendRow("Mass shell of a massive particle: E² = p² + m²") {
                Rectangle().fill(Color.accentColor).frame(width: 22, height: 2.4)
            }
            legendRow("Photon shell (m = 0): E = |p|") {
                Path { $0.move(to: CGPoint(x: 0, y: 1)); $0.addLine(to: CGPoint(x: 22, y: 1)) }
                    .stroke(LineStyle.photon.color, style: StrokeStyle(lineWidth: 1.6, dash: [6, 5]))
                    .frame(width: 22, height: 2)
            }
            legendRow("Real electron: on its shell") {
                Circle().fill(Color.accentColor).frame(width: 10, height: 10)
            }
            legendRow("Virtual photons: off their shell. Inside the cone q² > 0 (s-channel); outside it q² < 0 (t-channel)") {
                Circle().strokeBorder(LineStyle.photon.color, lineWidth: 2).frame(width: 10, height: 10)
            }
        }
        .font(.caption)
    }

    private func legendRow<Swatch: View>(_ text: String, @ViewBuilder swatch: () -> Swatch) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            swatch().frame(width: 22).alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            Text(text)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let inset = EdgeInsets(top: 16, leading: 16, bottom: 28, trailing: 16)
        let w = size.width - inset.leading - inset.trailing
        let h = size.height - inset.top - inset.bottom
        func pt(_ p: CGFloat, _ e: CGFloat) -> CGPoint {
            CGPoint(x: inset.leading + (p - pRange.lowerBound) / (pRange.upperBound - pRange.lowerBound) * w,
                    y: inset.top + (1 - e / eMax) * h)
        }
        func curve(_ e: (CGFloat) -> CGFloat) -> Path {
            var path = Path()
            let steps = 120
            for i in 0...steps {
                let p = pRange.lowerBound + (pRange.upperBound - pRange.lowerBound) * CGFloat(i) / CGFloat(steps)
                let y = e(p)
                guard y <= eMax else { continue }
                path.isEmpty ? path.move(to: pt(p, y)) : path.addLine(to: pt(p, y))
            }
            return path
        }
        func label(_ s: String, at point: CGPoint, anchor: UnitPoint, color: Color = .secondary) {
            ctx.draw(Text(s).font(.caption).foregroundStyle(color), at: point, anchor: anchor)
        }

        // Axes.
        var axes = Path()
        axes.move(to: pt(pRange.lowerBound, 0)); axes.addLine(to: pt(pRange.upperBound, 0))
        axes.move(to: pt(0, 0)); axes.addLine(to: pt(0, eMax))
        ctx.stroke(axes, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
        label("momentum p", at: CGPoint(x: pt(pRange.upperBound, 0).x, y: pt(0, 0).y + 6), anchor: .topTrailing)
        label("energy E", at: CGPoint(x: pt(0, eMax).x + 6, y: pt(0, eMax).y), anchor: .topLeading)

        // Photon shell (light cone) and the massive particle's shell.
        let photonColor = LineStyle.photon.color
        ctx.stroke(curve { abs($0) }, with: .color(photonColor), style: StrokeStyle(lineWidth: 1.6, dash: [6, 5]))
        ctx.stroke(curve { sqrt($0 * $0 + mass * mass) }, with: .color(.accentColor), lineWidth: 2.4)

        // Points: one real (filled, on its shell), two virtual (hollow, off the photon shell).
        func dot(_ p: CGFloat, _ e: CGFloat, filled: Bool, color: Color) -> CGPoint {
            let c = pt(p, e)
            let r: CGFloat = 5
            let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            if filled { ctx.fill(circle, with: .color(color)) } else { ctx.stroke(circle, with: .color(color), lineWidth: 2) }
            return c
        }
        let electron = dot(1.2, sqrt(1.2 * 1.2 + mass * mass), filled: true, color: .accentColor)
        label("e⁻", at: CGPoint(x: electron.x + 10, y: electron.y), anchor: .leading, color: .primary)
        let sChannel = dot(0, 2.6, filled: false, color: photonColor)
        label("γ* in e⁺e⁻ → μ⁺μ⁻", at: CGPoint(x: sChannel.x + 10, y: sChannel.y), anchor: .leading, color: .primary)
        let tChannel = dot(1.9, 0.45, filled: false, color: photonColor)
        label("γ* in Møller", at: CGPoint(x: tChannel.x - 10, y: tChannel.y - 12), anchor: .trailing, color: .primary)
    }
}
