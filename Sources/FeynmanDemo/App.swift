import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct FeynmanDemoApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @State private var find = FindModel()

    var body: some Scene {
        WindowGroup("Feynman Diagrams") {
            ContentView()
                .environment(find)
                #if os(macOS)
                .frame(minWidth: 1050, minHeight: 700)
                #endif
        }
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Find…") { find.show() }
                    .keyboardShortcut("f", modifiers: .command)
            }
        }
        #if os(macOS)
        Settings { SettingsView() }
        #endif
    }
}

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched via `swift run` (no app bundle).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
#endif

enum Page: Hashable {
    case intro, lines, vertex, orders, quiz, game
    case diagram(String)
}

struct ContentView: View {
    @State private var page: Page? = .intro
    @State private var context = PageContext.empty
    @State private var showAsk = false
    @State private var ask = AskModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FindModel.self) private var find

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                Section("Learn") {
                    Label("What is a Feynman diagram?", systemImage: "book").tag(Page.intro)
                    Label("The cast of lines", systemImage: "scribble.variable").tag(Page.lines)
                    Label("One vertex, six stories", systemImage: "arrow.triangle.branch").tag(Page.vertex)
                }
                Section("Processes") {
                    ForEach(Diagram.catalog) { d in
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(d.title)
                                Text(d.process).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: d.interaction.icon).foregroundStyle(d.interaction.color)
                        }
                        .tag(Page.diagram(d.id))
                    }
                }
                Section("Go deeper") {
                    Label("Orders & loops", systemImage: "chart.bar.xaxis").tag(Page.orders)
                    Label("Quiz", systemImage: "questionmark.circle").tag(Page.quiz)
                    Label("Diagram Builder Game", systemImage: "puzzlepiece.extension").tag(Page.game)
                }
            }
            .navigationSplitViewColumnWidth(min: 230, ideal: 260)
        } detail: {
            Group {
                switch page ?? .intro {
                case .intro: IntroView(navigate: { page = $0 })
                case .lines: LinesView()
                case .vertex: VertexExplorerView()
                case .orders: OrdersView()
                case .quiz: QuizView()
                case .game: GameView()
                case .diagram(let id): DiagramDetailView(diagram: .named(id))
                }
            }
            .onPreferenceChange(FindBlocksKey.self) { find.blocks = $0 }
            .safeAreaInset(edge: .top, spacing: 0) {
                if find.isPresented { FindBar(find: find) }
            }
        }
        .onPreferenceChange(PageContextKey.self) { context = $0 }
        // iOS can kill a backgrounded app without warning, so save chats on the way out.
        .onChange(of: scenePhase) { if scenePhase == .background { ask.save() } }
        .inspector(isPresented: $showAsk) {
            AskView(context: context, model: ask)
                .inspectorColumnWidth(min: 300, ideal: 360, max: 520)
        }
        .toolbar {
            #if os(iOS)
            // iPhones often have no keyboard for ⌘F.
            ToolbarItem {
                Button { find.isPresented ? find.hide() : find.show() } label: { Label("Find", systemImage: "magnifyingglass") }
            }
            #endif
            ToolbarItem {
                Button { showAsk.toggle() } label: { Label("Ask Claude", systemImage: "sparkles") }
                    .keyboardShortcut("k", modifiers: .command)
                    .help("Ask Claude about this page (⌘K)")
            }
        }
    }
}
