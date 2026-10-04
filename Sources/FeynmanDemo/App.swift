import AppKit
import SwiftUI

@main
struct FeynmanDemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Feynman Diagrams") {
            ContentView()
                .frame(minWidth: 1050, minHeight: 700)
        }
        Settings { SettingsView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched via `swift run` (no app bundle).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

enum Page: Hashable {
    case intro, lines, vertex, orders, quiz
    case diagram(String)
}

struct ContentView: View {
    @State private var page: Page? = .intro
    @State private var context = PageContext.empty
    @State private var showAsk = false
    @State private var ask = AskModel()

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
                }
            }
            .navigationSplitViewColumnWidth(min: 230, ideal: 260)
        } detail: {
            switch page ?? .intro {
            case .intro: IntroView()
            case .lines: LinesView()
            case .vertex: VertexExplorerView()
            case .orders: OrdersView()
            case .quiz: QuizView()
            case .diagram(let id): DiagramDetailView(diagram: .named(id))
            }
        }
        .onPreferenceChange(PageContextKey.self) { context = $0 }
        .inspector(isPresented: $showAsk) {
            AskView(context: context, model: ask)
                .inspectorColumnWidth(min: 300, ideal: 360, max: 520)
        }
        .toolbar {
            ToolbarItem {
                Button { showAsk.toggle() } label: { Label("Ask Claude", systemImage: "sparkles") }
                    .keyboardShortcut("k", modifiers: .command)
                    .help("Ask Claude about this page (⌘K)")
            }
        }
    }
}
