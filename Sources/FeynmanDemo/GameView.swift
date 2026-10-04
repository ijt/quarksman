import SwiftUI

enum BoardSelection: Equatable {
    case node(Int)
    case edge(Int)
}

@MainActor @Observable
final class GameModel {
    private(set) var levelIndex = 0
    private(set) var board: Board
    private var history: [Board] = []
    var internalSpecies: Species = .photon
    var selection: BoardSelection?
    private(set) var check: GameCheck?
    /// Set when the player pressed "It can't happen" on a possible level.
    private(set) var wrongImpossibleGuess = false
    private(set) var notice: String?
    private(set) var stars: [String: Int]

    private static let starsKey = "gameStars"

    var level: GameLevel { GameLevel.all[levelIndex] }
    var solved: Bool { check?.isValid == true }
    var canUndo: Bool { !history.isEmpty }

    init() {
        board = Board(level: GameLevel.all[0])
        stars = (UserDefaults.standard.dictionary(forKey: Self.starsKey) as? [String: Int]) ?? [:]
        internalSpecies = GameLevel.all[0].palette[0]
    }

    func go(to index: Int) {
        levelIndex = min(max(index, 0), GameLevel.all.count - 1)
        board = Board(level: level)
        history = []
        selection = nil
        check = nil
        notice = nil
        wrongImpossibleGuess = false
        internalSpecies = level.palette[0]
    }

    private func change(_ body: (inout Board) -> String?) {
        var next = board
        if let reason = body(&next) {
            notice = reason
            return
        }
        guard next != board else { return }
        history.append(board)
        board = next
        check = nil
        notice = nil
        wrongImpossibleGuess = false
    }

    func addVertex(x: CGFloat, y: CGFloat) {
        change { $0.add(x: x, y: y); return nil }
    }

    func connect(_ a: Int, _ b: Int) {
        change { $0.connect(a, b, internalSpecies: internalSpecies, level: level) }
    }

    /// Drag from a node into empty space: a new vertex joined to that node.
    func extend(from a: Int, x: CGFloat, y: CGFloat) {
        change { board in
            let v = board.add(x: x, y: y)
            return board.connect(a, v, internalSpecies: internalSpecies, level: level)
        }
    }

    func deleteSelection() {
        switch selection {
        case .node(let id): change { $0.removeNode(id); return nil }
        case .edge(let id): change { $0.removeEdge(id); return nil }
        case nil: break
        }
        selection = nil
    }

    func flipSelection() {
        if case .edge(let id) = selection { change { $0.flip(id); return nil } }
    }

    /// Picking a particle while an internal line is selected changes that line.
    func choose(_ species: Species) {
        internalSpecies = species
        if case .edge(let id) = selection, let e = board.edges.first(where: { $0.id == id }),
           board.node(e.a)?.isVertex == true {
            change { b in
                if let i = b.edges.firstIndex(where: { $0.id == id }) { b.edges[i].species = species }
                return nil
            }
        }
    }

    func undo() {
        guard let last = history.popLast() else { return }
        board = last
        selection = nil
        check = nil
        notice = nil
    }

    func clear() {
        change { b in b = Board(level: level); return nil }
        selection = nil
    }

    func runCheck() {
        let result = GameRules.check(board, level: level)
        notice = nil
        wrongImpossibleGuess = false
        if level.impossible && result.isValid {
            // Can't happen with these rules, so a "valid" board here would be a bug in the checker.
            check = GameCheck(problems: [GameProblem(message: "Hmm, that passed the rules. This level should be impossible, so please report it!")], vertexCount: result.vertexCount, loops: result.loops)
            return
        }
        check = result
        let earned = GameRules.stars(for: result, level: level)
        if earned > (stars[level.id] ?? 0) { record(earned) }
    }

    func claimImpossible() {
        if level.impossible {
            check = GameCheck(problems: [], vertexCount: 0, loops: 0)
            record(3)
        } else {
            wrongImpossibleGuess = true
            check = nil
        }
    }

    private func record(_ earned: Int) {
        stars[level.id] = max(earned, stars[level.id] ?? 0)
        UserDefaults.standard.set(stars, forKey: Self.starsKey)
    }

    var earnedStars: Int {
        guard let check, check.isValid else { return 0 }
        return level.impossible ? 3 : GameRules.stars(for: check, level: level)
    }

