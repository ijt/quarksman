import XCTest
@testable import FeynmanDemo

/// Builds boards for game levels and checks them against the rules.
final class GameRulesTests: XCTestCase {
    /// Board for `level` with `vertexCount` vertices. External nodes have ids 0..<legs (incoming first, then outgoing,
    /// in level order); vertices follow.
    private func board(_ levelID: String, vertices vertexCount: Int) -> (Board, GameLevel, [Int]) {
        let level = GameLevel.all.first { $0.id == levelID }!
        var b = Board(level: level)
        let vs = (0..<vertexCount).map { b.add(x: 0.3 + 0.2 * CGFloat($0), y: 0.5) }
        return (b, level, vs)
    }

    private func link(_ b: inout Board, _ level: GameLevel, _ p: Int, _ q: Int, _ s: Species = .photon) {
        XCTAssertNil(b.connect(p, q, internalSpecies: s, level: level))
    }

    private func assertValid(_ b: Board, _ level: GameLevel, vertices: Int, loops: Int = 0, stars: Int = 3,
                             file: StaticString = #filePath, line: UInt = #line) {
        let c = GameRules.check(b, level: level)
        XCTAssertTrue(c.isValid, c.problems.map(\.message).joined(separator: "; "), file: file, line: line)
        XCTAssertEqual(c.vertexCount, vertices, file: file, line: line)
        XCTAssertEqual(c.loops, loops, file: file, line: line)
        XCTAssertEqual(GameRules.stars(for: c, level: level), stars, file: file, line: line)
    }

    private func assertInvalid(_ b: Board, _ level: GameLevel, containing text: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        let c = GameRules.check(b, level: level)
        XCTAssertFalse(c.isValid, file: file, line: line)
        XCTAssertTrue(c.problems.contains { $0.message.contains(text) },
                      "Expected a problem mentioning \"\(text)\", got: \(c.problems.map(\.message))", file: file, line: line)
    }

    func testMollerWithPhotonExchange() {
        var (b, l, v) = board("repel", vertices: 2)   // e⁻(0) e⁻(1) → e⁻(2) e⁻(3)
        link(&b, l, 0, v[0]); link(&b, l, 2, v[0])
        link(&b, l, 1, v[1]); link(&b, l, 3, v[1])
        link(&b, l, v[0], v[1], .photon)
        assertValid(b, l, vertices: 2)
    }

    func testAnnihilationAndFlavorMixingAtPhotonVertex() {
        var (b, l, v) = board("annihilate", vertices: 2)   // e⁻(0) e⁺(1) → μ⁻(2) μ⁺(3)
        link(&b, l, 0, v[0]); link(&b, l, 1, v[0])
        link(&b, l, 2, v[1]); link(&b, l, 3, v[1])
        link(&b, l, v[0], v[1])
        assertValid(b, l, vertices: 2)

        var (bad, _, w) = board("annihilate", vertices: 2)
        link(&bad, l, 0, w[0]); link(&bad, l, 2, w[0])   // e⁻ in, μ⁻ out at one photon vertex
        link(&bad, l, 1, w[1]); link(&bad, l, 3, w[1])
        link(&bad, l, w[0], w[1])
        assertInvalid(bad, l, containing: "can't change an electron into a muon")
    }

    func testComptonNeedsInternalArrowInTheRightDirection() {
        var (b, l, v) = board("compton", vertices: 2)   // e⁻(0) γ(1) → e⁻(2) γ(3)
        link(&b, l, 0, v[0]); link(&b, l, 1, v[0])
        link(&b, l, 2, v[1]); link(&b, l, 3, v[1])
        link(&b, l, v[0], v[1], .e)
        assertValid(b, l, vertices: 2)

        b.flip(b.edges.last!.id)
        assertInvalid(b, l, containing: "Both fermion arrows point")
    }

    func testPairProductionRunsTheFermionLineBackward() {
        var (b, l, v) = board("pair", vertices: 2)   // γ(0) γ(1) → e⁻(2) e⁺(3)
        link(&b, l, 0, v[0]); link(&b, l, 2, v[0])
        link(&b, l, 1, v[1]); link(&b, l, 3, v[1])
        link(&b, l, v[1], v[0], .e)   // arrow from the e⁺ vertex to the e⁻ vertex
        assertValid(b, l, vertices: 2)
    }

