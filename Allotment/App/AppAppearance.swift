import SwiftUI

enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    static let storageKey = "allotment-appearance"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}
