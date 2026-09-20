import CryptoKit
import Foundation
import Observation

@MainActor
@Observable
final class UsageStore {
    private(set) var snapshot: QuotaResponse?
    private(set) var history: [DailySnapshot]
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var needsKeyUpdate = false
    private(set) var lastUpdated: Date?

    private var apiKey: String?
    private var refreshGeneration = 0
    private var pendingRefresh = false
    private let client: SyntheticClient
    private let keyStore: any APIKeyStoring
    private let defaults: UserDefaults
    private static let legacyHistoryKey = "usage-history"
    private static let historyEncoder = JSONEncoder()

    var hasAPIKey: Bool { apiKey?.isEmpty == false }

    init(
        client: SyntheticClient = SyntheticClient(),
        keyStore: any APIKeyStoring = APIKeyStore(provider: .synthetic),
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
        let loadedKey = keyStore.load() ?? ProcessInfo.processInfo.environment["SYNTHETIC_API_KEY"]
        #else
        let loadedKey = keyStore.load()
        #endif
        apiKey = loadedKey
        if let loadedKey {
            history = Self.loadHistory(from: defaults, apiKey: loadedKey)
        } else {
            history = []
        }
    }

    func connect(_ value: String) async throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SetupError.emptyKey }

        refreshGeneration += 1
        let generation = refreshGeneration
        isLoading = true
        clearError()
        defer { isLoading = false }

        let response = try await client.fetchQuota(apiKey: trimmed)
        guard generation == refreshGeneration else { return }

        try keyStore.save(trimmed)
        let keyChanged = apiKey != trimmed
        apiKey = trimmed
        snapshot = response
        lastUpdated = .now
        clearError()
        if keyChanged {
            history = Self.loadHistory(from: defaults, apiKey: trimmed)
        }
        record(response)
    }

    func disconnect() {
        refreshGeneration += 1
        pendingRefresh = false
        do {
            try keyStore.delete()
        } catch {
            assignError(error)
            return
        }
        apiKey = nil
        snapshot = nil
        lastUpdated = nil
        history = []
        isLoading = false
        clearError()
    }

    func refresh() async {
        pendingRefresh = true
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        while pendingRefresh {
            pendingRefresh = false
            guard let requestedKey = apiKey else { return }
            let generation = refreshGeneration
            do {
                let response = try await client.fetchQuota(apiKey: requestedKey)
                guard generation == refreshGeneration, requestedKey == apiKey else { continue }
                snapshot = response
                lastUpdated = .now
                clearError()
                record(response)
            } catch is CancellationError {
                return
            } catch {
                guard generation == refreshGeneration, requestedKey == apiKey else { continue }
                assignError(error)
            }
        }
    }

    private func record(_ response: QuotaResponse) {
        guard let weekly = response.weeklyTokenLimit,
              let rolling = response.rollingFiveHourLimit,
              let apiKey
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
        persistHistory(for: apiKey)
    }

    private func persistHistory(for apiKey: String) {
        do {
            let data = try Self.historyEncoder.encode(history)
            defaults.set(data, forKey: Self.historyDefaultsKey(for: apiKey))
        } catch {
            if errorMessage == nil {
                errorMessage = "Allotment couldn’t save usage history on this device."
            }
        }
    }

    private func assignError(_ error: any Error) {
        errorMessage = error.localizedDescription
        needsKeyUpdate = (error as? SyntheticError)?.isAuthFailure == true
    }

    private func clearError() {
        errorMessage = nil
        needsKeyUpdate = false
    }

    private static func loadHistory(from defaults: UserDefaults, apiKey: String) -> [DailySnapshot] {
        let key = historyDefaultsKey(for: apiKey)
        if let data = defaults.data(forKey: key) {
            return decodeHistory(data)
        }
        if let data = defaults.data(forKey: legacyHistoryKey) {
            defaults.set(data, forKey: key)
            defaults.removeObject(forKey: legacyHistoryKey)
            return decodeHistory(data)
        }
        return []
    }

    private static func decodeHistory(_ data: Data) -> [DailySnapshot] {
        (try? JSONDecoder().decode([DailySnapshot].self, from: data)) ?? []
    }

    static func historyDefaultsKey(for apiKey: String) -> String {
        let digest = SHA256.hash(data: Data(apiKey.utf8))
        let hex = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "usage-history.\(hex)"
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
