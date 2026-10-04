import SwiftUI

struct DiagramDetailView: View {
    let diagram: Diagram
    /// Opens another page, for links in the primer.
    var navigate: (Page) -> Void = { _ in }
    @State private var selection: DiagramSelection?
    @State private var time: CGFloat = 0.02
    @State private var showSlice = true
    @State private var playing = false

    var body: some View {
        FindableScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                SidePanelStack(sideWidth: 290, sideMinHeight: 360) {
                    VStack(alignment: .leading, spacing: 10) {
                        DiagramCard {
                            DiagramView(diagram: diagram, timeSlice: showSlice ? time : nil,
                                        selection: selection, onSelect: { selection = $0 })
                                .adaptiveHeight(360, compact: 260)
                        }
                        timeControls
                        if showSlice { stateRow }
                    }
                } side: {
                    SelectionInfoView(diagram: diagram, selection: selection)
                }

                if let primer = diagram.primer { primerBox(primer) }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(diagram.details, id: \.self) { ProseText($0) }
                }
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: 760, alignment: .leading)

                amplitudeBox
                stats
            }
            .padding(24)
        }
        .navigationTitle(diagram.title)
        .pageContext(PageContext(
            title: diagram.title,
            body: diagram.contextText(selection: selection, time: showSlice ? time : nil),
            suggestions: suggestions))
        .task(id: playing) {
            guard playing else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                time += 0.0035
                if time > 1 { time = 0 }
            }
        }
        .onChange(of: diagram.id) {
            selection = nil
            time = 0.02
            playing = false
        }
    }

    private var suggestions: [String] {
        var s = ["Walk me through this diagram step by step.",
                 "Which particles here are virtual, and what does that mean?"]
        switch selection {
        case .edge(let id): s.insert("Explain the Feynman rule for the \(diagram.edges[id].label) line I selected.", at: 0)
        case .vertex: s.insert("What's conserved at the vertex I selected?", at: 0)
        case .none: s.append("How would I compute a cross-section from this?")
        }
        return s
    }

    private func primerBox(_ primer: Primer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(primer.title, systemImage: "lightbulb").font(.headline).foregroundStyle(Color.accentColor)
            ForEach(primer.paragraphs, id: \.self) { ProseText($0) }
            if let link = primer.link {
                Button(link.title) { navigate(link.page) }.linkButtonStyle()
            }
        }
        .padding(14)
        .frame(maxWidth: 760, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor.opacity(0.3)))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label(diagram.interaction.title, systemImage: diagram.interaction.icon)
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(diagram.interaction.color.opacity(0.18)))
                    .foregroundStyle(diagram.interaction.color)
                Text(diagram.loops == 0 ? "Tree level" : "\(diagram.loops)-loop")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.quaternary))
            }
            ProseText(diagram.process, markdown: false).font(.system(size: 30, weight: .semibold, design: .serif))
            ProseText(diagram.summary, markdown: false).font(.title3).foregroundStyle(.secondary)
        }
        .textSelection(.enabled)
    }

    private var timeControls: some View {
        HStack(spacing: 12) {
            Toggle("Time slice", isOn: $showSlice).toggleStyle(.switch).controlSize(.small)
            Button { playing.toggle() } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill").frame(width: 16)
            }
            .disabled(!showSlice)
            Slider(value: $time, in: 0...1) { Text("Time") }
                .labelsHidden()
                .disabled(!showSlice)
        }
    }

    private var stateRow: some View {
        let present = diagram.edgesCrossing(time: time)
        return HStack(spacing: 6) {
            Text("At this instant:").font(.callout).foregroundStyle(.secondary)
            if present.isEmpty {
                Text("(at a vertex)").font(.callout).foregroundStyle(.tertiary)
            }
            ForEach(present) { e in
                let virtual = diagram.isInternal(e)
                Text(e.label + (virtual ? " (virtual)" : ""))
                    .font(.system(.callout, design: .serif).weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(e.particle.style.color.opacity(virtual ? 0.08 : 0.2)))
                    .overlay(Capsule().strokeBorder(e.particle.style.color.opacity(0.5),
                                                    style: StrokeStyle(lineWidth: 1, dash: virtual ? [3, 2] : [])))
            }
            Spacer()
        }
        .animation(.default, value: present.map(\.id))
    }

    private var amplitudeBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Putting the rules together").font(.headline)
            Text("Multiply the factors for every line and vertex to get the amplitude 𝓜. The probability is ∝ |𝓜|².")
                .font(.callout).foregroundStyle(.secondary)
            ProseText(diagram.amplitude, markdown: false)
                .font(.system(size: 16, design: .serif))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var stats: some View {
        let v = diagram.vertices.count
        let i = diagram.internalEdges.count
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            stat("Vertices V", "\(v)", "amplitude ∝ g^\(v)")
            stat("Internal lines I", "\(i)", "virtual particles")
            stat("Loops L = I − V + 1", "\(diagram.loops)", diagram.loops == 0 ? "tree diagram" : "integrate over loop momentum")
            stat("Rate", "∝ g^\(2 * v)", "|𝓜|² doubles the power")
        }
    }

    private func stat(_ title: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold())
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }
}
