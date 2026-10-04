import SwiftUI

struct OrdersView: View {
    @State private var log10Alpha: Double = log10(1.0 / 137.036)

    private var alpha: Double { pow(10, log10Alpha) }

    private let presets: [(String, Double)] = [
        ("QED (α ≈ 1/137)", 1.0 / 137.036),
        ("QCD at M_Z (α_s ≈ 0.118)", 0.118),
        ("QCD at ~1 GeV (α_s ≈ 0.5)", 0.5),
    ]

    private let g2Counts: [(Int, String)] = [(1, "1"), (2, "7"), (3, "72"), (4, "891"), (5, "12,672")]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Section_("Orders & loops", [
                    "A physical amplitude is an infinite sum over diagrams, organized by the number of vertices:",
                ])
                Text("𝓜 = 𝓜_tree + 𝓜_1-loop + 𝓜_2-loop + …")
                    .font(.system(size: 22, design: .serif))
                    .textSelection(.enabled)

                AdaptiveStack {
                    miniDiagram(.moller, caption: "Tree level: 2 vertices, 𝓜 ∝ e²")
                    miniDiagram(.vacuumPolarization, caption: "One loop: 4 vertices, 𝓜 ∝ e⁴")
                }
                .frame(maxWidth: 820)

                Section_("Each loop costs a factor of about α/π", [
                    "Adding a loop adds two vertices, which multiplies the amplitude by e² ∝ α. With the typical 1/π from the loop integral, each loop is suppressed by roughly **α/π**. Move the coupling and watch what happens to the series.",
                ])

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Coupling α = \(alpha, specifier: "%.4f")").font(.headline).monospacedDigit()
                        Text("(≈ 1/\(Int((1 / alpha).rounded())))").foregroundStyle(.secondary).monospacedDigit()
                    }
                    Slider(value: $log10Alpha, in: -2.3...0.3)
                    HStack {
                        ForEach(presets, id: \.0) { p in
                            Button(p.0) { withAnimation { log10Alpha = log10(p.1) } }
                        }
                    }
                    ForEach(0..<5) { loops in bar(loops: loops) }
                    verdict
                }
                .padding(18)
                .frame(maxWidth: 820)
                .background(RoundedRectangle(cornerRadius: 14).fill(.background.secondary))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))

                Section_("But the number of diagrams explodes", [
                    "Number of QED diagrams contributing to the electron's anomalous magnetic moment (g − 2):",
                ])
                HStack(spacing: 10) {
                    ForEach(g2Counts, id: \.0) { n, count in
                        VStack(spacing: 2) {
                            Text(count).font(.title3.bold()).monospacedDigit()
                            Text("\(n) loop\(n == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(width: 100).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
                    }
                }
                Section_("", [
                    "In QED the terms shrink much faster than the diagram count grows, so a few loops already give extraordinary precision. In low-energy QCD, α_s ~ 1 and higher loops are just as big as lower ones. Diagrams stop being useful, and physicists turn to **lattice QCD** and supercomputers instead.",
                ])
            }
            .padding(28)
        }
        .navigationTitle("Orders & loops")
        .pageContext(PageContext(
            title: "Orders & loops",
            body: """
            Page on perturbation theory: amplitude = tree + 1-loop + 2-loop + …, each loop suppressed by ~α/π. \
            Shows Møller scattering (tree) and vacuum polarization (1 loop), a coupling slider with bars for \
            (α/π)^L, and the count of QED diagrams for electron g−2 by loop order (1, 7, 72, 891, 12,672). \
            The slider is currently at α = \(String(format: "%.4f", alpha)), so α/π = \(String(format: "%.4f", alpha / .pi)).
            """,
            suggestions: ["Why is each loop suppressed by about α/π?",
                          "What is lattice QCD and why is it needed?",
                          "Does the perturbation series actually converge?"]))
    }

    private func miniDiagram(_ d: Diagram, caption: String) -> some View {
        VStack(spacing: 6) {
            DiagramCard { DiagramView(diagram: d, showTimeArrow: false).frame(height: 220) }
            Text(caption).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func bar(loops: Int) -> some View {
        let size = pow(alpha / .pi, Double(loops))
        // Log scale: 1 → full width, 1e-10 → empty.
        let fraction = max(0.01, min(1, 1 + log10(size) / 10))
        let color: Color = size > 0.3 && loops > 0 ? .red : .accentColor
        return HStack(spacing: 10) {
            Text(loops == 0 ? "tree" : "\(loops)-loop").frame(width: 56, alignment: .leading).font(.callout)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.gradient)
                    .frame(width: geo.size.width * fraction)
            }
            .frame(height: 18)
            Text(size >= 0.001 ? String(format: "%.3f", size) : String(format: "%.1e", size))
                .monospacedDigit().font(.callout).frame(width: 70, alignment: .trailing)
        }
        .animation(.default, value: fraction)
    }

    private var verdict: some View {
        let r = alpha / .pi
        let (icon, text, color): (String, String, Color) =
            r < 0.01 ? ("checkmark.seal.fill", "Converges fast: each loop is ~\(Int((1 / r).rounded()))× smaller. Perturbation theory works beautifully.", .green)
            : r < 0.1 ? ("exclamationmark.triangle.fill", "Still useful, but you need several loops for precision (typical of high-energy QCD).", .orange)
            : ("xmark.octagon.fill", "Loops aren't small. The series is useless here, so you need non-perturbative methods.", .red)
        return Label(text, systemImage: icon).foregroundStyle(color).font(.callout.bold())
    }
}