    /// A text description of the board for the Ask panel.
    var contextText: String {
        var lines = [
            "Diagram-building game, level \(levelIndex + 1) of \(GameLevel.all.count): \"\(level.title)\" — \(level.processText).",
            "Goal: \(level.goal)",
            "Rules: tap to add vertices, drag between dots to draw lines; internal lines use the chosen particle (\(level.palette.map { $0.symbol() }.joined(separator: ", ")) available). Every vertex joins exactly three lines; only Standard Model vertices count (f f γ for charged f, q q g, g g g, f f H, and the W between weak partners e↔νₑ, μ↔νμ, u↔d); fermion arrows go in and out; charge is conserved. Fewer vertices is better (par \(level.par.map(String.init) ?? "n/a")).",
            level.impossible ? "This is a trick level; the player can press \"It can't happen\"." : "",
            "Current board: \(board.vertices.count) vertices.",
        ]
        let label: (Int) -> String = { id in
            guard let n = self.board.node(id) else { return "?" }
            if let leg = n.leg { return "external \(self.level.legs[leg].symbol) (\(self.level.legs[leg].incoming ? "in" : "out"))" }
            return "vertex #\(self.board.vertices.firstIndex(of: n).map { $0 + 1 } ?? 0)"
        }
        for e in board.edges {
            let arrow = e.species.isFermion && board.node(e.a)?.isVertex == true ? " (arrow \(label(e.a)) → \(label(e.b)))" : ""
            lines.append("  - \(e.species.name) line between \(label(e.a)) and \(label(e.b))\(arrow)")
        }
        if let check {
            lines.append(check.isValid ? "Last check: valid with \(check.vertexCount) vertices and \(check.loops) loop(s)."
                                       : "Last check found problems: " + check.problems.map(\.message).joined(separator: " | "))
        }
        lines.append("Help the player reason it out. Give hints rather than the full solution unless they ask for it.")
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

// MARK: - Views

struct GameView: View {
    @State private var game = GameModel()

    var body: some View {
        FindableScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                DiagramCard {
                    GameBoardView(game: game).adaptiveHeight(400, compact: 300)
                }
                palette
                controls
                feedback
                howToPlay
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle("Diagram Builder")
        .pageContext(PageContext(
            title: "Diagram Builder",
            body: game.contextText,
            suggestions: game.solved
                ? ["Why does this diagram work?", "Is there another valid diagram for this process?"]
                : ["Give me a hint without the answer.", "What's wrong with my diagram?"]))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Level \(game.levelIndex + 1) of \(GameLevel.all.count)").font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach(Array(GameLevel.all.enumerated()), id: \.element.id) { i, level in
                        Button("\(i + 1). \(level.title)  \(String(repeating: "★", count: game.stars[level.id] ?? 0))") { game.go(to: i) }
                    }
                } label: {
                    Label("Levels", systemImage: "list.number")
                }
                .fixedSize()
            }
            ProseText(game.level.title, markdown: false).font(.title.bold())
            ProseText(game.level.processText, markdown: false).font(.system(size: 26, design: .serif))
            ProseText(game.level.goal, markdown: false).foregroundStyle(.secondary)
        }
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedInternalEdge ? "Change the selected line to:" : "New lines between vertices are:")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(game.level.palette, id: \.self) { s in
                        Button { game.choose(s) } label: {
                            HStack(spacing: 6) {
                                LineSample(style: s.style).frame(width: 64, height: 22)
                                Text(s.symbol()).font(.system(.body, design: .serif).weight(.semibold))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(game.internalSpecies == s ? Color.accentColor.opacity(0.2) : Color.clear))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(game.internalSpecies == s ? Color.accentColor : Color.secondary.opacity(0.3)))
                        }
                        .buttonStyle(.plain)
                        .help(s.name)
                    }
                }
            }
        }
    }

    private var selectedInternalEdge: Bool {
        guard case .edge(let id) = game.selection, let e = game.board.edges.first(where: { $0.id == id }) else { return false }
        return game.board.node(e.a)?.isVertex == true
    }

    private var controls: some View {
        AdaptiveStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("Check") { game.runCheck() }
                    .buttonStyle(.borderedProminent)
                Button("It can't happen") { game.claimImpossible() }
                    .buttonStyle(.bordered)
            }
            HStack(spacing: 8) {
                if game.selection != nil {
                    if selectedInternalEdge, case .edge(let id) = game.selection,
                       game.board.edges.first(where: { $0.id == id })?.species.isFermion == true {
                        Button { game.flipSelection() } label: { Label("Flip arrow", systemImage: "arrow.left.arrow.right") }
                    }
                    Button(role: .destructive) { game.deleteSelection() } label: { Label("Delete", systemImage: "trash") }
                }
                Button { game.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(!game.canUndo)
                Button { game.clear() } label: { Label("Clear", systemImage: "eraser") }
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder private var feedback: some View {
        if let notice = game.notice {
            Label(notice, systemImage: "hand.raised").foregroundStyle(.orange)
        }
        if game.wrongImpossibleGuess {
            VStack(alignment: .leading, spacing: 6) {
                Label("It can happen! Keep building.", systemImage: "arrow.uturn.left").font(.headline).foregroundStyle(.orange)
                ProseText("Hint: \(game.level.hint)", markdown: false)
            }
        }
        if let check = game.check {
            if check.isValid {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(repeating: "★", count: game.earnedStars) + String(repeating: "☆", count: 3 - game.earnedStars))
                            .font(.title2).foregroundStyle(.yellow)
                        Text(game.level.impossible ? "Right!" : "Valid diagram: \(check.vertexCount) vertices, \(check.loops) loop\(check.loops == 1 ? "" : "s").")
                            .font(.headline)
                    }
                    if !game.level.impossible, let par = game.level.par, check.vertexCount > par {
                        ProseText("It works, but it can be done with \(par) vertices. Each extra pair of vertices makes the process about 1/137 as likely in QED, so the simplest diagram dominates.", markdown: false)
                            .foregroundStyle(.secondary)
                    }
                    ProseText(game.level.lesson, markdown: false)
                    if game.levelIndex + 1 < GameLevel.all.count {
                        Button("Next level") { game.go(to: game.levelIndex + 1) }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Text("That's every level. Nicely done!").font(.headline)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.12)))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Not quite", systemImage: "exclamationmark.triangle").font(.headline).foregroundStyle(.orange)
                    ForEach(check.problems) { p in
                        ProseText("• " + p.message, markdown: false)
                    }
                    ProseText("Hint: \(game.level.hint)", markdown: false).foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
            }
        }
    }

    private var howToPlay: some View {
        DisclosureGroup("How to play") {
            VStack(alignment: .leading, spacing: 4) {
                ProseText("• **Tap** empty space to add a vertex.")
                ProseText("• **Drag** from one dot to another to draw a line. Drag from a dot into empty space to add a new vertex already connected to it.")
                ProseText("• Lines to the particles at the edges take that particle automatically. Lines between two vertices use the particle chosen below the board.")
                ProseText("• **Tap a line** to select it: flip its arrow, delete it, or pick a new particle for it. Tap a vertex to select and delete it.")
                ProseText("• A fermion's arrow on an internal line points the way you drew it.")
                ProseText("• Press **Check** when you're done. Fewer vertices earns more stars.")
            }
            .font(.callout)
            .padding(.top, 4)
        }
    }
}

