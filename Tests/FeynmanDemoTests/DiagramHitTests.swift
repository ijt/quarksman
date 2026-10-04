import XCTest
@testable import FeynmanDemo

final class DiagramHitTests: XCTestCase {
    /// Clicking the middle of each line selects that line, for every catalog diagram.
    func testClickingALineSelectsIt() {
        for d in Diagram.catalog {
            let layout = DiagramLayout(diagram: d, size: CGSize(width: 700, height: 360))
            for e in d.edges {
                let g = layout.geometry(e)
                let mid = g.locate(g.length / 2).point
                XCTAssertEqual(layout.hitTest(mid), .edge(e.id), "\(d.title): clicking \(e.label) (\(e.from)→\(e.to))")
            }
        }
    }
}
