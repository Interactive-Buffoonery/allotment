import XCTest
@testable import Allotment

@MainActor
final class UsageStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "allotment.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        if let suiteName {
            defaults?.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        super.tearDown()
    }

    func testConnectSavesKeyOnlyAfterSyntheticAcceptsIt() async throws {
        MockURLProtocol.handler = { _ in (200, QuotaFixtures.valid) }
        let keys = InMemoryKeyStore()
        let store = makeStore(keys: keys)

        try await store.connect(" syn_ok ")

        XCTAssertTrue(store.hasAPIKey)
        XCTAssertEqual(keys.load(), "syn_ok")
        XCTAssertEqual(store.snapshot?.weeklyTokenLimit?.remaining, 18.66)
        XCTAssertNil(store.errorMessage)
    }

    func testConnectLeavesKeyUnsavedWhenSyntheticRejectsIt() async {
        MockURLProtocol.handler = { _ in (401, Data()) }
        let keys = InMemoryKeyStore()
        let store = makeStore(keys: keys)

        do {
            try await store.connect("syn_bad")
            XCTFail("Expected connect to throw")
        } catch {
            XCTAssertEqual(error as? SyntheticError, .httpStatus(401))
        }

        XCTAssertFalse(store.hasAPIKey)
        XCTAssertNil(keys.load())
        XCTAssertNil(store.snapshot)
    }

    func testRefreshSurfacesAuthFailureWithoutDroppingCachedSnapshot() async throws {
        MockURLProtocol.handler = { _ in (200, QuotaFixtures.valid) }
        let store = makeStore(keys: InMemoryKeyStore())
        try await store.connect("syn_ok")

        MockURLProtocol.handler = { _ in (401, Data()) }
        await store.refresh()

        XCTAssertEqual(store.snapshot?.weeklyTokenLimit?.remaining, 18.66)
        XCTAssertEqual(store.errorMessage, "That API key was rejected.")
        XCTAssertTrue(store.needsKeyUpdate)
    }

    func testConnectDuringInFlightRefreshKeepsTheNewAccountSnapshot() async throws {
        MockURLProtocol.delayNanoseconds = 150_000_000
        MockURLProtocol.handler = { request in
            let token = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if token.contains("syn_new") {
                return (200, QuotaFixtures.otherAccount())
            }
            return (200, QuotaFixtures.valid)
        }

        let store = makeStore(keys: InMemoryKeyStore(value: "syn_old"))
        async let refresh: Void = store.refresh()
        try await Task.sleep(nanoseconds: 40_000_000)
        try await store.connect("syn_new")
        await refresh

        XCTAssertEqual(store.snapshot?.weeklyTokenLimit?.remaining, 40)
        XCTAssertTrue(store.hasAPIKey)
        XCTAssertNil(store.errorMessage)
    }

    func testHistoryIsNamespacedByAccount() async throws {
        MockURLProtocol.handler = { _ in (200, QuotaFixtures.valid) }
        let storeA = makeStore(keys: InMemoryKeyStore())
        try await storeA.connect("syn_a")
        XCTAssertEqual(storeA.history.first?.weeklyRemaining, 18.66)

        MockURLProtocol.handler = { _ in (200, QuotaFixtures.otherAccount()) }
        let storeB = makeStore(keys: InMemoryKeyStore())
        try await storeB.connect("syn_b")
        XCTAssertEqual(storeB.history.first?.weeklyRemaining, 40)

        let reloadedA = makeStore(keys: InMemoryKeyStore(value: "syn_a"))
        XCTAssertEqual(reloadedA.history.first?.weeklyRemaining, 18.66)
        XCTAssertNotEqual(
            UsageStore.historyDefaultsKey(for: "syn_a"),
            UsageStore.historyDefaultsKey(for: "syn_b")
        )
    }

    func testFailedDisconnectKeepsTheSession() {
        let keys = InMemoryKeyStore(value: "syn_ok")
        keys.deleteShouldFail = true
        let store = makeStore(keys: keys)

        store.disconnect()

        XCTAssertTrue(store.hasAPIKey)
        XCTAssertEqual(keys.load(), "syn_ok")
        XCTAssertEqual(store.errorMessage, "Allotment couldn’t remove the API key from this device.")
    }

    private func makeStore(keys: InMemoryKeyStore) -> UsageStore {
        UsageStore(
            client: SyntheticClient(session: QuotaFixtures.session()),
            keyStore: keys,
            defaults: defaults
        )
    }
}