    func testMuonAndBetaDecayThroughW() {
        for id in ["muon", "beta"] {   // f(0) → f′(1) e⁻(2) ν̄ₑ(3)
            var (b, l, v) = board(id, vertices: 2)
            link(&b, l, 0, v[0]); link(&b, l, 1, v[0])
            link(&b, l, 2, v[1]); link(&b, l, 3, v[1])
            link(&b, l, v[0], v[1], .w)
            assertValid(b, l, vertices: 2)

            b.edges[b.edges.count - 1].species = .photon
            assertInvalid(b, l, containing: "Only the W changes flavor")
        }
    }

    func testWChargeMustMatchAtBothEnds() {
        // d → u e⁺ νₑ: the quark end emits W⁻ but the lepton end would need W⁺.
        let level = GameLevel(id: "test", title: "", goal: "", legs: [.into(.d), .out(.u), .out(.e, anti: true), .out(.nuE)],
                              palette: [.w], par: 2, hint: "", lesson: "")
        var b = Board(level: level)
        let v0 = b.add(x: 0.4, y: 0.5), v1 = b.add(x: 0.6, y: 0.5)
        link(&b, level, 0, v0); link(&b, level, 1, v0)
        link(&b, level, 2, v1); link(&b, level, 3, v1)
        link(&b, level, v0, v1, .w)
        assertInvalid(b, level, containing: "Charge isn't conserved along this W")
    }

    func testQuarksScatterByGluonOrPhoton() {
        for s in [Species.gluon, .photon] {
            var (b, l, v) = board("strong", vertices: 2)
            link(&b, l, 0, v[0]); link(&b, l, 2, v[0])
            link(&b, l, 1, v[1]); link(&b, l, 3, v[1])
            link(&b, l, v[0], v[1], s)
            assertValid(b, l, vertices: 2)
        }
    }

    func testGluonsCoupleToGluonsButPhotonsDoNot() {
        var (b, l, v) = board("glue", vertices: 2)
        link(&b, l, 0, v[0]); link(&b, l, 1, v[0])
        link(&b, l, 2, v[1]); link(&b, l, 3, v[1])
        link(&b, l, v[0], v[1], .gluon)
        assertValid(b, l, vertices: 2)

        b.edges[b.edges.count - 1].species = .photon
        assertInvalid(b, l, containing: "This game has no vertex joining")
    }

    func testHiggsToPhotonsNeedsATopLoop() {
        var (b, l, v) = board("higgs", vertices: 3)   // H(0) → γ(1) γ(2)
        link(&b, l, 0, v[0]); link(&b, l, 1, v[1]); link(&b, l, 2, v[2])
        link(&b, l, v[0], v[1], .t); link(&b, l, v[1], v[2], .t); link(&b, l, v[2], v[0], .t)
        assertValid(b, l, vertices: 3, loops: 1)
    }

    func testMuonToElectronPhotonFailsAtTheVertex() {
        var (b, l, v) = board("lfv", vertices: 1)   // μ⁻(0) → e⁻(1) γ(2)
        link(&b, l, 0, v[0]); link(&b, l, 1, v[0]); link(&b, l, 2, v[0])
        assertInvalid(b, l, containing: "can't change a muon into an electron")
    }

    func testIncompleteDiagramsAreRejected() {
        var (b, l, v) = board("repel", vertices: 2)
        link(&b, l, 0, v[0]); link(&b, l, 2, v[0])
        assertInvalid(b, l, containing: "isn't connected to anything yet")
        assertInvalid(b, l, containing: "Every vertex needs exactly three")
    }

    func testConnectionRules() {
        var (b, l, v) = board("repel", vertices: 1)
        XCTAssertNotNil(b.connect(0, 2, internalSpecies: .photon, level: l), "externals can't join directly")
        link(&b, l, 0, v[0])
        XCTAssertNotNil(b.connect(0, v[0], internalSpecies: .photon, level: l), "an external connects only once")
        link(&b, l, 1, v[0]); link(&b, l, 2, v[0])
        XCTAssertNotNil(b.connect(3, v[0], internalSpecies: .photon, level: l), "a vertex holds at most three lines")
    }
}
