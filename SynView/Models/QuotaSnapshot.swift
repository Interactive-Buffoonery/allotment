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

struct WeeklyTokenLimit: Decodable, Sendable, Equatable {
    static let regenerationInterval: TimeInterval = 202 * 60

    let nextRefillDate: Date?
    let percentRemaining: Double
    let maximum: Double
    let remaining: Double
    let refillAmount: Double

    init(nextRegenAt: String, percentRemaining: Double, maxCredits: String, remainingCredits: String, nextRegenCredits: String) {
        self.nextRefillDate = nextRegenAt.iso8601Date
        self.percentRemaining = percentRemaining
        self.maximum = maxCredits.currencyValue
        self.remaining = remainingCredits.currencyValue
        self.refillAmount = nextRegenCredits.currencyValue
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nextRefillDate = try c.decode(String.self, forKey: .nextRegenAt).iso8601Date
        self.percentRemaining = try c.decode(Double.self, forKey: .percentRemaining)
        self.maximum = try c.decode(String.self, forKey: .maxCredits).currencyValue
        self.remaining = try c.decode(String.self, forKey: .remainingCredits).currencyValue
        self.refillAmount = try c.decode(String.self, forKey: .nextRegenCredits).currencyValue
    }

    enum CodingKeys: String, CodingKey {
        case nextRegenAt, percentRemaining, maxCredits, remainingCredits, nextRegenCredits
    }

    func timeToReach(_ target: Double, now: Date = .now) -> TimeInterval {
        guard target > remaining, refillAmount > 0 else { return 0 }
        let ticks = ceil((min(target, maximum) - remaining) / refillAmount)
        let firstTick = max(0, nextRefillDate?.timeIntervalSince(now) ?? 0)
        return firstTick + max(0, ticks - 1) * Self.regenerationInterval
    }
}

struct RollingFiveHourLimit: Decodable, Sendable, Equatable {
    static let regenerationInterval: TimeInterval = 15 * 60

    let nextTickDate: Date?
    let tickPercent: Double
    let remaining: Double
    let max: Double
    let limited: Bool

    var refillAmount: Double { max * tickPercent }

    init(nextTickAt: String, tickPercent: Double, remaining: Double, max: Double, limited: Bool) {
        self.nextTickDate = nextTickAt.iso8601Date
        self.tickPercent = tickPercent
        self.remaining = remaining
        self.max = max
        self.limited = limited
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nextTickDate = try c.decode(String.self, forKey: .nextTickAt).iso8601Date
        self.tickPercent = try c.decode(Double.self, forKey: .tickPercent)
        self.remaining = try c.decode(Double.self, forKey: .remaining)
        self.max = try c.decode(Double.self, forKey: .max)
        self.limited = try c.decode(Bool.self, forKey: .limited)
    }

    enum CodingKeys: String, CodingKey {
        case nextTickAt, tickPercent, remaining, max, limited
    }
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
        let stripped = filter { $0.isASCII && ($0.isNumber || $0 == "." || $0 == "-") }
        return Double(stripped) ?? 0
    }

    var iso8601Date: Date? {
        try? Date(self, strategy: .iso8601)
    }
}
