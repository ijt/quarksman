import SwiftUI

struct Section_: View {
    let title: String
    let paragraphs: [String]
    init(_ title: String, _ paragraphs: [String]) { self.title = title; self.paragraphs = paragraphs }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.bold())
            ForEach(paragraphs, id: \.self) { Text(LocalizedStringKey($0)) }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }
}

// MARK: - Intro

struct IntroView: View {
    @State private var time: CGFloat = 0.1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Feynman Diagrams").font(.system(size: 40, weight: .bold, design: .serif))
                    Text("Pictures that are also equations.").font(.title2).foregroundStyle(.secondary)
                }

                Section_("What are they?", [
                    "In 1948 Richard Feynman introduced a way to draw particle interactions. Each picture stands for a precise mathematical term in a calculation. Each line and vertex has a **Feynman rule** that turns it into a factor, and multiplying the factors gives the **amplitude** 𝓜 for the process.",
                    "To get the probability of a process, add up the amplitudes of *every* diagram with the same incoming and outgoing particles, then square: P ∝ |𝓜₁ + 𝓜₂ + …|².",
                ])

                VStack(alignment: .leading, spacing: 8) {
                    DiagramCard {
                        DiagramView(diagram: .eeToMuMu, timeSlice: time).frame(height: 300)
                    }
                    HStack {
                        Text("Drag time forward:").foregroundStyle(.secondary)
                        Slider(value: $time, in: 0...1)
                    }
                    Text(stateDescription).font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: 760)

                Section_("How to read one", [
                    "**Time runs left to right** in this app. Some books draw time running upward. The physics is the same.",
                    "**Lines are particles.** Straight lines with arrows are matter (fermions). Wavy, curly and dashed lines are force carriers (bosons).",
                    "**Vertices are interactions.** At each dot, particles are absorbed or emitted. Charge, energy and momentum are conserved at every vertex.",
                    "**External lines** stick out of the diagram. They're the real particles you send in and detect. **Internal lines** run between two vertices. They're *virtual* particles that are never observed and don't obey E² = p² + m².",
                ])

                Section_("The key idea: perturbation theory", [
                    "Every vertex brings one factor of the coupling constant. In QED that's e, with α = e²/4π ≈ 1/137. Diagrams with more vertices are suppressed by more powers of α.",
                    "You can therefore start with the simplest diagrams (**tree level**) and add **loop** corrections for more precision. Each loop typically costs a factor of about α/π ≈ 0.002.",
                ])

                Section_("Where to go next", [
                    "• **The cast of lines** — the visual vocabulary.",
                    "• **One vertex, six stories** — rotate a single vertex to see emission, absorption, pair creation and annihilation.",
                    "• **Processes** — ten real processes. Click lines to inspect them and sweep the time slice.",
                    "• **Orders & loops** — why perturbation theory works for QED but not for low-energy QCD.",
                    "• **Quiz** — test yourself.",
                ])
            }
            .padding(28)
        }
        .navigationTitle("Introduction")
    }

    private var stateDescription: String {
        let present = Diagram.eeToMuMu.edgesCrossing(time: time).map(\.label)
        switch present {
        case ["e⁻", "e⁺"]: return "Before: an electron and a positron fly toward each other."
        case ["γ*"]: return "Middle: only a virtual photon exists. The pair has annihilated."
        case ["μ⁻", "μ⁺"]: return "After: a muon–antimuon pair flies apart."
        default: return "At a vertex: particles are being destroyed and created."
        }
    }
}

// MARK: - Lines

struct LinesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section_("The cast of lines", [
                    "Each kind of particle has its own line style. Learn these and you can read almost any diagram in a particle physics paper.",
                ])

                ForEach(LineStyle.allCases) { style in
                    HStack(alignment: .top, spacing: 18) {
                        LineSample(style: style)
                            .frame(width: 200, height: 60)
                            .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(style.title).font(.headline).foregroundStyle(style.color == .primary ? Color.primary : style.color)
                            Text(style.drawing).font(.subheadline.italic()).foregroundStyle(.secondary)
                            Text(style.examples).font(.callout)
                            Text(LocalizedStringKey(style.summary)).font(.callout).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: 520, alignment: .leading)
                    }
                }

                Section_("Particles vs antiparticles", [
                    "A positron is drawn as an *electron line with the arrow pointing backward in time*. Feynman's (and Stückelberg's) insight was that an antiparticle moving forward in time is mathematically the same as a particle moving backward.",
                ])
                HStack(spacing: 18) {
                    VStack {
                        LineSample(style: .fermion, arrow: .forward).frame(width: 200, height: 50)
                        Text("electron e⁻ →").font(.caption)
                    }
                    VStack {
                        LineSample(style: .fermion, arrow: .backward).frame(width: 200, height: 50)
                        Text("positron e⁺ →").font(.caption)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
            }
            .padding(28)
        }
        .navigationTitle("The cast of lines")
    }
}

struct LineSample: View {
    let style: LineStyle
    var arrow: Arrow? = nil

    var body: some View {
        Canvas { ctx, size in
            let g = EdgeGeometry(from: CGPoint(x: 16, y: size.height / 2), to: CGPoint(x: size.width - 16, y: size.height / 2))
            LinePainter.draw(style, arrow: arrow ?? (style == .fermion ? .forward : .none), geometry: g, in: &ctx)
        }
    }
}

// MARK: - Vertex explorer

struct VertexExplorerView: View {
    @State private var angle: Double = 20

    private struct Reading { let initial: [String]; let final: [String] }

    private static let aspect: CGFloat = 1.6
    private static let legOffsets: [Double] = [210, 330, 90] // incoming-arrow fermion, outgoing-arrow fermion, photon

