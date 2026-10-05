import Foundation
import UniformTypeIdentifiers
import WebKit

/// Serves the page's local files to the web view:
/// - `mdp://app/…` — the bundled renderer and styles in Resources/web
/// - `mdp://doc/<absolute path>` — files next to the document (images, linked files)
///
/// The page's base URL is the document's folder under `mdp://doc`, so relative
/// links like `![](images/a.png)` resolve exactly as they would on disk.
final class LocalSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "mdp"

    private static let appRoot = (Bundle.main.resourceURL ?? Bundle.main.bundleURL)
        .appendingPathComponent("web", isDirectory: true)
        .standardizedFileURL

    static func pageURL(forDocumentAt fileURL: URL?) -> URL? {
        let folder = fileURL?.deletingLastPathComponent().path ?? NSHomeDirectory()
        var components = URLComponents()
        components.scheme = scheme
        components.host = "doc"
        components.path = folder.hasSuffix("/") ? folder : folder + "/"
        return components.url
    }

    static func fileURL(for url: URL) -> URL? {
        switch url.host {
        case "doc":
            return URL(fileURLWithPath: url.path)
        case "app":
            let file = appRoot.appendingPathComponent(url.path).standardizedFileURL
            return file.path.hasPrefix(appRoot.path + "/") ? file : nil
        default:
            return nil
        }
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url,
              let file = Self.fileURL(for: url),
              let data = try? Data(contentsOf: file)
        else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mimeType = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        task.didReceive(URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil))
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
