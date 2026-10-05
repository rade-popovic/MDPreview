import SwiftUI
import UniformTypeIdentifiers

@main
struct MDPreviewApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            DocumentView(markdown: file.document.text, fileURL: file.fileURL)
        }
        .defaultSize(width: 900, height: 1000)
        .commands {
            SidebarCommands()
            ViewerCommands()
        }
    }
}

struct ViewerCommands: Commands {
    @FocusedObject private var viewer: ViewerModel?
    @AppStorage(Theme.defaultsKey) private var theme: Theme = .standard

    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Button("Make Default Markdown Viewer") {
                NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: .markdownText) { _ in }
            }
        }

        CommandGroup(replacing: .importExport) {
            Button("Export as PDF…") { viewer?.exportPDF() }
                .disabled(viewer == nil)
        }

        CommandGroup(replacing: .printItem) {
            Button("Print…") { viewer?.printDocument() }
                .keyboardShortcut("p")
                .disabled(viewer == nil)
        }

        CommandGroup(replacing: .textEditing) {
            Menu("Find") {
                Button("Find…") { viewer?.focusSearch() }
                    .keyboardShortcut("f")
                Button("Find Next") { viewer?.find(backwards: false) }
                    .keyboardShortcut("g")
                Button("Find Previous") { viewer?.find(backwards: true) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            .disabled(viewer == nil)
        }

        CommandGroup(before: .toolbar) {
            Button("Actual Size") { viewer?.resetZoom() }
                .keyboardShortcut("0")
            Button("Zoom In") { viewer?.zoomIn() }
                .keyboardShortcut("+")
            Button("Zoom Out") { viewer?.zoomOut() }
                .keyboardShortcut("-")
            Divider()
            Picker("Theme", selection: $theme) {
                ForEach(Theme.allCases) { Text($0.title).tag($0) }
            }
            Divider()
        }
    }
}
