import SwiftUI

struct Rule {
    let title: String
    let formula: String
    let explanation: String
}

enum FeynmanRules {
    enum Role { case incoming, outgoing, `internal`, spectator }

    static func role(of e: Edge, in d: Diagram) -> Role {
        let fromV = d.node(e.from).isVertex, toV = d.node(e.to).isVertex
        switch (fromV, toV) {
        case (true, true): return .internal
        case (false, true): return .incoming
        case (true, false): return .outgoing
        case (false, false): return .spectator
        }
    }

    static func rule(for e: Edge, in d: Diagram) -> Rule {
        let p = e.particle
        switch role(of: e, in: d) {
        case .spectator:
            return Rule(title: "Spectator line", formula: "(no factor)",
                        explanation: "This particle doesn't touch any vertex. It just goes along for the ride.")
        case .internal:
            let formula: String
            switch p.style {
            case .fermion: formula = "i(q̸ + m) / (q² − m²)"
            case .photon: formula = "−i g_μν / q²"
            case .gluon: formula = "−i g_μν δᵃᵇ / q²"
            case .weak: formula = "−i (g_μν − q_μq_ν/M²) / (q² − M²)"
            case .higgs: formula = "i / (q² − m²_H)"
            }
            return Rule(title: "Propagator (virtual \(p.name.lowercased()))", formula: formula,
                        explanation: "Internal lines are **virtual**. They can be off-shell, meaning off the mass shell q² = m² that real particles satisfy, and are never observed directly. The propagator is largest when q² is close to m². That's how resonances appear.")
        case .incoming, .outgoing:
            let incoming = role(of: e, in: d) == .incoming
            let formula: String
            switch p.style {
            case .fermion:
                switch (incoming, p.isAntiparticle) {
                case (true, false): formula = "u(p)"
                case (true, true): formula = "v̄(p)"
                case (false, false): formula = "ū(p)"
                case (false, true): formula = "v(p)"
                }
            case .photon, .weak: formula = incoming ? "ε_μ(p)" : "ε*_μ(p)"
            case .gluon: formula = incoming ? "ε_μ(p) · color vector" : "ε*_μ(p) · color vector"
            case .higgs: formula = "1"
            }
            return Rule(title: "External \(incoming ? "incoming" : "outgoing") \(p.name.lowercased())",
                        formula: formula,
                        explanation: "External lines are **real** particles: on-shell, meaning their four-momentum satisfies p² = E² − |p⃗|² = m², and seen in the detector. Each one contributes a wavefunction factor: a spinor for fermions, a polarization vector for vector bosons.")
        }
    }

    static func rule(forVertex id: String, in d: Diagram) -> Rule {
        let styles = d.edges(at: id).map(\.particle.style)
        let gluons = styles.filter { $0 == .gluon }.count
        if gluons >= 3 {
            return Rule(title: "Three-gluon vertex", formula: "g_s f^{abc} [g_μν(k−p)_ρ + g_νρ(p−q)_μ + g_ρμ(q−k)_ν]",
                        explanation: "Gluons carry color charge, so they couple to each other. QED has no three-photon vertex because the photon is neutral.")
        }
        if styles.contains(.gluon) {
            return Rule(title: "Quark–gluon vertex", formula: "−i g_s γ^μ Tᵃ",
                        explanation: "Strength g_s, with α_s = g²_s/4π ≈ 0.1–1. The color matrix Tᵃ lets the quark change color. Flavor and electric charge are conserved.")
        }
        if styles.contains(.weak) {
            return Rule(title: "Charged-current weak vertex", formula: "−i (g/√2) γ^μ ½(1 − γ⁵)",
                        explanation: "The W changes flavor (d → u, e⁻ ↔ νₑ) and couples only to left-handed particles, which violates parity. Electric charge is still conserved: −⅓ = +⅔ + (−1).")
        }
        if styles.contains(.higgs) {
            return Rule(title: "Yukawa (Higgs–fermion) vertex", formula: "−i m_f / v,   v ≈ 246 GeV",
                        explanation: "The Higgs couples in proportion to mass. For the top quark, m_t/v ≈ 0.7. For the electron it's 0.000002.")
        }
        let field = d.edges(at: id).contains { $0.label.contains("field") }
        return Rule(title: "QED vertex", formula: "−i Q e γ^μ",
                    explanation: "Strength e, with √α ≈ 0.085. Every vertex conserves charge, energy and momentum. The fermion arrow goes in and comes out again." + (field ? " The top photon is an external classical field: a magnet." : ""))
    }
}

struct SelectionInfoView: View {
    let diagram: Diagram
    let selection: DiagramSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch selection {
            case .none:
                Label("Inspect", systemImage: "hand.tap").font(.headline)
                Text("Click any **line** to see the particle and its Feynman rule, or click a **vertex** (dot) to see the interaction.")
                    .foregroundStyle(.secondary)
                Divider()
                legendRow("Real (external) lines", "enter or leave the diagram")
                legendRow("Virtual (internal) lines", "connect two vertices")
                legendRow("Vertices", "where particles interact")
            case .edge(let id):
                let edge = diagram.edges[id]
                let rule = FeynmanRules.rule(for: edge, in: diagram)
                HStack {
                    Text(edge.particle.symbol).font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(edge.particle.style.color)
                    VStack(alignment: .leading) {
                        Text(edge.particle.name).font(.headline)
                        Text(rule.title).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow { Text("Charge").foregroundStyle(.secondary); Text(edge.particle.charge) }
                    GridRow { Text("Spin").foregroundStyle(.secondary); Text(edge.particle.spin) }
                    GridRow { Text("Mass").foregroundStyle(.secondary); Text(edge.particle.mass) }
                }
                .font(.callout)
                Text(edge.particle.blurb).font(.callout)
                ruleBox(rule)
            case .vertex(let id):
                let rule = FeynmanRules.rule(forVertex: id, in: diagram)
                Label(rule.title, systemImage: "circle.fill").font(.headline)
                Text("Lines meeting here: " + diagram.edges(at: id).map(\.label).joined(separator: ", "))
                    .font(.callout).foregroundStyle(.secondary)
                ruleBox(rule)
            }
            Spacer(minLength: 0)
        }
        .textSelection(.enabled)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14).fill(.background.secondary))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }

    private func legendRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.callout.bold())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func ruleBox(_ rule: Rule) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Feynman rule").font(.caption.bold()).foregroundStyle(.secondary)
            Text(rule.formula).font(.system(.body, design: .serif)).textSelection(.enabled)
                .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
            Text(LocalizedStringKey(rule.explanation)).font(.callout)
        }
    }
}
