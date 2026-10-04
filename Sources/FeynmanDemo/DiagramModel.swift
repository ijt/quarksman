import SwiftUI

enum Interaction: String, CaseIterable, Identifiable {
    case qed, qcd, weak, higgs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qed: return "Electromagnetic (QED)"
        case .qcd: return "Strong (QCD)"
        case .weak: return "Weak"
        case .higgs: return "Higgs"
        }
    }

    var icon: String {
        switch self {
        case .qed: return "bolt.fill"
        case .qcd: return "circle.hexagongrid.fill"
        case .weak: return "atom"
        case .higgs: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .qed: return .orange
        case .qcd: return .green
        case .weak: return .purple
        case .higgs: return .pink
        }
    }
}

/// A point in a diagram. Coordinates are normalized: x is time (0 = past, 1 = future), y runs top to bottom.
struct Node: Identifiable, Hashable {
    let id: String
    let x: CGFloat
    let y: CGFloat
    let isVertex: Bool

    static func ext(_ id: String, _ x: CGFloat, _ y: CGFloat) -> Node { Node(id: id, x: x, y: y, isVertex: false) }
    static func vtx(_ id: String, _ x: CGFloat, _ y: CGFloat) -> Node { Node(id: id, x: x, y: y, isVertex: true) }
}

enum Arrow { case forward, backward, none }

struct Edge: Identifiable {
    var id = 0
    let from: String
    let to: String
    let particle: Particle
    let arrow: Arrow
    /// Sideways bulge as a fraction of the edge length (0 = straight).
    let bend: CGFloat
    /// Which side of the line the label sits on (−1 or +1).
    let labelSide: CGFloat
    let label: String

    init(_ from: String, _ to: String, _ particle: Particle, arrow: Arrow? = nil,
         bend: CGFloat = 0, labelSide: CGFloat = -1, label: String? = nil) {
        self.from = from
        self.to = to
        self.particle = particle
        self.arrow = arrow ?? (particle.style == .fermion ? (particle.isAntiparticle ? .backward : .forward) : .none)
        self.bend = bend
        self.labelSide = labelSide
        self.label = label ?? particle.symbol
    }
}

struct Diagram: Identifiable {
    let id: String
    let title: String
    let process: String
    let interaction: Interaction
    let summary: String
    let details: [String]
    let amplitude: String
    let nodes: [Node]
    let edges: [Edge]
    var aspect: CGFloat = 1.6

    init(id: String, title: String, process: String, interaction: Interaction, summary: String,
         details: [String], amplitude: String, nodes: [Node], edges: [Edge], aspect: CGFloat = 1.6) {
        self.id = id
        self.title = title
        self.process = process
        self.interaction = interaction
        self.summary = summary
        self.details = details
        self.amplitude = amplitude
        self.nodes = nodes
        self.edges = edges.enumerated().map { i, e in var e = e; e.id = i; return e }
        self.aspect = aspect
    }

    func node(_ id: String) -> Node { nodes.first { $0.id == id }! }

    var vertices: [Node] { nodes.filter(\.isVertex) }

    func isInternal(_ e: Edge) -> Bool { node(e.from).isVertex && node(e.to).isVertex }

    var internalEdges: [Edge] { edges.filter(isInternal) }

    /// Independent loops of a connected diagram: L = I − V + 1.
    var loops: Int { max(0, internalEdges.count - vertices.count + 1) }

    func edges(at vertexID: String) -> [Edge] { edges.filter { $0.from == vertexID || $0.to == vertexID } }

    /// Edges that exist at normalized time `t` — the "state" of the system at that instant.
    func edgesCrossing(time t: CGFloat) -> [Edge] {
        let layout = DiagramLayout(unit: self)
        let x = t * aspect
        return edges.filter { e in
            let g = layout.geometry(e)
            return g.minX < x && x < g.maxX
        }
    }
}
