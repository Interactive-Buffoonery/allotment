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
        XCTAssertEqual(response.weeklyTokenLimit?.nextRefillDate, "2026-08-09T16:32:59.000Z".iso8601Date)
        XCTAssertEqual(response.rollingFiveHourLimit?.nextTickDate, "2026-08-09T13:47:57.000Z".iso8601Date)
    }

    func testRejectsUnparseableCreditStrings() {
        let data = Data(#"""
        {
          "weeklyTokenLimit": {
            "nextRegenAt": "2026-08-09T16:32:59.000Z",
            "percentRemaining": 38.8886,
            "maxCredits": "N/A",
            "remainingCredits": "$18.66",
            "nextRegenCredits": "$0.96"
          }
        }
        """#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(QuotaResponse.self, from: data))
    }

    func testHistoryWindowUsesCalendarDaysNotSuffix() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20))!
        let snapshots: [DailySnapshot] = [
            DateComponents(year: 2026, month: 7, day: 1),
            DateComponents(year: 2026, month: 8, day: 1),
            DateComponents(year: 2026, month: 8, day: 18),
            DateComponents(year: 2026, month: 8, day: 20),
        ].enumerated().map { index, components in
            DailySnapshot(
                date: calendar.date(from: components)!,
                weeklyRemaining: Double(index),
                weeklyMaximum: 48,
                rollingRemaining: 100,
                rollingMaximum: 1_000
            )
        }

        let week = snapshots.occurring(inLastDays: 7, now: now, calendar: calendar)
        XCTAssertEqual(week.map(\.weeklyRemaining), [2, 3])

        let month = snapshots.occurring(inLastDays: 30, now: now, calendar: calendar)
        XCTAssertEqual(month.map(\.weeklyRemaining), [1, 2, 3])
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

    func testWeeklyTargetDoesNotAddAnExtraTickOnCreditFixture() throws {
        let now = try XCTUnwrap("2026-08-09T15:15:59.000Z".iso8601Date)
        let quota = WeeklyTokenLimit(
            nextRegenAt: "2026-08-09T16:32:59.000Z",
            percentRemaining: 38.9,
            maxCredits: "$48.00",
            remainingCredits: "$18.66",
            nextRegenCredits: "$0.96"
        )

        XCTAssertEqual(quota.timeToReach(19.62, now: now), 77 * 60)
    }

    func testQuotaAccessRequiresBothLimits() {
        XCTAssertEqual(QuotaAccessState(weeklyRemaining: 18, requestRemaining: 987), .ready)
        XCTAssertEqual(QuotaAccessState(weeklyRemaining: 0, requestRemaining: 987), .weeklyRefilling)
        XCTAssertEqual(QuotaAccessState(weeklyRemaining: 18, requestRemaining: 0), .requestsRefilling)
        XCTAssertEqual(QuotaAccessState(weeklyRemaining: 0, requestRemaining: 0), .bothRefilling)
    }
}
