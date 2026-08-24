import XCTest
@testable import Allotment

final class QuotaSnapshotTests: XCTestCase {
    func testDecodesCurrentQuotaPayload() throws {
        let data = Data(#"""
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

        let response = try JSONDecoder().decode(QuotaResponse.self, from: data)

        XCTAssertEqual(response.weeklyTokenLimit?.remaining, 18.66)
        XCTAssertEqual(response.weeklyTokenLimit?.refillAmount, 0.96)
        XCTAssertEqual(response.rollingFiveHourLimit?.refillAmount, 50)
    }

    func testWeeklyTargetUsesIncrementalRefillTicks() throws {
        let now = try XCTUnwrap("2026-08-09T15:15:59.000Z".iso8601Date)
        let quota = WeeklyTokenLimit(
            nextRegenAt: "2026-08-09T16:32:59.000Z",
            percentRemaining: 36,
            maxCredits: "$24.00",
            remainingCredits: "$8.64",
            nextRegenCredits: "$0.48"
        )

        XCTAssertEqual(quota.timeToReach(12, now: now), 77 * 60 + 6 * 202 * 60)
        XCTAssertEqual(quota.timeToReach(8, now: now), 0)
    }

    func testQuotaAccessRequiresBothLimits() {
        XCTAssertEqual(QuotaAccessState(weeklyRemaining: 18, requestRemaining: 987), .ready)
        XCTAssertEqual(QuotaAccessState(weeklyRemaining: 0, requestRemaining: 987), .weeklyRefilling)
        XCTAssertEqual(QuotaAccessState(weeklyRemaining: 18, requestRemaining: 0), .requestsRefilling)
        XCTAssertEqual(QuotaAccessState(weeklyRemaining: 0, requestRemaining: 0), .bothRefilling)
    }
}