    private static func cosines(_ angle: Double) -> [Double] {
        legOffsets.map { cos(($0 + angle) * .pi / 180) }
    }

    private static func reading(_ angle: Double) -> Reading {
        let c = cosines(angle)
        var initial: [String] = [], final: [String] = []
        // Arrow into the vertex: from the past it's an electron; from the future it's an outgoing positron.
        if c[0] < 0 { initial.append("e⁻") } else { final.append("e⁺") }
        // Arrow out of the vertex: into the future it's an electron; into the past it's an incoming positron.
        if c[1] > 0 { final.append("e⁻") } else { initial.append("e⁺") }
        if c[2] < 0 { initial.append("γ") } else { final.append("γ") }
        return Reading(initial: initial.sorted(by: order), final: final.sorted(by: order))
    }

    private static func order(_ a: String, _ b: String) -> Bool {
        let rank = ["e⁻": 0, "e⁺": 1, "γ": 2]
        return rank[a]! < rank[b]!
    }

    private static func key(_ r: Reading) -> String { r.initial.joined() + "→" + r.final.joined() }

    private static let stories: [(key: String, title: String, text: String)] = [
        ("e⁻→e⁻γ", "An electron emits a photon",
         "The fermion arrow runs straight through: the electron continues on with less energy and recoils."),
        ("e⁻γ→e⁻", "An electron absorbs a photon",
         "The time-reverse of emission. This is how atoms absorb light."),
        ("e⁺→e⁺γ", "A positron emits a photon",
         "The fermion arrow now points backward in time, which is how a positron moving forward is drawn."),
        ("e⁺γ→e⁺", "A positron absorbs a photon",
         "Same vertex, same rule: −ieγ^μ. Only the reading in time has changed."),
        ("e⁻e⁺→γ", "Pair annihilation",
         "Electron and positron meet and become a photon. The arrow comes in on the electron and goes back out on the positron."),
        ("γ→e⁻e⁺", "Pair creation",
         "A photon turns into matter and antimatter, E = mc² in action."),
    ]

    /// For each story, the rotation where all legs are furthest from vertical.
    private static let presets: [String: Double] = {
        var best: [String: (Double, Double)] = [:]
        for a in stride(from: 0.0, to: 360, by: 1) {
            let k = key(reading(a))
            let margin = cosines(a).map(abs).min()!
            if margin > (best[k]?.1 ?? -1) { best[k] = (a, margin) }
        }
        return best.mapValues(\.0)
    }()

    private var diagram: Diagram {
        let r: CGFloat = 0.38
        let c = Self.cosines(angle)
        func node(_ id: String, _ offset: Double) -> Node {
            let a = (offset + angle) * .pi / 180
            return .ext(id, 0.5 + r * CGFloat(cos(a)) / Self.aspect, 0.5 - r * CGFloat(sin(a)))
        }
        let legA = c[0] < 0 ? Particle.electron : .positron
        let legB = c[1] > 0 ? Particle.electron : .positron
        return Diagram(
            id: "explorer", title: "", process: "", interaction: .qed, summary: "", details: [], amplitude: "",
            nodes: [.vtx("v", 0.5, 0.5), node("a", Self.legOffsets[0]), node("b", Self.legOffsets[1]), node("p", Self.legOffsets[2])],
            edges: [
                Edge("a", "v", legA, arrow: .forward),
                Edge("v", "b", legB, arrow: .forward),
                Edge("v", "p", .photon),
            ],
            aspect: Self.aspect)
    }

    var body: some View {
        let reading = Self.reading(angle)
        let story = Self.stories.first { $0.key == Self.key(reading) }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Section_("One vertex, six stories", [
                    "QED has exactly **one** basic vertex: two fermion legs and one photon leg. Rotate it, and read it with time running left to right. Legs on the left are *incoming*; legs on the right are *outgoing*.",
                ])

                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 10) {
                        DiagramCard {
                            ZStack(alignment: .top) {
                                HStack {
                                    Text("PAST").font(.caption.bold()).foregroundStyle(.tertiary)
                                    Spacer()
                                    Text("FUTURE").font(.caption.bold()).foregroundStyle(.tertiary)
                                }
                                .padding(12)
                                DiagramView(diagram: diagram, timeSlice: 0.5)
                            }
                            .frame(height: 340)
                        }
                        HStack {
                            Image(systemName: "rotate.right")
                            Slider(value: $angle, in: 0...360)
                            Text("\(Int(angle))°").monospacedDigit().frame(width: 40)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(story?.title ?? "—").font(.title2.bold())
                        HStack {
                            Text(reading.initial.joined(separator: " + "))
                            Image(systemName: "arrow.right")
                            Text(reading.final.joined(separator: " + "))
                        }
                        .font(.system(size: 24, design: .serif))
                        Text(story?.text ?? "").font(.callout)
                        Divider()
                        Text("Jump to:").font(.caption.bold()).foregroundStyle(.secondary)
                        ForEach(Self.stories, id: \.key) { s in
                            Button(s.title) {
                                withAnimation(.easeInOut(duration: 0.6)) { angle = Self.presets[s.key] ?? angle }
                            }
                            .buttonStyle(.link)
                        }
                    }
                    .padding(16)
                    .frame(width: 300, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.background.secondary))
                }

                Section_("The catch", [
                    "None of these six processes can actually happen *on its own* with all three particles real. A free electron can't emit a real photon without breaking energy–momentum conservation. Every real process glues two or more vertices together with virtual lines, which are allowed to be off-shell.",
                    "This is **crossing symmetry**. One vertex rule describes every one of these processes. Their amplitudes are related by swapping incoming particles for outgoing antiparticles.",
                ])
            }
            .padding(28)
        }
        .navigationTitle("One vertex, six stories")
    }
}
