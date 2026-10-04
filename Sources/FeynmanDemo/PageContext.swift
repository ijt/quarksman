import SwiftUI

/// A plain-text description of what the user is looking at, for the "Ask" assistant.
struct PageContext: Equatable {
    var title: String
    var body: String
    var suggestions: [String] = []

    static let empty = PageContext(title: "", body: "")
}

struct PageContextKey: PreferenceKey {
    static let defaultValue = PageContext.empty
    static func reduce(value: inout PageContext, nextValue: () -> PageContext) {
        let next = nextValue()
        if !next.title.isEmpty { value = next }
    }
}

extension View {
    func pageContext(_ context: PageContext) -> some View {
        preference(key: PageContextKey.self, value: context)
    }
}

extension Diagram {
    /// Everything on the diagram page, including what the user has selected or scrubbed to.
    func contextText(selection: DiagramSelection?, time: CGFloat?) -> String {
        var lines: [String] = [
            "Diagram: \(title) — process \(process) (\(interaction.title)).",
            "Time runs left to right. \(vertices.count) vertices, \(internalEdges.count) internal lines, \(loops) loop(s).",
            "Summary: \(summary)",
        ]
        if let primer { lines.append("Primer box \"\(primer.title)\": " + primer.paragraphs.joined(separator: " ")) }
        lines += details.map { "• " + $0 }
        lines.append("Amplitude shown: \(amplitude)")
        lines.append("Lines:")
        for e in edges {
            let role = FeynmanRules.role(of: e, in: self)
            let rule = FeynmanRules.rule(for: e, in: self)
            lines.append("  - \(e.label) (\(e.particle.name)), \(role), \(node(e.from).id)→\(node(e.to).id); rule \(rule.formula)")
        }
        for v in vertices {
            let rule = FeynmanRules.rule(forVertex: v.id, in: self)
            let legs = edges(at: v.id).map(\.label).joined(separator: ", ")
            lines.append("  - vertex \(v.id): \(rule.title) joining \(legs); rule \(rule.formula)")
        }
        switch selection {
        case .edge(let id):
            let e = edges[id]
            lines.append("The user has selected the line \(e.label) (\(e.particle.name), \(FeynmanRules.role(of: e, in: self))).")
        case .vertex(let id):
            lines.append("The user has selected vertex \(id) (\(FeynmanRules.rule(forVertex: id, in: self).title)).")
        case .none:
            break
        }
        if let time {
            let present = edgesCrossing(time: time).map { $0.label + (isInternal($0) ? " (virtual)" : "") }
            lines.append("Time slice at \(Int(time * 100))% across the diagram; particles present: \(present.isEmpty ? "none (at a vertex)" : present.joined(separator: ", ")).")
        }
        return lines.joined(separator: "\n")
    }
}
