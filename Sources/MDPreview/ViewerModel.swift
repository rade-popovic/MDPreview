import AppKit
import UniformTypeIdentifiers
import WebKit

/// One per document window: owns the web view and everything the menus and toolbar act on.
@MainActor
final class ViewerModel: NSObject, ObservableObject {
    let webView: MarkdownWebView
    weak var searchField: NSSearchField?

    private var fileURL: URL?
    private var markdown: String
    private var watcher: FileWatcher?
    private var pageLoaded = false
    private var reloadScheduled = false

    private static let zoomSteps: [CGFloat] = [0.5, 0.67, 0.75, 0.85, 1, 1.15, 1.25, 1.5, 1.75, 2, 2.5, 3]

    private static let pageTemplate: String = {
        guard let url = Bundle.main.url(forResource: "page", withExtension: "html", subdirectory: "web"),
              let template = try? String(contentsOf: url, encoding: .utf8)
        else { return "<p>MD Preview is missing its page template. Rebuild the app.</p>" }
        return template
    }()

    init(markdown: String, fileURL: URL?) {
        self.markdown = markdown
        self.fileURL = fileURL

        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(LocalSchemeHandler(), forURLScheme: LocalSchemeHandler.scheme)
        webView = MarkdownWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsMagnification = true
        webView.setValue(false, forKey: "drawsBackground")
        webView.onZoomIn = { [weak self] in self?.zoomIn() }

        loadPage()
        startWatching()
    }

    // MARK: Content

    private func loadPage() {
        pageLoaded = false
        let html = Self.pageTemplate.replacingOccurrences(of: "<!--MARKDOWN-->", with: Self.jsonLiteral(markdown))
        webView.loadHTMLString(html, baseURL: LocalSchemeHandler.pageURL(forDocumentAt: fileURL))
    }

    /// JSON string literal that is also safe inside a <script> element.
    private static func jsonLiteral(_ text: String) -> String {
        let data = (try? JSONEncoder().encode(text)) ?? Data("\"\"".utf8)
        return String(decoding: data, as: UTF8.self).replacingOccurrences(of: "<", with: "\\u003c")
    }

    private func startWatching() {
        watcher = fileURL.map { url in
            FileWatcher(url: url) { [weak self] in
                MainActor.assumeIsolated { self?.scheduleReload() }
            }
        }
    }

    /// Editors often fire several events per save; coalesce them into one re-render.
    private func scheduleReload() {
        guard !reloadScheduled else { return }
        reloadScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.reloadScheduled = false
                self.reloadFromDisk()
            }
        }
    }

    private func reloadFromDisk() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        let text = MarkdownDocument.decode(data)
        guard text != markdown else { return }
        markdown = text
        if pageLoaded {
            webView.evaluateJavaScript("render(\(Self.jsonLiteral(text)), true)")
        } else {
            loadPage()
        }
    }

    func fileMoved(to newURL: URL?) {
        guard newURL != fileURL else { return }
        fileURL = newURL
        startWatching()
        loadPage()
    }

    // MARK: Zoom

    func zoomIn() {
        setZoom(Self.zoomSteps.first { $0 > webView.pageZoom + 0.001 } ?? Self.zoomSteps.last!)
    }

    func zoomOut() {
        setZoom(Self.zoomSteps.last { $0 < webView.pageZoom - 0.001 } ?? Self.zoomSteps.first!)
    }

    func resetZoom() {
        webView.magnification = 1
        setZoom(1)
    }

    private func setZoom(_ zoom: CGFloat) {
        webView.pageZoom = zoom
    }

    // MARK: Find

    func focusSearch() {
        guard let field = searchField else { return }
        field.window?.makeFirstResponder(field)
        field.currentEditor()?.selectAll(nil)
    }

    /// Search as you type: always start from the top of the document.
    func search(_ text: String) {
        webView.evaluateJavaScript("window.getSelection().removeAllRanges()") { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard !text.isEmpty else { return }
                self?.find(backwards: false, beepIfMissing: false)
            }
        }
    }

    func find(backwards: Bool, beepIfMissing: Bool = true) {
        guard let text = searchField?.stringValue, !text.isEmpty else {
            focusSearch()
            return
        }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = false
        configuration.wraps = true
        webView.find(text, configuration: configuration) { result in
            if !result.matchFound && beepIfMissing { NSSound.beep() }
        }
    }

    // MARK: Print

    func printDocument() {
        guard let window = webView.window else { return }
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        info.topMargin = 36
        info.bottomMargin = 36
        info.leftMargin = 36
        info.rightMargin = 36

        let operation = webView.printOperation(with: info)
        operation.jobTitle = fileURL?.deletingPathExtension().lastPathComponent ?? "Markdown"
        operation.view?.frame = webView.bounds
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    // MARK: Links

    private func openLink(_ url: URL) {
        guard url.scheme == LocalSchemeHandler.scheme else {
            NSWorkspace.shared.open(url)
            return
        }
        guard let file = LocalSchemeHandler.fileURL(for: url) else { return }
        if UTType(filenameExtension: file.pathExtension)?.conforms(to: .markdownText) == true {
            NSDocumentController.shared.openDocument(withContentsOf: file, display: true) { _, _, error in
                if let error { NSApp.presentError(error) }
            }
        } else {
            NSWorkspace.shared.open(file)
        }
    }
}

extension ViewerModel: WKNavigationDelegate, WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // Only our own page load may navigate the view; links open elsewhere.
        if action.navigationType == .other, action.targetFrame?.isMainFrame == true,
           action.request.url?.scheme == LocalSchemeHandler.scheme {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        if action.navigationType == .linkActivated, let url = action.request.url {
            openLink(url)
        }
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for action: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = action.request.url { openLink(url) }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageLoaded = true
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loadPage()
    }
}

/// WKWebView with viewer-specific keyboard and context-menu tweaks.
final class MarkdownWebView: WKWebView {
    var onZoomIn: (() -> Void)?

    private static let hiddenMenuItems: Set<String> = [
        "WKMenuItemIdentifierReload",
        "WKMenuItemIdentifierGoBack",
        "WKMenuItemIdentifierGoForward",
        "WKMenuItemIdentifierOpenLinkInNewWindow",
        "WKMenuItemIdentifierDownloadLinkedFile",
        "WKMenuItemIdentifierOpenImageInNewWindow",
        "WKMenuItemIdentifierDownloadImage",
        "WKMenuItemIdentifierOpenFrameInNewWindow",
    ]

    /// The menu says ⌘+, but on most keyboards people press ⌘= for it.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "=" {
            onZoomIn?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        menu.items.removeAll { Self.hiddenMenuItems.contains($0.identifier?.rawValue ?? "") }
        super.willOpenMenu(menu, with: event)
    }
}
