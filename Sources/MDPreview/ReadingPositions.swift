import Foundation

/// Where the reader left each file, so it reopens at the same place and zoom — like Preview.
/// Kept in UserDefaults by path, trimmed to the most recently read files.
enum ReadingPositions {
    struct Position {
        var scrollY: Double
        var zoom: Double
    }

    private static let key = "readingPositions"
    private static let limit = 200

    static func position(for fileURL: URL) -> Position? {
        guard let entry = entries()[fileURL.path] else { return nil }
        return Position(scrollY: entry["y"] ?? 0, zoom: entry["zoom"] ?? 1)
    }

    static func save(_ position: Position, for fileURL: URL) {
        var all = entries()
        all[fileURL.path] = ["y": position.scrollY, "zoom": position.zoom, "t": Date().timeIntervalSince1970]
        if all.count > limit {
            let oldest = all.sorted { ($0.value["t"] ?? 0) < ($1.value["t"] ?? 0) }.prefix(all.count - limit)
            for (path, _) in oldest { all[path] = nil }
        }
        UserDefaults.standard.set(all, forKey: key)
    }

    private static func entries() -> [String: [String: Double]] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: [String: Double]] ?? [:]
    }
}
