import Foundation

enum Provider: String, CaseIterable {
    case synthetic

    var displayName: String { "Synthetic" }
    var icon: String { "leaf.fill" }
    var keyPlaceholder: String { "syn_…" }
}
