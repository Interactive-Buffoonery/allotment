import Foundation

struct QuotaResponse: Decodable, Sendable {
    let subscription: RequestQuota?
    let weeklyTokenLimit: WeeklyTokenLimit?
    let rollingFiveHourLimit: RollingFiveHourLimit?
}

struct RequestQuota: Decodable, Sendable {
    let limit: Double
    let requests: Double
    let renewsAt: String
}

struct WeeklyTokenLimit: Decodable, Sendable {
    static let regenerationInterval: TimeInterval = 202 * 60

    let nextRegenAt: String
    let percentRemaining: Double
    let maxCredits: String
    let remainingCredits: String
    let nextRegenCredits: String

    var maximum: Double { maxCredits.currencyValue }
    var remaining: Double { remainingCredits.currencyValue }
    var refillAmount: Double { nextRegenCredits.currencyValue }
    var nextRefillDate: Date? { nextRegenAt.iso8601Date }

    func timeToReach(_ target: Double, now: Date = .now) -> TimeInterval {
        guard target > remaining, refillAmount > 0 else { return 0 }
        let ticks = ceil((min(target, maximum) - remaining) / refillAmount)
        let firstTick = max(0, nextRefillDate?.timeIntervalSince(now) ?? 0)
        return firstTick + max(0, ticks - 1) * Self.regenerationInterval
    }
}

struct RollingFiveHourLimit: Decodable, Sendable {
    static let regenerationInterval: TimeInterval = 15 * 60

    let nextTickAt: String
    let tickPercent: Double
    let remaining: Double
    let max: Double
    let limited: Bool

    var nextTickDate: Date? { nextTickAt.iso8601Date }
    var refillAmount: Double { max * tickPercent }
}

struct DailySnapshot: Codable, Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let weeklyRemaining: Double
    let weeklyMaximum: Double
    let rollingRemaining: Double
    let rollingMaximum: Double
}

extension String {
    var currencyValue: Double {
        Double(filter { $0.isNumber || $0 == "." || $0 == "-" }) ?? 0
    }

    var iso8601Date: Date? {
        try? Date(self, strategy: .iso8601)
    }
}
