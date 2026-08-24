import XCTest
@testable import Allotment

final class APIKeyStoreTests: XCTestCase {
    // ponytail: runs against the hosted app's own Keychain on the simulator;
    // the round-trip key is deleted in tearDown.
    private let store = APIKeyStore(provider: .synthetic)

    override func tearDown() {
        store.delete()
        super.tearDown()
    }

    func testSaveLoadDeleteRoundTrips() throws {
        try store.save("test-key-12345")
        XCTAssertEqual(store.load(), "test-key-12345")
        store.delete()
        XCTAssertNil(store.load())
    }
}
