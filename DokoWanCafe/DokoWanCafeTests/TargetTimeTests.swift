import XCTest
@testable import DokoWanCafe

/// 「いつ行く？」の対象時刻の組み立て・文言（純関数）のユニットテスト（再設計 段階2）。
/// 2026-10-25 は日曜日。日付・曜日は東京時間で数える。
final class TargetTimeTests: XCTestCase {
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func tokyoDate(month: Int = 10, day: Int, hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        return calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    /// 日曜 10/25 15:00
    private var sunday3pm: Date { tokyoDate(day: 25, hour: 15) }

    // MARK: - 日の選択肢

    func test_日の選択肢は今日明日とその先5日分の曜日() {
        let options = TargetTime.dayOptions(now: sunday3pm)
        XCTAssertEqual(options.map(\.title), ["今日", "明日", "火", "水", "木", "金", "土"])
        XCTAssertEqual(options.map(\.dateText), ["10/25", "10/26", "10/27", "10/28", "10/29", "10/30", "10/31"])
        XCTAssertEqual(options.map(\.offset), [0, 1, 2, 3, 4, 5, 6])
    }

    func test_月をまたぐ日付() {
        let options = TargetTime.dayOptions(now: tokyoDate(day: 30, hour: 9))
        XCTAssertEqual(options.map(\.dateText), ["10/30", "10/31", "11/1", "11/2", "11/3", "11/4", "11/5"])
        XCTAssertEqual(options.map(\.title), ["今日", "明日", "日", "月", "火", "水", "木"])
    }

    func test_深夜0時台はUTCでは前日でも東京の日付で数える() {
        // 日曜 00:30（東京）= 土曜 15:30（UTC）
        let options = TargetTime.dayOptions(now: tokyoDate(day: 25, hour: 0, minute: 30))
        XCTAssertEqual(options.first?.dateText, "10/25")
        XCTAssertEqual(options[2].title, "火")
    }

    // MARK: - 対象時刻の組み立て

    func test_今日と明日の時刻を組み立てる() {
        XCTAssertEqual(TargetTime.date(dayOffset: 0, minutes: 12 * 60, now: sunday3pm), tokyoDate(day: 25, hour: 12))
        XCTAssertEqual(TargetTime.date(dayOffset: 1, minutes: 9 * 60 + 30, now: sunday3pm), tokyoDate(day: 26, hour: 9, minute: 30))
    }

    func test_曜日の選択肢は次の該当日の時刻になる() {
        // 日曜から見た「土」= 6日後の 10/31
        let saturday = TargetTime.dayOptions(now: sunday3pm).last!
        XCTAssertEqual(saturday.title, "土")
        let target = TargetTime.date(dayOffset: saturday.offset, minutes: 12 * 60, now: sunday3pm)
        XCTAssertEqual(target, tokyoDate(day: 31, hour: 12))
        XCTAssertEqual(TargetTime.shortLabel(target!), "土 12:00")
    }

    func test_日跨ぎの深夜帯の時刻は翌日扱いにならずその日の0時台() {
        let target = TargetTime.date(dayOffset: 1, minutes: 30, now: sunday3pm)
        XCTAssertEqual(target, tokyoDate(day: 26, hour: 0, minute: 30))
        XCTAssertEqual(TargetTime.shortLabel(target!), "月 0:30")

        // 日曜 00:30 の「今日」は日曜の0:30（UTCの土曜ではない）
        let early = TargetTime.date(dayOffset: 0, minutes: 30, now: tokyoDate(day: 25, hour: 0, minute: 10))
        XCTAssertEqual(early, tokyoDate(day: 25, hour: 0, minute: 30))
    }

    func test_深夜帯の対象時刻は前日の日跨ぎ営業を拾う() {
        // 土曜 18:00-翌2:00 の店は、日曜 1:00 に営業中・日曜 3:00 は時間外
        let hours = OpeningHours(
            mon: nil, tue: nil, wed: nil, thu: nil, fri: nil,
            sat: [TimeRange(open: "18:00", close: "02:00")], sun: nil
        )
        let sunday1am = TargetTime.date(dayOffset: 0, minutes: 60, now: sunday3pm)!
        XCTAssertEqual(OpeningHoursEvaluator.state(hours: hours, at: sunday1am), .open)
        let sunday3am = TargetTime.date(dayOffset: 0, minutes: 180, now: sunday3pm)!
        XCTAssertNotEqual(OpeningHoursEvaluator.state(hours: hours, at: sunday3am), .open)
    }

    func test_範囲外の日や分は組み立てない() {
        XCTAssertNil(TargetTime.date(dayOffset: 7, minutes: 0, now: sunday3pm))
        XCTAssertNil(TargetTime.date(dayOffset: -1, minutes: 0, now: sunday3pm))
        XCTAssertNil(TargetTime.date(dayOffset: 0, minutes: 24 * 60, now: sunday3pm))
    }

    func test_対象時刻を選択に戻せる() {
        let target = tokyoDate(day: 28, hour: 18, minute: 30)
        let selection = TargetTime.selection(of: target, now: sunday3pm)
        XCTAssertEqual(selection?.dayOffset, 3)
        XCTAssertEqual(selection?.minutes, 18 * 60 + 30)
        // 開いたまま日が進んで選択肢の範囲外になった対象時刻は nil
        XCTAssertNil(TargetTime.selection(of: tokyoDate(month: 11, day: 20, hour: 9), now: sunday3pm))
        XCTAssertNil(TargetTime.selection(of: tokyoDate(day: 24, hour: 9), now: sunday3pm))
    }

    // MARK: - 時刻の選択肢・文言

    func test_時刻は30分刻みで0時から23時30分まで() {
        XCTAssertEqual(TargetTime.timeChoices.count, 48)
        XCTAssertEqual(TargetTime.timeChoices.first, 0)
        XCTAssertEqual(TargetTime.timeChoices.last, 23 * 60 + 30)
        XCTAssertTrue(TargetTime.timeChoices.allSatisfy { $0 % 30 == 0 })
    }

    func test_プリセットは朝昼午後夜() {
        XCTAssertEqual(TargetTime.presets.map(\.label), ["朝 9時", "昼 12時", "午後 15時", "夜 18時"])
        XCTAssertEqual(TargetTime.presets.map(\.minutes), [540, 720, 900, 1080])
        XCTAssertTrue(TargetTime.presets.allSatisfy { TargetTime.timeChoices.contains($0.minutes) })
    }

    func test_ラベル() {
        let saturdayNoon = tokyoDate(day: 31, hour: 12)
        XCTAssertEqual(TargetTime.shortLabel(saturdayNoon), "土 12:00")
        XCTAssertEqual(TargetTime.longLabel(saturdayNoon), "土曜 12:00")
        XCTAssertEqual(TargetTime.shortLabel(tokyoDate(day: 25, hour: 9, minute: 30)), "日 9:30")
        XCTAssertEqual(TargetTime.monthDayText(saturdayNoon), "10/31")
    }

    func test_ボタン文言は件数を出し0件は理由を言う() {
        let saturdayNoon = tokyoDate(day: 31, hour: 12)
        XCTAssertEqual(TargetTime.applyButtonTitle(target: saturdayNoon, count: 42), "土曜 12:00 に開いている 42件を表示")
        XCTAssertEqual(TargetTime.applyButtonTitle(target: nil, count: 7), "今開いている 7件を表示")
        XCTAssertEqual(TargetTime.applyButtonTitle(target: saturdayNoon, count: 0), "この時間に開いているお店はありません")
        XCTAssertEqual(TargetTime.applyButtonTitle(target: nil, count: 0), "この時間に開いているお店はありません")
    }

    // MARK: - 営業の行（対象時刻）

    private var saturdayHours: OpeningHours {
        OpeningHours(
            mon: nil, tue: [], wed: nil, thu: nil, fri: nil,
            sat: [TimeRange(open: "09:00", close: "19:00")], sun: nil
        )
    }

    func test_対象時刻の営業の行() {
        let saturdayNoon = tokyoDate(day: 31, hour: 12)
        let open = OpenLine.make(hours: saturdayHours, at: saturdayNoon, isTargetTime: true)
        XCTAssertEqual(open.text, "土 12:00 は営業中・19:00まで")
        XCTAssertEqual(open.state, .open)
        XCTAssertEqual(open.spokenText, "土 12:00 は営業中19時まで")

        let outside = OpenLine.make(hours: saturdayHours, at: tokyoDate(day: 31, hour: 20), isTargetTime: true)
        XCTAssertEqual(outside.text, "土 20:00 は営業時間外")
        XCTAssertEqual(outside.state, .outsideHours)

        let closed = OpenLine.make(hours: saturdayHours, at: tokyoDate(day: 27, hour: 12), isTargetTime: true)
        XCTAssertEqual(closed.text, "火曜は定休")
        XCTAssertEqual(closed.state, .closedToday)

        let unknown = OpenLine.make(hours: nil, at: saturdayNoon, isTargetTime: true)
        XCTAssertEqual(unknown.text, "時間の情報なし")
        XCTAssertEqual(unknown.state, .unknown)
    }

    func test_対象時刻でなければ今の言い方のまま() {
        let line = OpenLine.make(hours: saturdayHours, at: tokyoDate(day: 31, hour: 12))
        XCTAssertEqual(line.text, "営業中・19:00まで")
        XCTAssertEqual(OpenLine.make(hours: saturdayHours, at: tokyoDate(day: 27, hour: 12)).text, "本日定休")
    }

    // MARK: - 見出し・VoiceOver

    func test_見出しは対象時刻に開いている店と言う() {
        let text = SheetHeadline.make(
            count: 42, amenities: AmenityFilter(), openNowOnly: true, targetLabel: "土 12:00",
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(text.title, "土 12:00 に開いている犬OKのお店 42件")

        let withAmenity = SheetHeadline.make(
            count: 5, amenities: AmenityFilter(indoorOnly: true), openNowOnly: true, targetLabel: "土 12:00",
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(withAmenity.title, "土 12:00 に開いている、店内OKのお店 5件")

        let unverified = SheetHeadline.make(
            count: 8, amenities: AmenityFilter(), openNowOnly: true, targetLabel: "土 12:00", includeUnverified: true,
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(unverified.title, "土 12:00 に開いている犬同伴のお店 8件（未確認を含む）")
    }

    func test_営業中がオフなら対象時刻があっても見出しは条件だけ() {
        let text = SheetHeadline.make(
            count: 100, amenities: AmenityFilter(), openNowOnly: false, targetLabel: "土 12:00",
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(text.title, "犬OKのお店 100件")
    }
}
