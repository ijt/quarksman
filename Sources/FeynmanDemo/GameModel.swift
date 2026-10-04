import SwiftUI

/// Particle species available in the diagram-building game.
enum Species: String, CaseIterable, Codable {
    case e, mu, nuE, nuMu, u, d, t, photon, gluon, w, higgs

    var isFermion: Bool { [.e, .mu, .nuE, .nuMu, .u, .d, .t].contains(self) }
    var isColored: Bool { [.u, .d, .t].contains(self) }
    var isNeutrino: Bool { self == .nuE || self == .nuMu }

    /// Electric charge of the particle (antiparticles have the opposite sign).
    var charge: Double {
        switch self {
        case .e, .mu: return -1
        case .u, .t: return 2.0 / 3
        case .d: return -1.0 / 3
        default: return 0
        }
    }

    /// The W connects only these weak-doublet partners.
    var weakPartner: Species? {
        switch self {
        case .e: return .nuE
        case .nuE: return .e
        case .mu: return .nuMu
        case .nuMu: return .mu
        case .u: return .d
        case .d: return .u
        default: return nil
        }
    }

    var style: LineStyle {
        switch self {
        case .photon: return .photon
        case .gluon: return .gluon
        case .w: return .weak
        case .higgs: return .higgs
        default: return .fermion
        }
    }

    var name: String {
        switch self {
        case .e: return "electron"
        case .mu: return "muon"
        case .nuE: return "electron neutrino"
        case .nuMu: return "muon neutrino"
        case .u: return "up quark"
        case .d: return "down quark"
        case .t: return "top quark"
        case .photon: return "photon"
        case .gluon: return "gluon"
        case .w: return "W boson"
        case .higgs: return "Higgs"
        }
    }

    /// The name with "a" or "an", for messages.
    var aName: String { (["electron", "electron neutrino", "up quark"].contains(name) ? "an " : "a ") + name }

    func symbol(anti: Bool = false) -> String {
        switch self {
        case .e: return anti ? "e⁺" : "e⁻"
        case .mu: return anti ? "μ⁺" : "μ⁻"
        case .nuE: return anti ? "ν̄ₑ" : "νₑ"
        case .nuMu: return anti ? "ν̄μ" : "νμ"
        case .u: return anti ? "ū" : "u"
        case .d: return anti ? "d̄" : "d"
        case .t: return anti ? "t̄" : "t"
        case .photon: return "γ"
        case .gluon: return "g"
        case .w: return "W"
        case .higgs: return "H"
        }
    }
}

func chargeText(_ q: Double) -> String {
    let thirds = Int((q * 3).rounded())
    switch thirds {
    case 0: return "0"
    case 3: return "+1"
    case -3: return "−1"
    case 2: return "+⅔"
    case -2: return "−⅔"
    case 1: return "+⅓"
    case -1: return "−⅓"
    default: return (thirds > 0 ? "+" : "−") + "\(abs(thirds))/3"
    }
}

/// An external particle in a level: what it is, whether it's an antiparticle, and whether it comes in or goes out.
struct GameLeg: Hashable {
    let species: Species
    var anti = false
    let incoming: Bool

    var symbol: String { species.symbol(anti: anti) }
    /// Whether this leg's fermion arrow points into the diagram.
    var arrowIntoDiagram: Bool { incoming != anti }

    static func into(_ s: Species, anti: Bool = false) -> GameLeg { GameLeg(species: s, anti: anti, incoming: true) }
    static func out(_ s: Species, anti: Bool = false) -> GameLeg { GameLeg(species: s, anti: anti, incoming: false) }
}

struct GameLevel: Identifiable {
    let id: String
    let title: String
    let goal: String
    let legs: [GameLeg]
    let palette: [Species]
    /// Fewest vertices that work (for three stars); nil for impossible levels.
    let par: Int?
    let hint: String
    let lesson: String
    var impossible: Bool { par == nil }

    var processText: String {
        let ins = legs.filter(\.incoming).map(\.symbol).joined(separator: " ")
        let outs = legs.filter { !$0.incoming }.map(\.symbol).joined(separator: " ")
        return "\(ins) → \(outs)"
    }
}

