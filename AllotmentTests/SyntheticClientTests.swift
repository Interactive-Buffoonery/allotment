import XCTest
@testable import Allotment

final class SyntheticClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testFetchQuotaDecodesASuccessfulPayload() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer syn_ok")
            XCTAssertEqual(request.url?.absoluteString, "https://api.synthetic.new/v2/quotas")
            return (200, QuotaFixtures.valid)
        }

        let client = SyntheticClient(session: QuotaFixtures.session())
        let response = try await client.fetchQuota(apiKey: "syn_ok")
        XCTAssertEqual(response.weeklyTokenLimit?.remaining, 18.66)
    }

    func testFetchQuotaMapsUnauthorizedToAuthError() async {
        MockURLProtocol.handler = { _ in (401, Data()) }
        let client = SyntheticClient(session: QuotaFixtures.session())

        do {
            _ = try await client.fetchQuota(apiKey: "syn_bad")
            XCTFail("Expected an auth error")
        } catch {
            XCTAssertEqual(error as? SyntheticError, .httpStatus(401))
            XCTAssertTrue((error as? SyntheticError)?.isAuthFailure == true)
        }
    }

    func testFetchQuotaRejectsUndecodableBodies() async {
        MockURLProtocol.handler = { _ in (200, Data("{\"weeklyTokenLimit\": true}".utf8)) }
        let client = SyntheticClient(session: QuotaFixtures.session())

        do {
            _ = try await client.fetchQuota(apiKey: "syn_ok")
            XCTFail("Expected a decoding error")
        } catch {
            XCTAssertFalse(error is SyntheticError)
        }
    }
}
