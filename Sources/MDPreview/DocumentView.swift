import SwiftUI

struct DocumentView: View {
    private static let showOutlineKey = "showOutline"

    let fileURL: URL?
    @StateObject private var viewer: ViewerModel
    /// Each window toggles on its own; new windows open the way the last one was left.
    @State private var columnVisibility: NavigationSplitViewVisibility =
        (UserDefaults.standard.object(forKey: DocumentView.showOutlineKey) as? Bool ?? true) ? .all : .detailOnly

    init(markdown: String, fileURL: URL?) {
        self.fileURL = fileURL
        _viewer = StateObject(wrappedValue: ViewerModel(markdown: markdown, fileURL: fileURL))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            OutlineSidebar(viewer: viewer)
                .navigationSplitViewColumnWidth(min: 160, ideal: 220, max: 360)
        } detail: {
            content
        }
        .onChange(of: columnVisibility) { _, visibility in
            UserDefaults.standard.set(visibility != .detailOnly, forKey: Self.showOutlineKey)
        }
    }

    private var content: some View {
        WebViewHost(webView: viewer.webView)
            .frame(minWidth: 420, minHeight: 300)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    ControlGroup {
                        Button { viewer.zoomOut() } label: {
                            Label("Zoom Out", systemImage: "minus.magnifyingglass")
                        }
                        Button { viewer.zoomIn() } label: {
                            Label("Zoom In", systemImage: "plus.magnifyingglass")
                        }
                    }
                    .help("Zoom")

                    if let fileURL {
                        ShareLink(item: fileURL)
                    }

                    SearchField(viewer: viewer)
                        .frame(width: 200)
                }
            }
            .focusedSceneObject(viewer)
            .onChange(of: fileURL) { _, newURL in
                viewer.fileMoved(to: newURL)
            }
    }
}

/// Document headings, indented by level. Click to jump; follows the reader while scrolling.
private struct OutlineSidebar: View {
    @ObservedObject var viewer: ViewerModel

    var body: some View {
        let topLevel = viewer.outline.map(\.level).min() ?? 1
        let selection = Binding<Int?>(
            get: { viewer.currentHeading },
            set: { index in if let index { viewer.scrollToHeading(index) } }
        )

        ScrollViewReader { proxy in
            List(selection: selection) {
                ForEach(viewer.outline) { item in
                    Text(item.title)
                        .lineLimit(1)
                        .fontWeight(item.level == topLevel ? .semibold : .regular)
                        .padding(.leading, CGFloat(item.level - topLevel) * 12)
                        .help(item.title)
                }
            }
            .listStyle(.sidebar)
            .onChange(of: viewer.currentHeading) { _, index in
                if let index { proxy.scrollTo(index) }
            }
        }
        .overlay {
            if viewer.outline.isEmpty {
                ContentUnavailableView("No Headings", systemImage: "list.bullet.indent")
            }
        }
    }
}

private struct WebViewHost: NSViewRepresentable {
    let webView: NSView

    func makeNSView(context: Context) -> NSView { webView }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Native toolbar search field, like Preview's. Typing searches as you go,
/// Return finds the next match, Shift-Return the previous one.
private struct SearchField: NSViewRepresentable {
    let viewer: ViewerModel

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Search"
        field.sendsSearchStringImmediately = false
        field.sendsWholeSearchString = false
        field.target = context.coordinator
        field.action = #selector(Coordinator.searchChanged(_:))
        field.delegate = context.coordinator
        viewer.searchField = field
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(viewer: viewer) }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        let viewer: ViewerModel

        init(viewer: ViewerModel) { self.viewer = viewer }

        @objc func searchChanged(_ sender: NSSearchField) {
            viewer.search(sender.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            let backwards = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
            viewer.find(backwards: backwards)
            return true
        }
    }
}
