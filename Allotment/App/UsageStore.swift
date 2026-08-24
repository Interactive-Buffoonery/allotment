import Foundation
import Observation

@MainActor
@Observable
final class UsageStore {
    private(set) var snapshot: QuotaResponse?
    private(set) var history: [DailySnapshot]
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?

    private var apiKey: String?
    private let client: SyntheticClient
    private let keyStore: APIKeyStore
    private let defaults: UserDefaults
    private let historyKey = "usage-history"
    private static let historyEncoder = JSONEncoder()

    var hasAPIKey: Bool { apiKey?.isEmpty == false }

    init(
        client: SyntheticClient = SyntheticClient(),
        keyStore: APIKeyStore = APIKeyStore(provider: .synthetic),
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.keyStore = keyStore
        self.defaults = defaults
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--sample-data") {
            apiKey = "sample"
            snapshot = Self.sampleSnapshot
            history = Self.sampleHistory
            lastUpdated = .now
            return
        }
        apiKey = keyStore.load() ?? ProcessInfo.processInfo.environment["SYNTHETIC_API_KEY"]
        #else
        apiKey = keyStore.load()
        #endif
        history = Self.loadHistory(from: defaults, key: historyKey)
    }

    func saveAPIKey(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SetupError.emptyKey }
        try keyStore.save(trimmed)
        apiKey = trimmed
        errorMessage = nil
    }

    func disconnect() {
        keyStore.delete()
        apiKey = nil
        snapshot = nil
        errorMessage = nil
    }

    func refresh() async {
        guard let requestedKey = apiKey, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await client.fetchQuota(apiKey: requestedKey)
            guard requestedKey == apiKey else { return }
            snapshot = response
            lastUpdated = .now
            record(response)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func record(_ response: QuotaResponse) {
        guard let weekly = response.weeklyTokenLimit,
              let rolling = response.rollingFiveHourLimit
        else { return }

        let today = Calendar.current.startOfDay(for: .now)
        let entry = DailySnapshot(
            date: today,
            weeklyRemaining: weekly.remaining,
            weeklyMaximum: weekly.maximum,
            rollingRemaining: rolling.remaining,
            rollingMaximum: rolling.max
        )
        history.removeAll { Calendar.current.isDate($0.date, inSameDayAs: today) }
        history.append(entry)
        history = Array(history.sorted { $0.date < $1.date }.suffix(30))
        if let data = try? Self.historyEncoder.encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }

    private static func loadHistory(from defaults: UserDefaults, key: String) -> [DailySnapshot] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([DailySnapshot].self, from: data)) ?? []
    }

    #if DEBUG
    private static let sampleSnapshot = QuotaResponse(
        subscription: RequestQuota(limit: 1_000, requests: 0, renewsAt: "2026-08-09T18:41:11.774Z"),
        weeklyTokenLimit: WeeklyTokenLimit(nextRegenAt: Date.now.addingTimeInterval(102 * 60).ISO8601Format(), percentRemaining: 38.9, maxCredits: "$48.00", remainingCredits: "$18.66", nextRegenCredits: "$0.96"),
        rollingFiveHourLimit: RollingFiveHourLimit(nextTickAt: Date.now.addingTimeInterval(8 * 60).ISO8601Format(), tickPercent: 0.05, remaining: 987.4, max: 1_000, limited: false)
    )

    private static let sampleHistory: [DailySnapshot] = zip(0..<7, [31.20, 28.80, 34.56, 19.20, 22.08, 24.96, 18.66]).map { offset, credits in
        DailySnapshot(
            date: Calendar.current.date(byAdding: .day, value: offset - 6, to: Calendar.current.startOfDay(for: .now)) ?? .now,
            weeklyRemaining: credits,
            weeklyMaximum: 48,
            rollingRemaining: 850,
            rollingMaximum: 1_000
        )
    }
    #endif
}

enum SetupError: LocalizedError {
    case emptyKey

    var errorDescription: String? { "Enter your Synthetic API key." }
}
