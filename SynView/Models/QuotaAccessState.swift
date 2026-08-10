import Foundation

enum QuotaAccessState: Equatable {
    case ready
    case weeklyRefilling
    case requestsRefilling
    case bothRefilling

    init(weeklyRemaining: Double, requestRemaining: Double) {
        switch (weeklyRemaining > 0, requestRemaining > 0) {
        case (true, true): self = .ready
        case (false, true): self = .weeklyRefilling
        case (true, false): self = .requestsRefilling
        case (false, false): self = .bothRefilling
        }
    }

    var title: String {
        switch self {
        case .ready: "Ready when you are"
        case .weeklyRefilling: "Weekly credits refilling"
        case .requestsRefilling: "Request limit refilling"
        case .bothRefilling: "Both limits refilling"
        }
    }

    var isReady: Bool { self == .ready }
}
