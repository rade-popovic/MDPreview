import Foundation

/// Look of the rendered page, chosen in View › Theme and shared by every window.
/// The raw value is what the page's `data-theme` attribute gets.
enum Theme: String, CaseIterable, Identifiable {
    case standard = "default"
    case gold

    static let defaultsKey = "theme"

    static var current: Theme {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(Theme.init) ?? .standard
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Default"
        case .gold: "Gold"
        }
    }
}
