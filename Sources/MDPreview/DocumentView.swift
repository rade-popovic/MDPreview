import SwiftUI

struct DocumentView: View {
    let fileURL: URL?
    @StateObject private var viewer: ViewerModel

    init(markdown: String, fileURL: URL?) {
        self.fileURL = fileURL
        _viewer = StateObject(wrappedValue: ViewerModel(markdown: markdown, fileURL: fileURL))
    }

    var body: some View {
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
