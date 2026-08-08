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

    // MARK: - closingTimeIfOpen（地図の下部コンパクトカード「営業中・〜HH:mm」表示, UI/UXブラッシュアップ設計書2）

    func test_営業中なら閉店時刻を返す() {
        XCTAssertEqual(
            OpeningHoursEvaluator.closingTimeIfOpen(hours: hours, at: tokyoDate(hour: 10, minute: 30)),
            "18:00"
        )
    }

    func test_複数時間帯でも該当する枠の閉店時刻を返す() {
        // 2026-07-09 は木曜日（9-12, 13-18）
        XCTAssertEqual(
            OpeningHoursEvaluator.closingTimeIfOpen(hours: hours, at: tokyoDate(day: 9, hour: 11, minute: 0)),
            "12:00"
        )
        XCTAssertEqual(
            OpeningHoursEvaluator.closingTimeIfOpen(hours: hours, at: tokyoDate(day: 9, hour: 13, minute: 0)),
            "18:00"
        )
    }

    func test_営業中でなければnil() {
        // 時間外・定休・未登録曜日・構造化データなしのいずれも nil（判定不能な店で嘘をつかない）
        XCTAssertNil(OpeningHoursEvaluator.closingTimeIfOpen(hours: hours, at: tokyoDate(hour: 8, minute: 59)))
        XCTAssertNil(OpeningHoursEvaluator.closingTimeIfOpen(hours: hours, at: tokyoDate(day: 7, hour: 10, minute: 0)))
        XCTAssertNil(OpeningHoursEvaluator.closingTimeIfOpen(hours: hours, at: tokyoDate(day: 8, hour: 10, minute: 0)))
        XCTAssertNil(OpeningHoursEvaluator.closingTimeIfOpen(hours: nil, at: tokyoDate(hour: 10, minute: 0)))
    }

    // MARK: - 日跨ぎ営業（close <= open。S4, 22:00-2:00 のような深夜営業に対応）

    private var crossMidnightHours: OpeningHours {
        OpeningHours(
            mon: [TimeRange(open: "22:00", close: "02:00")],
            tue: nil,
            wed: nil,
            thu: nil,
            fri: [TimeRange(open: "17:00", close: "24:00")],  // 24:00終端（当日終端＝翌0:00）
            sat: nil,
            // 月曜早朝（01:00）が日曜深夜からの繰り越しとして営業中になることを検証するため、
            // 日曜も同じ枠を登録する（前日の実際の曜日を見て判定することの確認, QA指摘）
            sun: [TimeRange(open: "22:00", close: "02:00")]
        )
    }

    func test_日跨ぎ営業_深夜は営業中() {
        // 22:00-2:00 の店: 23:30は営業中
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: crossMidnightHours, at: tokyoDate(day: 6, hour: 23, minute: 30)),
            .open
        )
    }

    func test_日跨ぎ営業_日をまたいだ早朝も営業中() {
        // 22:00-2:00 の店: 01:00も営業中
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: crossMidnightHours, at: tokyoDate(day: 6, hour: 1, minute: 0)),
            .open
        )
    }

    func test_日跨ぎ営業_閉店時刻以降は時間外() {
        // 22:00-2:00 の店: 03:00は営業時間外
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: crossMidnightHours, at: tokyoDate(day: 6, hour: 3, minute: 0)),
            .outsideHours
        )
    }

    func test_日跨ぎ営業_開店前は時間外() {
        // 22:00-2:00 の店: 21:59はまだ時間外
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: crossMidnightHours, at: tokyoDate(day: 6, hour: 21, minute: 59)),
            .outsideHours
        )
    }

    func test_日跨ぎ営業_閉店時刻を返す() {
        // 22:00-2:00 の店: 01:00は営業中で閉店時刻は02:00
        XCTAssertEqual(
            OpeningHoursEvaluator.closingTimeIfOpen(hours: crossMidnightHours, at: tokyoDate(day: 6, hour: 1, minute: 0)),
            "02:00"
        )
    }

    func test_終端24時00分は当日深夜まで営業中() {
        // 2026-07-10 は金曜日（17:00-24:00）: 23:59は営業中
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: crossMidnightHours, at: tokyoDate(day: 10, hour: 23, minute: 59)),
            .open
        )
        // 開店前（16:59）は時間外
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: crossMidnightHours, at: tokyoDate(day: 10, hour: 16, minute: 59)),
            .outsideHours
        )
    }

    // MARK: - 日跨ぎ営業の繰り越し（前日の実際の曜日を見て判定する。QA指摘の再現ケース）

    func test_日跨ぎ営業_翌日が定休でも前日からの繰り越しで営業中() {
        // 2026-07-10は金曜日, 2026-07-11は土曜日。金17:00-02:00 / 土定休（空配列）
        let hours = OpeningHours(
            mon: nil, tue: nil, wed: nil, thu: nil,
            fri: [TimeRange(open: "17:00", close: "02:00")],
            sat: [],  // 土曜は新規営業なし（定休）
            sun: nil
        )
        // 土曜01:00は金曜からの繰り越しで営業中（土曜自身が定休でも前日の営業は続く）
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(day: 11, hour: 1, minute: 0)),
            .open
        )
        // 繰り越し分の閉店時刻（02:00）を過ぎれば、土曜自身は定休なので「本日定休」
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(day: 11, hour: 10, minute: 0)),
            .closedToday
        )
    }

    func test_日跨ぎ営業_前日が定休なら早朝は営業時間外() {
        // 金定休（空配列） / 土18:00-02:00
        let hours = OpeningHours(
            mon: nil, tue: nil, wed: nil, thu: nil,
            fri: [],  // 金曜は定休（前日に日跨ぎ枠なし）
            sat: [TimeRange(open: "18:00", close: "02:00")],
            sun: nil
        )
        // 土曜01:00は土曜自身の開店前（18:00より前）で、金曜からの繰り越しもない → 営業時間外
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(day: 11, hour: 1, minute: 0)),
            .outsideHours
        )
        // 日曜01:00は土曜からの繰り越しで営業中（日曜自身は未登録でも前日の実績で判定する）
        XCTAssertEqual(
            OpeningHoursEvaluator.state(hours: hours, at: tokyoDate(day: 12, hour: 1, minute: 0)),
            .open
        )
    }
}
