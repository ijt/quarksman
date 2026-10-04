import SwiftUI

struct QuizQuestion {
    let diagram: Diagram
    let prompt: String
    let options: [String]
    let answer: String
    let explanation: String
    var hideLabels = false

    static func random() -> QuizQuestion {
        let d = Diagram.catalog.randomElement()!
        let v = d.vertices.count, i = d.internalEdges.count
        switch Int.random(in: 0..<5) {
        case 0:
            return QuizQuestion(
                diagram: d, prompt: "How many vertices does this diagram have?",
                options: ["2", "3", "4", "5"], answer: "\(v)",
                explanation: "Count the dots where lines meet: V = \(v). The amplitude carries \(v) powers of the coupling.")
        case 1:
            return QuizQuestion(
                diagram: d, prompt: "How many loops does this diagram have?",
                options: ["0 (tree)", "1", "2"], answer: d.loops == 0 ? "0 (tree)" : "\(d.loops)",
                explanation: "L = I − V + 1 = \(i) − \(v) + 1 = \(d.loops).")
        case 2:
            return QuizQuestion(
                diagram: d, prompt: "Which interaction is this diagram mainly about?",
                options: Interaction.allCases.map(\.title), answer: d.interaction.title,
                explanation: "Look at the boson lines: wavy = photon, curly = gluon, long wavy = W/Z, dashed = Higgs. This one is \(d.title).")
        case 3:
            let others = Set(Diagram.catalog.map(\.process)).subtracting([d.process]).shuffled().prefix(3)
            return QuizQuestion(
                diagram: d, prompt: "Which process is this? (labels hidden)",
                options: ([d.process] + others).shuffled(), answer: d.process,
                explanation: "\(d.title): \(d.summary)", hideLabels: true)
        default:
            return QuizQuestion(
                diagram: d, prompt: "How many virtual (internal) lines are there?",
                options: ["1", "2", "3", "4"], answer: "\(i)",
                explanation: "Internal lines connect two vertices. Here there are \(i).")
        }
    }
}

struct QuizView: View {
    @State private var question = QuizQuestion.random()
    @State private var chosen: String?
    @State private var score = 0
    @State private var asked = 0

    var body: some View {
        FindableScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Quiz").font(.largeTitle.bold()).hiddenOnIOS()
                    Spacer()
                    Text("Score: \(score) / \(asked)").font(.title3.monospacedDigit()).foregroundStyle(.secondary)
                }

                DiagramCard {
                    DiagramView(diagram: question.diagram, showLabels: !question.hideLabels).adaptiveHeight(320, compact: 240)
                }
                .frame(maxWidth: 760)

                ProseText(question.prompt, markdown: false).font(.title2.bold()).textSelection(.enabled)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(question.options, id: \.self) { option in
                        Button { choose(option) } label: {
                            HStack {
                                Text(option).font(.system(.body, design: .serif))
                                Spacer()
                                if chosen != nil, option == question.answer {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else if chosen == option {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: 420)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.background.secondary))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                        }
                        .buttonStyle(.plain)
                        .disabled(chosen != nil)
                    }
                }

                if let chosen {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(chosen == question.answer ? "Correct!" : "Not quite — the answer is \(question.answer).",
                              systemImage: chosen == question.answer ? "star.fill" : "info.circle")
                            .font(.headline)
                            .foregroundStyle(chosen == question.answer ? .green : .orange)
                        ProseText(question.explanation, markdown: false).frame(maxWidth: 600, alignment: .leading).textSelection(.enabled)
                        Button("Next question") { next() }
                            .keyboardShortcut(.return, modifiers: [])
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(28)
        }
        .navigationTitle("Quiz")
        .pageContext(PageContext(
            title: "Quiz",
            body: """
            Quiz page. Current question: "\(question.prompt)" about this diagram:
            \(question.diagram.contextText(selection: nil, time: nil))
            Options: \(question.options.joined(separator: " | ")).
            """ + (chosen == nil
                ? "\nThe student hasn't answered yet. Give hints, but don't reveal the answer or which option is correct."
                : "\nThe student answered \"\(chosen!)\"; the correct answer is \"\(question.answer)\". \(question.explanation)"),
            suggestions: chosen == nil
                ? ["Can you give me a hint?", "How do I count loops?"]
                : ["Why is that the answer?", "Give me a harder question like this one."]))
    }

    private func choose(_ option: String) {
        chosen = option
        asked += 1
        if option == question.answer { score += 1 }
    }

    private func next() {
        chosen = nil
        question = QuizQuestion.random()
    }
}
