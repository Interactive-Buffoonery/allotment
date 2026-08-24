import Foundation

enum UsageLayout: String, CaseIterable {
    case bars
    case rings

    static let storageKey = "allotment-usage-layout"

    var label: String { rawValue.capitalized }
}
