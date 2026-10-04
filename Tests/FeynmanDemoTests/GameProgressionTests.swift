import XCTest
@testable import FeynmanDemo

final class GameProgressionTests: XCTestCase {
    func testParticlesAreIntroducedGradually() {
        let introduced = GameLevel.all.indices.map { GameLevel.introduced(at: $0) }
        XCTAssertEqual(introduced[0], [.e, .photon])
        XCTAssertEqual(introduced[1], [.mu])
        XCTAssertEqual(Set(introduced[4]), [.nuE, .nuMu, .w])
        XCTAssertEqual(Set(introduced[5]), [.u, .d])
        XCTAssertEqual(introduced[6], [.gluon])
        XCTAssertEqual(Set(introduced[8]), [.t, .higgs])
    }

    func testEveryParticleIsIntroducedExactlyOnce() {
        let all = GameLevel.all.indices.flatMap { GameLevel.introduced(at: $0) }
        XCTAssertEqual(all.count, Set(all).count)
        XCTAssertEqual(Set(all), Set(Species.allCases))
    }

    func testVirtualLinesAreStarredWithoutChargeSigns() {
        XCTAssertEqual(Species.e.virtualSymbol, "e*")
        XCTAssertEqual(Species.mu.virtualSymbol, "μ*")
        XCTAssertEqual(Species.photon.virtualSymbol, "γ*")
        XCTAssertEqual(Species.t.virtualSymbol, "t*")
        XCTAssertTrue(Species.allCases.allSatisfy { $0.virtualSymbol.hasSuffix("*") })
    }
}
