import SwiftUI

/// True on compact-width screens (iPhone, narrow iPad split view). Always false on macOS.
private struct CompactWidthReader<Content: View>: View {
    @ViewBuilder var content: (Bool) -> Content
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    var body: some View { content(sizeClass == .compact) }
    #else
    var body: some View { content(false) }
    #endif
}

/// Side by side on wide screens, stacked vertically on compact ones.
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        CompactWidthReader { compact in
            if compact {
                VStack(alignment: .leading, spacing: spacing) { content }
            } else {
                HStack(alignment: .top, spacing: spacing) { content }
            }
        }
    }
}

/// A main view with a fixed-width side panel, which moves below the main view on compact screens.
struct SidePanelStack<Main: View, Side: View>: View {
    var sideWidth: CGFloat
    var sideMinHeight: CGFloat? = nil
    var spacing: CGFloat = 16
    @ViewBuilder var main: Main
    @ViewBuilder var side: Side

    var body: some View {
        CompactWidthReader { compact in
            if compact {
                VStack(alignment: .leading, spacing: spacing) {
                    main
                    side.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .top, spacing: spacing) {
                    main
                    side.frame(width: sideWidth).frame(minHeight: sideMinHeight)
                }
            }
        }
    }
}

extension View {
    /// A fixed height that shrinks on compact screens, where a diagram is narrower and needs less room.
    func adaptiveHeight(_ regular: CGFloat, compact: CGFloat) -> some View {
        CompactWidthReader { isCompact in
            self.frame(height: isCompact ? compact : regular)
        }
    }

    /// Removes the view on iOS, e.g. a heading that repeats the large navigation title there.
    @ViewBuilder func hiddenOnIOS(_ hidden: Bool = true) -> some View {
        #if os(iOS)
        if !hidden { self }
        #else
        self
        #endif
    }

    /// Link-looking buttons on macOS; plain borderless buttons elsewhere.
    @ViewBuilder func linkButtonStyle() -> some View {
        #if os(macOS)
        buttonStyle(.link)
        #else
        buttonStyle(.borderless)
        #endif
    }
}
