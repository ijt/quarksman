import SwiftUI

struct ChatTurn: Identifiable, Equatable, Codable {
    var id = UUID()
    let role: String // "user" or "assistant"
    /// What the user typed (shown in the UI).
    var text: String
    /// What was sent to the API for user turns (question plus page description).
    var sent: String
    var isError = false
}

@MainActor @Observable
final class AskModel {
    /// One conversation per page, so switching pages doesn't mix contexts.
    private(set) var conversations: [String: [ChatTurn]] = [:]
    private(set) var isStreaming = false
    private var task: Task<Void, Never>?
    /// Identifies the in-flight request, so a stopped one can't touch state owned by a newer one.
    private var requestID: UUID?
    /// The reply being streamed, so stopping can mark it if nothing arrived.
    private var pendingReply: (page: String, id: UUID)?

    /// Conversations survive relaunches in ~/Library/Application Support/FeynmanDemo/conversations.json.
    private static let fileURL = URL.applicationSupportDirectory
        .appending(path: "FeynmanDemo", directoryHint: .isDirectory)
        .appending(path: "conversations.json")

    init() {
        load()
        // Keep whatever has streamed so far if the app quits mid-answer.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.save() }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let saved = try? JSONDecoder().decode([String: [ChatTurn]].self, from: data) else { return }
        conversations = saved.mapValues { turns in
            turns.map { turn in
                var turn = turn
                if turn.role == "assistant" && turn.text.isEmpty { Self.markStopped(&turn) }
                return turn
            }
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(conversations).write(to: Self.fileURL, options: .atomic)
        } catch {
            print("Couldn't save conversations: \(error)")
        }
    }

    private static func markStopped(_ turn: inout ChatTurn) {
        turn.text = "Stopped before Claude answered."
        turn.isError = true
    }

    private static let system = """
    You are a friendly physics tutor inside a macOS app that teaches Feynman diagrams. \
    Each question arrives with a description of the page the student is looking at, inside <page> tags; \
    it reflects what's on screen right now (selected lines, time slider, quiz state). Ground your answer in that page.

    Pitch answers at a curious undergraduate unless the student asks for more or less depth. \
    The answer appears in a narrow side panel, so keep it short: usually one to three brief paragraphs. \
    Formatting: **bold**, *italics* and `code` render; headings, tables and LaTeX don't, so write math in \
    plain Unicode (α, γ^μ, q², ∫d⁴k) and use simple "•" lines for lists. \
    If the page says the student hasn't answered a quiz question yet, help them reason without giving away the answer.
    """

    func turns(for page: String) -> [ChatTurn] { conversations[page] ?? [] }

    func clear(page: String) {
        stop()
        conversations[page] = []
        save()
    }

    func stop() {
        guard let pending = pendingReply else { return }
        task?.cancel()
        task = nil
        requestID = nil
        pendingReply = nil
        isStreaming = false
        updateReply(pending.id, on: pending.page) { if $0.text.isEmpty { Self.markStopped(&$0) } }
        save()
    }

    /// Updates a reply by id; does nothing if it was cleared away in the meantime.
    private func updateReply(_ id: UUID, on page: String, _ change: (inout ChatTurn) -> Void) {
        guard let i = conversations[page]?.firstIndex(where: { $0.id == id }) else { return }
        change(&conversations[page]![i])
    }

    func ask(_ question: String, context: PageContext) {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isStreaming else { return }
        let page = context.title
        let sent = "<page title=\"\(context.title)\">\n\(context.body)\n</page>\n\n\(question)"
        conversations[page, default: []].append(ChatTurn(role: "user", text: question, sent: sent))
        let reply = ChatTurn(role: "assistant", text: "", sent: "")
        conversations[page]!.append(reply)

        // Turns alternate user/assistant. Earlier failed or empty exchanges aren't sent back to the API.
        let prior = Array(conversations[page]!.dropLast(2))
        var history: [ClaudeClient.Message] = []
        for i in stride(from: 0, to: prior.count - 1, by: 2) where !prior[i + 1].isError && !prior[i + 1].text.isEmpty {
            history.append(.init(role: "user", content: prior[i].sent))
            history.append(.init(role: "assistant", content: prior[i + 1].text))
        }
        history.append(.init(role: "user", content: sent))

        let request = UUID()
        requestID = request
        pendingReply = (page, reply.id)
        isStreaming = true
        task = Task {
            do {
                let client = try ClaudeClient.fromEnvironmentOrKeychain()
                for try await chunk in client.stream(system: Self.system, messages: history) {
                    guard requestID == request else { break }
                    updateReply(reply.id, on: page) { $0.text += chunk }
                }
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled {
                    updateReply(reply.id, on: page) {
                        $0.text = error.localizedDescription
                        $0.isError = true
                    }
                }
            }
            if requestID == request {
                requestID = nil
                pendingReply = nil
                isStreaming = false
                save()
            }
        }
    }
}

struct AskView: View {
    let context: PageContext
    let model: AskModel
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var turns: [ChatTurn] { model.turns(for: context.title) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Label("Ask Claude", systemImage: "sparkles").font(.headline)
                    Text("About: \(context.title.isEmpty ? "this page" : context.title)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button { model.clear(page: context.title) } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help("Clear this page's conversation")
                    .disabled(turns.isEmpty)
            }
            .padding(12)
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if turns.isEmpty { emptyState }
                        ForEach(turns) { turn in
                            bubble(turn).id(turn.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: turns.last?.text) {
                    if let id = turns.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }

            if !turns.isEmpty && !model.isStreaming {
                suggestionChips.padding(.horizontal, 12).padding(.bottom, 6)
            }
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask about this page…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($focused)
                    .onSubmit(send)
                if model.isStreaming {
                    Button { model.stop() } label: { Image(systemName: "stop.circle.fill").font(.title2) }
                        .buttonStyle(.borderless).help("Stop")
                } else {
                    Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                        .buttonStyle(.borderless)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(12)
        }
        .onAppear { focused = true }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask anything about what's on screen. Claude sees this page, including what you've selected.")
                .font(.callout).foregroundStyle(.secondary)
            ForEach(context.suggestions, id: \.self) { s in
                Button { model.ask(s, context: context) } label: {
                    Text(s).font(.callout).multilineTextAlignment(.leading)
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(context.suggestions, id: \.self) { s in
                    Button(s) { model.ask(s, context: context) }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(_ turn: ChatTurn) -> some View {
        if turn.role == "user" {
            HStack {
                Spacer(minLength: 30)
                Text(turn.text)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.2)))
                    .textSelection(.enabled)
            }
        } else if turn.text.isEmpty && model.isStreaming {
            ProgressView().controlSize(.small)
        } else if turn.isError {
            Label(turn.text, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).font(.callout)
        } else {
            Text(Self.markdown(turn.text)).textSelection(.enabled)
        }
    }

    private static func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }

    private func send() {
        model.ask(draft, context: context)
        draft = ""
    }
}

struct SettingsView: View {
    @State private var key = KeychainKey.load() ?? ""
    @State private var saved = false
    private let envKeySet = !(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "").isEmpty

    var body: some View {
        Form {
            Section {
                SecureField("Anthropic API key", text: $key)
                HStack {
                    Button("Save") { KeychainKey.save(key); saved = true }
                    if saved { Text("Saved to keychain").foregroundStyle(.secondary) }
                }
            } footer: {
                Text(envKeySet
                     ? "ANTHROPIC_API_KEY is set in the environment and takes precedence."
                     : "Used by “Ask Claude”. Stored in your login keychain.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}