extension GameLevel {
    static let all: [GameLevel] = [
        GameLevel(id: "repel", title: "Repel",
                  goal: "Two electrons come in and two go out. Make them scatter off each other.",
                  legs: [.into(.e), .into(.e), .out(.e), .out(.e)], palette: [.photon], par: 2,
                  hint: "Each electron needs its own vertex. What could carry momentum from one to the other?",
                  lesson: "That's Møller scattering: the electrons trade a virtual photon. There's also a crossed version with the outgoing electrons swapped, and the two amplitudes are added."),
        GameLevel(id: "annihilate", title: "Annihilate",
                  goal: "An electron and a positron go in; a muon and an antimuon come out.",
                  legs: [.into(.e), .into(.e, anti: true), .out(.mu), .out(.mu, anti: true)], palette: [.photon], par: 2,
                  hint: "Fermion arrows can't stop at a vertex: the electron's arrow has to leave again along the positron line.",
                  lesson: "Annihilation in the s-channel. The virtual photon carries all of the collision energy, so it's far off its mass shell."),
        GameLevel(id: "compton", title: "Bounce light",
                  goal: "A photon scatters off an electron.",
                  legs: [.into(.e), .into(.photon), .out(.e), .out(.photon)], palette: [.photon, .e], par: 2,
                  hint: "The electron absorbs one photon and emits the other. In between, it's a virtual electron.",
                  lesson: "Compton scattering. There are two orderings, absorb-then-emit and emit-then-absorb, and you need both for the right answer."),
        GameLevel(id: "pair", title: "Light into matter",
                  goal: "Two photons collide and make an electron–positron pair.",
                  legs: [.into(.photon), .into(.photon), .out(.e), .out(.e, anti: true)], palette: [.photon, .e], par: 2,
                  hint: "Each photon must attach to a charged line. Run one fermion line from the e⁺ back through both vertices to the e⁻.",
                  lesson: "The Breit–Wheeler process: light turning into matter. It's pair annihilation run backward in time."),
        GameLevel(id: "muon", title: "Muon decay",
                  goal: "A muon decays into a muon neutrino, an electron and an electron antineutrino.",
                  legs: [.into(.mu), .out(.nuMu), .out(.e), .out(.nuE, anti: true)], palette: [.photon, .w], par: 2,
                  hint: "Photons never change flavor. Which boson turns a muon into its neutrino?",
                  lesson: "The W turns μ⁻ into νμ, then becomes e⁻ and ν̄ₑ. The W is so heavy that this takes a leisurely 2.2 μs, ages by particle standards."),
        GameLevel(id: "beta", title: "Beta decay",
                  goal: "A down quark (inside a neutron) becomes an up quark, an electron and an antineutrino.",
                  legs: [.into(.d), .out(.u), .out(.e), .out(.nuE, anti: true)], palette: [.photon, .w], par: 2,
                  hint: "Same idea as muon decay, but the W attaches to quarks at one end.",
                  lesson: "Neutron β decay at the quark level: udd → uud. Check the charge at the quark vertex: −⅓ = +⅔ + (−1)."),
        GameLevel(id: "strong", title: "Quark scattering",
                  goal: "An up quark and a down quark scatter.",
                  legs: [.into(.u), .into(.d), .out(.u), .out(.d)], palette: [.photon, .gluon], par: 2,
                  hint: "Quarks feel the strong force. Exchange something between them.",
                  lesson: "Both a photon and a gluon work. The gluon wins by far, because α_s ≈ 0.1–1 while α ≈ 1/137."),
        GameLevel(id: "glue", title: "Glue on glue",
                  goal: "Two gluons scatter into two gluons, with no quarks at all.",
                  legs: [.into(.gluon), .into(.gluon), .out(.gluon), .out(.gluon)], palette: [.gluon, .photon], par: 2,
                  hint: "Gluons carry color, so they can meet other gluons at a vertex.",
                  lesson: "Only possible because gluons interact with each other. Swap the gluons for photons and there's no tree-level diagram: light-by-light scattering needs a loop of charged particles."),
        GameLevel(id: "higgs", title: "Higgs to photons",
                  goal: "A Higgs boson decays into two photons.",
                  legs: [.into(.higgs), .out(.photon), .out(.photon)], palette: [.photon, .t], par: 3,
                  hint: "The Higgs never touches photons directly. It does couple to heavy charged particles, and so do photons.",
                  lesson: "You built a loop! Only about 0.2% of Higgs bosons decay this way, but it was one of the two channels in which the Higgs was discovered in 2012."),
        GameLevel(id: "lfv", title: "Trick question",
                  goal: "Can a muon decay into just an electron and a photon? Build it, or press \"It can't happen\".",
                  legs: [.into(.mu), .out(.e), .out(.photon)], palette: [.photon, .w, .e, .mu, .nuE, .nuMu], par: nil,
                  hint: "Look at what each vertex is allowed to do to a particle's flavor.",
                  lesson: "Correct: it can't happen. Photons never change flavor, and the W always pairs a lepton with its own neutrino. (Tiny neutrino masses do allow it at about 10⁻⁵⁴, far beyond any experiment. Seeing it would mean new physics.)"),
        GameLevel(id: "family", title: "Family business",
                  goal: "Two electrons collide. Can two muons come out?",
                  legs: [.into(.e), .into(.e), .out(.mu), .out(.mu)], palette: [.photon, .w, .e, .mu, .nuE, .nuMu], par: nil,
                  hint: "Count electrons and muons on each side.",
                  lesson: "Correct: electron number and muon number are each conserved, so two electrons can't become two muons. (An electron and a positron can, because together they have zero electron number.)"),
    ]
}

