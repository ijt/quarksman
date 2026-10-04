import SwiftUI

/// A block of searchable text on the current page and how many times it matches the query.
struct FindBlock: Equatable {
    let id: String
    let count: Int
}

/// Collects matching blocks in on-screen order.
struct FindBlocksKey: PreferenceKey {
    static let defaultValue: [FindBlock] = []
    static func reduce(value: inout [FindBlock], nextValue: () -> [FindBlock]) {
        value += nextValue()
    }
}

/// State for ⌘F find-in-page: the query, which match is current, and where to scroll.
@MainActor @Observable
final class FindModel {
    struct ScrollRequest: Equatable {
        let id = UUID()
        let block: String
    }

    private(set) var isPresented = false
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            index = 0
            scrollWhenBlocksArrive = true
        }
    }
    /// Index of the current match across the whole page.
    private(set) var index = 0
    /// Matching blocks on the current page, reported by `ProseText` views.
    var blocks: [FindBlock] = [] {
        didSet {
            guard blocks != oldValue else { return }
            if index >= total { index = 0 }
            if scrollWhenBlocksArrive {
                scrollWhenBlocksArrive = false
                scrollToCurrent()
            }
        }
    }
    private(set) var scrollRequest: ScrollRequest?
    private var scrollWhenBlocksArrive = false

    /// The query that's highlighted, or empty when the find bar is closed.
    var activeQuery: String { isPresented ? query.trimmingCharacters(in: .whitespaces) : "" }
    var total: Int { blocks.reduce(0) { $0 + $1.count } }

    /// Bumped on every ⌘F so the bar re-focuses its field even if already open.
    private(set) var focusToken = 0

    func show() {
        isPresented = true
        focusToken += 1
        scrollWhenBlocksArrive = true
    }

    func hide() { isPresented = false }

    func next() { step(1) }
    func previous() { step(-1) }

    private func step(_ delta: Int) {
        guard total > 0 else { return }
        index = (index + delta + total) % total
        scrollToCurrent()
    }

    /// The current match as (block id, occurrence within that block).
    var current: (block: String, occurrence: Int)? {
        var i = index
        for b in blocks {
            if i < b.count { return (b.id, i) }
            i -= b.count
        }
        return nil
    }

    private func scrollToCurrent() {
        if let block = current?.block { scrollRequest = ScrollRequest(block: block) }
    }
}

/// Article text that highlights find-in-page matches and reports them so the find bar can count and scroll.
struct ProseText: View {
    let text: String
    var markdown = true
    @Environment(FindModel.self) private var find: FindModel?

    init(_ text: String, markdown: Bool = true) {
        self.text = text
        self.markdown = markdown
    }

    var body: some View {
        let query = find?.activeQuery ?? ""
        let current = find?.current
        let (styled, count) = Self.highlight(text, markdown: markdown, query: query,
                                             currentOccurrence: current?.block == text ? current?.occurrence : nil)
        Text(styled)
            .id(text)
            .preference(key: FindBlocksKey.self, value: count > 0 ? [FindBlock(id: text, count: count)] : [])
    }

    static func highlight(_ text: String, markdown: Bool, query: String, currentOccurrence: Int?) -> (AttributedString, Int) {
        var attributed = markdown
            ? (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
            : AttributedString(text)
        guard !query.isEmpty else { return (attributed, 0) }

        // Search the rendered characters (markdown markers removed), then map offsets back.
        let plain = String(attributed.characters)
        var count = 0
        var searchStart = plain.startIndex
        while let r = plain.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchStart..<plain.endIndex) {
            let lower = plain.distance(from: plain.startIndex, to: r.lowerBound)
            let length = plain.distance(from: r.lowerBound, to: r.upperBound)
            let start = attributed.characters.index(attributed.startIndex, offsetBy: lower)
            let end = attributed.characters.index(start, offsetBy: length)
            let isCurrent = count == currentOccurrence
            attributed[start..<end].backgroundColor = isCurrent ? .orange : .yellow.opacity(0.45)
            if isCurrent { attributed[start..<end].foregroundColor = .black }
            count += 1
            searchStart = r.upperBound
        }
        return (attributed, count)
    }
}

/// A page's ScrollView that scrolls to the current find match.
struct FindableScrollView<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(FindModel.self) private var find: FindModel?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView { content }
                .onChange(of: find?.scrollRequest) {
                    guard let block = find?.scrollRequest?.block else { return }
                    withAnimation { proxy.scrollTo(block, anchor: .center) }
                }
        }
    }
}

struct FindBar: View {
    @Bindable var find: FindModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Find on this page", text: $find.query)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit { find.next(); focused = true }
            Text(status).font(.callout).monospacedDigit().foregroundStyle(.secondary)
            Button { find.previous() } label: { Image(systemName: "chevron.up") }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(find.total == 0)
                .help("Previous match (⇧⌘G)")
            Button { find.next() } label: { Image(systemName: "chevron.down") }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(find.total == 0)
                .help("Next match (⌘G)")
            Button("Done") { find.hide() }
                .keyboardShortcut(.cancelAction)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .onAppear { focused = true }
        .onChange(of: find.focusToken) { focused = true }
    }

    private var status: String {
        if find.activeQuery.isEmpty { return "" }
        return find.total == 0 ? "No matches" : "\(find.index + 1) of \(find.total)"
    }
}
