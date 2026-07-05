import XCTest
@testable import DokoWanCafe

/// T107: 営業中判定のユニットテスト（FR-102, SC-102, 憲章 原則IV）
final class OpeningHoursEvaluatorTests: XCTestCase {
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    /// 2026-07-06 は月曜日。東京時間で日時を作る
    private func tokyoDate(day: Int = 6, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = tokyo
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        return calendar.date(from: components)!
    }

    private var hours: OpeningHours {
        OpeningHours(
            mon: [TimeRange(open: "09:00", close: "18:00")],
            tue: [],  // 定休
            wed: nil, // 不明（未登録）
            thu: [TimeRange(open: "09:00", close: "12:00"), TimeRange(open: "13:00", close: "18:00")],
            fri: nil, sat: nil, sun: nil
        )
    }

    func test_営業時間内は営業中() {
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(hour: 10, minute: 30)),
            .open
        )
    }

    func test_開店時刻は営業中_閉店時刻は時間外() {
        XCTAssertEqual(OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(hour: 9, minute: 0)), .open)
        XCTAssertEqual(OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(hour: 18, minute: 0)), .outsideHours)
    }

    func test_開店前は時間外() {
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(hour: 8, minute: 59)),
            .outsideHours
        )
    }

    func test_定休曜日は本日定休() {
        // 2026-07-07 は火曜日（空配列 = 定休）
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(day: 7, hour: 10, minute: 0)),
            .closedToday
        )
    }

    func test_未登録の曜日は不明() {
        // 2026-07-08 は水曜日（nil = 未登録）→ 「定休」と誤認させない（FR-104）
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(day: 8, hour: 10, minute: 0)),
            .unknown
        )
    }

    func test_複数時間帯_休憩中は時間外() {
        // 2026-07-09 は木曜日（9-12, 13-18）
        XCTAssertEqual(OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(day: 9, hour: 12, minute: 30)), .outsideHours)
        XCTAssertEqual(OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(day: 9, hour: 13, minute: 0)), .open)
        XCTAssertEqual(OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(day: 9, hour: 11, minute: 0)), .open)
    }

    func test_構造化なしは不明() {
        XCTAssertEqual(OpeningHoursEvaluator.state(hours: nil, at: tokyoDate(hour: 10, minute: 0)), .unknown)
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: OpeningHours(), at: tokyoDate(hour: 10, minute: 0)),
            .unknown
        )
    }

    func test_タイムゾーンが正しく適用される() {
        // 東京 月曜10:00 = UTC 月曜01:00。UTCで評価すると別の結果になり得るが、既定は東京
        let date = tokyoDate(hour: 10, minute: 0)
        XCTAssertEqual(OpeningHoursEvaluator.state(hours: hours, at: date), .open)
        // 東京 月曜 8:00 は UTC では日曜23:00 → 東京基準で「時間外」になることを確認
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(hour: 8, minute: 0)),
            .outsideHours
        )
    }
}