// MARK: - Board

struct BoardNode: Identifiable, Equatable {
    let id: Int
    var x: CGFloat
    var y: CGFloat
    /// Index into the level's legs for an external particle; nil for a vertex.
    var leg: Int?
    var isVertex: Bool { leg == nil }
}

/// A line on the board. For a line to an external particle, `a` is the external node and `b` the vertex.
/// For an internal line, a fermion's arrow points from `a` to `b`.
struct BoardEdge: Identifiable, Equatable {
    let id: Int
    var a: Int
    var b: Int
    var species: Species
}

struct Board: Equatable {
    var nodes: [BoardNode] = []
    var edges: [BoardEdge] = []
    var nextID = 0

    init(level: GameLevel) {
        let ins = level.legs.indices.filter { level.legs[$0].incoming }
        let outs = level.legs.indices.filter { !level.legs[$0].incoming }
        for (k, i) in ins.enumerated() { add(x: 0.05, y: CGFloat(k + 1) / CGFloat(ins.count + 1), leg: i) }
        for (k, i) in outs.enumerated() { add(x: 0.95, y: CGFloat(k + 1) / CGFloat(outs.count + 1), leg: i) }
    }

    @discardableResult
    mutating func add(x: CGFloat, y: CGFloat, leg: Int? = nil) -> Int {
        let id = nextID
        nextID += 1
        nodes.append(BoardNode(id: id, x: x, y: y, leg: leg))
        return id
    }

    func node(_ id: Int) -> BoardNode? { nodes.first { $0.id == id } }
    func edges(at id: Int) -> [BoardEdge] { edges.filter { $0.a == id || $0.b == id } }
    var vertices: [BoardNode] { nodes.filter(\.isVertex) }
    var internalEdges: [BoardEdge] { edges.filter { node($0.a)?.isVertex == true && node($0.b)?.isVertex == true } }

    mutating func removeNode(_ id: Int) {
        guard node(id)?.isVertex == true else { return }
        edges.removeAll { $0.a == id || $0.b == id }
        nodes.removeAll { $0.id == id }
    }

    mutating func removeEdge(_ id: Int) { edges.removeAll { $0.id == id } }

    mutating func flip(_ id: Int) {
        guard let i = edges.firstIndex(where: { $0.id == id }) else { return }
        let a = edges[i].a
        edges[i].a = edges[i].b
        edges[i].b = a
    }

    /// Connects two nodes; returns a reason if the connection isn't allowed.
    mutating func connect(_ p: Int, _ q: Int, internalSpecies: Species, level: GameLevel) -> String? {
        guard p != q, let np = node(p), let nq = node(q) else { return nil }
        if !np.isVertex && !nq.isVertex { return "Particles meet only at vertices. Connect each one to a vertex." }
        for n in [np, nq] {
            if n.isVertex && edges(at: n.id).count >= 3 { return "A vertex joins exactly three lines, and this one already has three." }
            if let leg = n.leg, !edges(at: n.id).isEmpty { return "\(level.legs[leg].symbol) is already connected." }
        }
        if let leg = np.leg ?? nq.leg {
            let external = np.leg != nil ? p : q
            let vertex = np.leg != nil ? q : p
            edges.append(BoardEdge(id: nextID, a: external, b: vertex, species: level.legs[leg].species))
        } else {
            edges.append(BoardEdge(id: nextID, a: p, b: q, species: internalSpecies))
        }
        nextID += 1
        return nil
    }
}

// MARK: - Checking

struct GameProblem: Identifiable {
    let id = UUID()
    let message: String
    var nodes: [Int] = []
    var edges: [Int] = []
}

struct GameCheck {
    var problems: [GameProblem]
    var vertexCount: Int
    var loops: Int
    var isValid: Bool { problems.isEmpty }
}

enum GameRules {
    /// Whether a fermion line's arrow points into vertex `v`.
    static func arrowIn(_ e: BoardEdge, at v: Int, board: Board, level: GameLevel) -> Bool {
        if let leg = board.node(e.a)?.leg { return level.legs[leg].arrowIntoDiagram }
        return e.b == v
    }