/// The interactive board: external particles on the edges, vertices and lines in between.
struct GameBoardView: View {
    let game: GameModel
    @State private var dragFrom: Int?
    @State private var dragPoint: CGPoint?

    private let aspect: CGFloat = 1.6

    var body: some View {
        GeometryReader { geo in
            let frame = Self.frame(in: geo.size, aspect: aspect)
            Canvas { ctx, _ in draw(&ctx, frame: frame) }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            if dragFrom == nil, hypot(v.translation.width, v.translation.height) > 6 {
                                dragFrom = nodeHit(v.startLocation, frame: frame) ?? -1
                            }
                            dragPoint = v.location
                        }
                        .onEnded { v in
                            defer { dragFrom = nil; dragPoint = nil }
                            if hypot(v.translation.width, v.translation.height) <= 6 {
                                tap(v.startLocation, frame: frame)
                            } else if let from = dragFrom, from >= 0 {
                                if let to = nodeHit(v.location, frame: frame), to != from {
                                    game.connect(from, to)
                                } else if frame.insetBy(dx: -4, dy: -4).contains(v.location) {
                                    let p = unit(v.location, frame: frame)
                                    game.extend(from: from, x: p.x, y: p.y)
                                }
                            }
                        }
                )
        }
    }

    static func frame(in size: CGSize, aspect: CGFloat) -> CGRect {
        let inset: CGFloat = 26
        var w = size.width - 2 * inset, h = size.height - 2 * inset
        if w / h > aspect { w = h * aspect } else { h = w / aspect }
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    private func point(_ n: BoardNode, frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX + n.x * frame.width, y: frame.minY + n.y * frame.height)
    }

    private func unit(_ p: CGPoint, frame: CGRect) -> CGPoint {
        CGPoint(x: min(max((p.x - frame.minX) / frame.width, 0.1), 0.9), y: min(max((p.y - frame.minY) / frame.height, 0.03), 0.97))
    }

    private func nodeHit(_ p: CGPoint, frame: CGRect) -> Int? {
        game.board.nodes
            .map { ($0.id, hypot(point($0, frame: frame).x - p.x, point($0, frame: frame).y - p.y)) }
            .filter { $0.1 < 20 }
            .min { $0.1 < $1.1 }?.0
    }

    private func geometry(_ e: BoardEdge, frame: CGRect) -> EdgeGeometry? {
        guard let na = game.board.node(e.a), let nb = game.board.node(e.b) else { return nil }
        // Parallel lines between the same two vertices bow apart so both stay visible.
        let siblings = game.board.edges.filter { Set([$0.a, $0.b]) == Set([e.a, e.b]) }.sorted { $0.id < $1.id }
        var bend: CGFloat = 0
        if siblings.count > 1, let i = siblings.firstIndex(of: e) {
            bend = (CGFloat(i) - CGFloat(siblings.count - 1) / 2) * 0.5
            if e.a > e.b { bend = -bend }
        }
        return EdgeGeometry(from: point(na, frame: frame), to: point(nb, frame: frame), bend: bend)
    }

    private func edgeHit(_ p: CGPoint, frame: CGRect) -> Int? {
        game.board.edges
            .compactMap { e in geometry(e, frame: frame).map { (e.id, $0.distance(to: p)) } }
            .filter { $0.1 < 12 }
            .min { $0.1 < $1.1 }?.0
    }

    private func tap(_ p: CGPoint, frame: CGRect) {
        if let id = nodeHit(p, frame: frame) {
            game.selection = game.board.node(id)?.isVertex == true ? .node(id) : nil
        } else if let id = edgeHit(p, frame: frame) {
            game.selection = .edge(id)
        } else if game.selection != nil {
            game.selection = nil
        } else if frame.insetBy(dx: -4, dy: -4).contains(p) {
            let u = unit(p, frame: frame)
            game.addVertex(x: u.x, y: u.y)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, frame: CGRect) {
        let board = game.board, level = game.level
        let problemNodes = Set(game.check?.problems.flatMap(\.nodes) ?? [])
        let problemEdges = Set(game.check?.problems.flatMap(\.edges) ?? [])

        // Time arrow.
        var axis = Path()
        axis.move(to: CGPoint(x: frame.midX - 40, y: frame.maxY + 14))
        axis.addLine(to: CGPoint(x: frame.midX + 40, y: frame.maxY + 14))
        axis.move(to: CGPoint(x: frame.midX + 34, y: frame.maxY + 10))
        axis.addLine(to: CGPoint(x: frame.midX + 40, y: frame.maxY + 14))
        axis.addLine(to: CGPoint(x: frame.midX + 34, y: frame.maxY + 18))
        ctx.stroke(axis, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
        ctx.draw(Text("time").font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: frame.midX + 46, y: frame.maxY + 14), anchor: .leading)

        if board.vertices.isEmpty {
            ctx.draw(Text("Tap to add a vertex · drag between dots to connect").font(.callout).foregroundStyle(.tertiary),
                     at: CGPoint(x: frame.midX, y: frame.midY))
        }

        for e in board.edges {
            guard let g = geometry(e, frame: frame) else { continue }
            let isExternal = board.node(e.a)?.isVertex == false
            var arrow = Arrow.none
            if e.species.isFermion {
                if isExternal, let leg = board.node(e.a)?.leg {
                    arrow = level.legs[leg].arrowIntoDiagram ? .forward : .backward
                } else {
                    arrow = .forward
                }
            }
            if problemEdges.contains(e.id) {
                ctx.stroke(LinePainter.path(e.species.style, g), with: .color(.red.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            }
            LinePainter.draw(e.species.style, arrow: arrow, geometry: g, in: &ctx, selected: game.selection == .edge(e.id))
            if !isExternal {
                let (p, t) = g.locate(g.length / 2)
                let d: CGFloat = e.species.isFermion ? 15 : 19
                ctx.draw(Text(e.species.symbol()).font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundStyle(e.species.style.color),
                         at: CGPoint(x: p.x - t.dy * d, y: p.y + t.dx * d))
            }
        }

        if let from = dragFrom, from >= 0, let n = board.node(from), let to = dragPoint {
            var band = Path()
            band.move(to: point(n, frame: frame))
            band.addLine(to: to)
            ctx.stroke(band, with: .color(.accentColor), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
        }

        for n in board.nodes {
            let p = point(n, frame: frame)
            if let leg = n.leg {
                let l = level.legs[leg]
                let connected = !board.edges(at: n.id).isEmpty
                let ring = Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14))
                ctx.stroke(ring, with: .color(l.species.style.color), lineWidth: connected ? 1 : 2)
                if problemNodes.contains(n.id) {
                    ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 13, y: p.y - 13, width: 26, height: 26)), with: .color(.red.opacity(0.6)), lineWidth: 3)
                }
                ctx.draw(Text(l.symbol).font(.system(size: 17, weight: .semibold, design: .serif)).foregroundStyle(l.species.style.color),
                         at: CGPoint(x: p.x, y: p.y - 18), anchor: .bottom)
            } else {
                if problemNodes.contains(n.id) {
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 13, y: p.y - 13, width: 26, height: 26)), with: .color(.red.opacity(0.35)))
                }
                if game.selection == .node(n.id) {
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)), with: .color(.accentColor.opacity(0.35)))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(.primary))
            }
        }
    }
}
