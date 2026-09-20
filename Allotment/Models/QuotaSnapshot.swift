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
        let regenAt = try c.decode(String.self, forKey: .nextRegenAt)
        guard let nextRefillDate = regenAt.iso8601Date else {
            throw DecodingError.dataCorruptedError(forKey: .nextRegenAt, in: c, debugDescription: "Invalid ISO-8601 date.")
        }
        guard let maximum = try c.decode(String.self, forKey: .maxCredits).parsedCurrencyAmount else {
            throw DecodingError.dataCorruptedError(forKey: .maxCredits, in: c, debugDescription: "Invalid currency value.")
        }
        guard let remaining = try c.decode(String.self, forKey: .remainingCredits).parsedCurrencyAmount else {
            throw DecodingError.dataCorruptedError(forKey: .remainingCredits, in: c, debugDescription: "Invalid currency value.")
        }
        guard let refillAmount = try c.decode(String.self, forKey: .nextRegenCredits).parsedCurrencyAmount else {
            throw DecodingError.dataCorruptedError(forKey: .nextRegenCredits, in: c, debugDescription: "Invalid currency value.")
        }
        self.nextRefillDate = nextRefillDate
        self.percentRemaining = try c.decode(Double.self, forKey: .percentRemaining)
        self.maximum = maximum
        self.remaining = remaining
        self.refillAmount = refillAmount
    }

    enum CodingKeys: String, CodingKey {
        case nextRegenAt, percentRemaining, maxCredits, remainingCredits, nextRegenCredits
    }

    func timeToReach(_ target: Double, now: Date = .now) -> TimeInterval {
        let remainingCents = Int((remaining * 100).rounded())
        let targetCents = Int((min(target, maximum) * 100).rounded())
        let refillCents = Int((refillAmount * 100).rounded())
        guard targetCents > remainingCents, refillCents > 0 else { return 0 }
        let ticks = (targetCents - remainingCents + refillCents - 1) / refillCents
        let firstTick = max(0, nextRefillDate?.timeIntervalSince(now) ?? 0)
        return firstTick + max(0, Double(ticks - 1)) * Self.regenerationInterval
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
        let tickAt = try c.decode(String.self, forKey: .nextTickAt)
        guard let nextTickDate = tickAt.iso8601Date else {
            throw DecodingError.dataCorruptedError(forKey: .nextTickAt, in: c, debugDescription: "Invalid ISO-8601 date.")
        }
        self.nextTickDate = nextTickDate
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

extension Array where Element == DailySnapshot {
    func occurring(inLastDays days: Int, now: Date = .now, calendar: Calendar = .current) -> [DailySnapshot] {
        let start = calendar.date(byAdding: .day, value: 1 - days, to: calendar.startOfDay(for: now)) ?? .distantPast
        return filter { $0.date >= start }
    }
}

extension String {
    var currencyValue: Double {
        parsedCurrencyAmount ?? 0
    }

    var parsedCurrencyAmount: Double? {
        let stripped = filter { $0.isASCII && ($0.isNumber || $0 == "." || $0 == "-") }
        guard stripped.contains(where: \.isNumber) else { return nil }
        return Double(stripped)
    }

    var iso8601Date: Date? {
        try? Date(self, strategy: .iso8601)
    }
}
