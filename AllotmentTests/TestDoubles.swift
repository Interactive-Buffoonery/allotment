import XCTest
@testable import Allotment

final class InMemoryKeyStore: APIKeyStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?
    var deleteShouldFail = false

    init(value: String? = nil) {
        self.value = value
    }

    func load() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func save(_ apiKey: String) throws {
        lock.lock()
        defer { lock.unlock() }
        value = apiKey
    }

    func delete() throws {
        lock.lock()
        defer { lock.unlock() }
        if deleteShouldFail { throw KeyStoreError.deleteFailed }
        value = nil
    }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _handler: ((URLRequest) throws -> (Int, Data))?
    nonisolated(unsafe) private static var _delayNanoseconds: UInt64 = 0

    static var handler: ((URLRequest) throws -> (Int, Data))? {
        get { lock.withLock { _handler } }
        set { lock.withLock { _handler = newValue } }
    }

    static var delayNanoseconds: UInt64 {
        get { lock.withLock { _delayNanoseconds } }
        set { lock.withLock { _delayNanoseconds = newValue } }
    }

    static func reset() {
        handler = nil
        delayNanoseconds = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler = Self.handler
        let delay = Self.delayNanoseconds
        let client = self.client
        let request = self.request

        Task {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            do {
                guard let handler else {
                    throw URLError(.badServerResponse)
                }
                let (status, data) = try handler(request)
                let response = HTTPURLResponse(
                    url: request.url ?? URL(string: "https://api.synthetic.new/v2/quotas")!,
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}

enum QuotaFixtures {
    static let valid = Data(#"""
        {
          "subscription": {"limit": 1000, "requests": 0, "renewsAt": "2026-08-09T18:41:11.774Z"},
          "weeklyTokenLimit": {
            "nextRegenAt": "2026-08-09T16:32:59.000Z",
            "percentRemaining": 38.8886,
            "maxCredits": "$48.00",
            "remainingCredits": "$18.66",
            "nextRegenCredits": "$0.96"
          },
          "rollingFiveHourLimit": {
            "nextTickAt": "2026-08-09T13:47:57.000Z",
            "tickPercent": 0.05,
            "remaining": 987.4,
            "max": 1000,
            "limited": false
          }
        }
        """#.utf8)

    static func otherAccount() -> Data {
        var json = String(decoding: valid, as: UTF8.self)
        json = json.replacingOccurrences(of: "$18.66", with: "$40.00")
        json = json.replacingOccurrences(of: "38.8886", with: "83.3")
        return Data(json.utf8)
    }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
