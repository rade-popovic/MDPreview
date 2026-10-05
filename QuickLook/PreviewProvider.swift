import Foundation
import JavaScriptCore
import QuickLookUI
import UniformTypeIdentifiers

/// Space-bar preview for Markdown in Finder. Renders with the same core.js as the
/// app, but in JavaScriptCore, and hands Quick Look a self-contained HTML page.
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        let markdown = decode(try Data(contentsOf: fileURL))
        let rendered = try MarkdownRenderer.render(markdown)

        let folder = fileURL.deletingLastPathComponent()
        var attachments: [String: QLPreviewReplyAttachment] = [:]
        for (index, path) in rendered.images.enumerated() {
            let imageURL = URL(fileURLWithPath: path, relativeTo: folder)
            guard let data = try? Data(contentsOf: imageURL) else { continue }
            let type = UTType(filenameExtension: imageURL.pathExtension) ?? .data
            attachments["img\(index)"] = QLPreviewReplyAttachment(data: data, contentType: type)
        }

        let html = MarkdownRenderer.page(body: rendered.html)
        return QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 900, height: 1000)) { reply in
            reply.stringEncoding = .utf8
            reply.attachments = attachments
            return Data(html.utf8)
        }
    }

    private func decode(_ data: Data) -> String {
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
    }
}

enum MarkdownRenderer {
    struct Output {
        let html: String
        let images: [String]
    }

    struct RenderError: LocalizedError {
        let errorDescription: String?
    }

    private static func resource(_ name: String) -> String {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("web/\(name)"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }

    private static let scripts = ["vendor/marked.min.js", "vendor/highlight.min.js", "core.js"].map(resource)

    private static let styles = """
        \(resource("vendor/github-markdown-light.css"))
        \(resource("vendor/hljs-github.css"))
        @media (prefers-color-scheme: dark) {
        \(resource("vendor/github-markdown-dark.css"))
        \(resource("vendor/hljs-github-dark.css"))
        }
        \(resource("viewer.css"))
        """

    /// A fresh context per preview: JSContext is not safe to share across threads.
    static func render(_ markdown: String) throws -> Output {
        guard let context = JSContext() else { throw RenderError(errorDescription: "JavaScriptCore unavailable") }
        var exception: String?
        context.exceptionHandler = { _, value in exception = value?.toString() }
        context.evaluateScript("var console = { log() {}, warn() {}, error() {} };")
        for script in scripts { context.evaluateScript(script) }

        let result = context.objectForKeyedSubscript("MDPreviewCore")?
            .objectForKeyedSubscript("renderWithLocalImages")?
            .call(withArguments: [markdown])
        if let exception { throw RenderError(errorDescription: exception) }

        return Output(
            html: result?.objectForKeyedSubscript("html")?.toString() ?? "",
            images: result?.objectForKeyedSubscript("images")?.toArray() as? [String] ?? []
        )
    }

    /// The CSP blocks any script that raw HTML in the Markdown might contain.
    static func page(body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src cid: data: https: http:; style-src 'unsafe-inline'">
        <meta name="color-scheme" content="light dark">
        <style>\(styles)</style>
        </head>
        <body><article class="markdown-body">\(body)</article></body>
        </html>
        """
    }
}