    static func check(_ board: Board, level: GameLevel) -> GameCheck {
        var problems: [GameProblem] = []

        for n in board.nodes {
            if let leg = n.leg, board.edges(at: n.id).isEmpty {
                problems.append(GameProblem(message: "\(level.legs[leg].symbol) isn't connected to anything yet.", nodes: [n.id]))
            }
        }

        // W charge flowing out of each vertex along its W line, for checking both ends agree.
        var wOutflow: [Int: Double] = [:]

        for v in board.vertices {
            let legs = board.edges(at: v.id)
            if legs.count != 3 {
                problems.append(GameProblem(message: "This vertex has \(legs.count) line\(legs.count == 1 ? "" : "s"). Every vertex needs exactly three.", nodes: [v.id]))
                continue
            }
            let fermions = legs.filter { $0.species.isFermion }
            let bosons = legs.filter { !$0.species.isFermion }
            let names = legs.map { $0.species.symbol() }.joined(separator: ", ")
            let bad = { (msg: String) in problems.append(GameProblem(message: msg, nodes: [v.id], edges: legs.map(\.id))) }

            if fermions.isEmpty {
                if bosons.allSatisfy({ $0.species == .gluon }) { continue }
                if bosons.allSatisfy({ $0.species == .photon }) {
                    bad("Photons have no charge, so no vertex joins photons to each other.")
                } else {
                    bad("This game has no vertex joining \(names).")
                }
                continue
            }
            guard fermions.count == 2, bosons.count == 1 else {
                bad(fermions.count == 1 || fermions.count == 3
                    ? "A fermion line can't start or end at a vertex: each vertex needs fermion lines in pairs, one in and one out."
                    : "This game has no vertex joining \(names).")
                continue
            }
            let ins = fermions.filter { arrowIn($0, at: v.id, board: board, level: level) }
            guard ins.count == 1 else {
                bad(ins.count == 2
                    ? "Both fermion arrows point into this vertex. One must come in and one must go out. Tap an internal line and flip its arrow."
                    : "Both fermion arrows point out of this vertex. One must come in and one must go out. Tap an internal line and flip its arrow.")
                continue
            }
            let fin = ins[0].species
            let fout = fermions.first { !arrowIn($0, at: v.id, board: board, level: level) }!.species
            let boson = bosons[0]

            switch boson.species {
            case .photon:
                if fin != fout { bad("A photon can't change \(fin.aName) into \(fout.aName). Only the W changes flavor.") }
                else if fin.isNeutrino { bad("Neutrinos have no electric charge, so they don't couple to photons.") }
            case .gluon:
                if fin != fout { bad("A gluon can't change \(fin.aName) into \(fout.aName).") }
                else if !fin.isColored { bad("Gluons couple only to quarks (color charge). \(fin.aName.prefix(1).uppercased() + fin.aName.dropFirst()) has no color.") }
            case .higgs:
                if fin != fout { bad("The Higgs can't change \(fin.aName) into \(fout.aName).") }
                else if fin.isNeutrino { bad("In this game neutrinos are massless, so they don't couple to the Higgs.") }
            case .w:
                if fin.weakPartner != fout {
                    bad("The W only connects weak partners (e↔νₑ, μ↔νμ, u↔d). It can't turn \(fin.aName) into \(fout.aName).")
                } else if board.node(boson.a)?.isVertex == true && board.node(boson.b)?.isVertex == true {
                    wOutflow[v.id] = fin.charge - fout.charge
                }
            default:
                bad("This game has no vertex joining \(names).")
            }
        }

        // A W line carries the same charge out of one end as into the other.
        for e in board.internalEdges where e.species == .w {
            if let qa = wOutflow[e.a], let qb = wOutflow[e.b], abs(qa + qb) > 0.01 {
                problems.append(GameProblem(
                    message: "Charge isn't conserved along this W: one end sends out charge \(chargeText(qa)), the other sends out \(chargeText(qb)). They have to cancel.",
                    nodes: [e.a, e.b], edges: [e.id]))
            }
        }

        // Everything must be one connected diagram.
        var parent = Dictionary(uniqueKeysWithValues: board.nodes.map { ($0.id, $0.id) })
        func find(_ x: Int) -> Int { var x = x; while parent[x] != x { x = parent[x]! }; return x }
        for e in board.edges { parent[find(e.a)] = find(e.b) }
        let roots = Set(board.nodes.map { find($0.id) })
        if roots.count > 1 && problems.isEmpty {
            problems.append(GameProblem(message: "The diagram is in separate pieces. Everything has to connect into one diagram."))
        }

        let v = board.vertices.count
        return GameCheck(problems: problems, vertexCount: v, loops: max(0, board.internalEdges.count - v + 1))
    }

    static func stars(for check: GameCheck, level: GameLevel) -> Int {
        guard check.isValid, let par = level.par else { return 0 }
        if check.vertexCount <= par { return 3 }
        if check.vertexCount <= par + 2 { return 2 }
        return 1
    }
}
