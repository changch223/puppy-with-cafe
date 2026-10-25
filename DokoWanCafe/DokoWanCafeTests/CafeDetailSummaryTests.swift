import XCTest
@testable import DokoWanCafe

/// 店詳細の 3つの要点・曜日別表・わんちゃん向け情報・共有文・写真の帯のユニットテスト（再設計 段階1b）
final class CafeDetailSummaryTests: XCTestCase {
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
            mon: [TimeRange(open: "09:00", close: "19:00")],
            tue: [],  // 定休
            wed: nil, // 不明
            thu: [TimeRange(open: "09:00", close: "12:00"), TimeRange(open: "13:00", close: "18:00")],
            fri: nil, sat: nil, sun: nil
        )
    }

    // MARK: - 今日

    func test_今日_営業中は閉店時刻つき() {
        let tile = CafeDetailHighlights.today(hours: hours, at: tokyoDate(hour: 10, minute: 0), timeZone: tokyo)
        XCTAssertEqual(tile.title, "今日")
        XCTAssertEqual(tile.value, "営業中・19:00まで")
        XCTAssertEqual(tile.tone, .good)
    }

    func test_今日_複数時間帯では該当枠の閉店時刻() {
        let tile = CafeDetailHighlights.today(hours: hours, at: tokyoDate(day: 9, hour: 11, minute: 0), timeZone: tokyo)
        XCTAssertEqual(tile.value, "営業中・12:00まで")
    }

    func test_今日_時間外() {
        let tile = CafeDetailHighlights.today(hours: hours, at: tokyoDate(hour: 19, minute: 0), timeZone: tokyo)
        XCTAssertEqual(tile.value, "営業時間外")
        XCTAssertEqual(tile.tone, .neutral)
    }

    func test_今日_定休() {
        let tile = CafeDetailHighlights.today(hours: hours, at: tokyoDate(day: 7, hour: 10, minute: 0), timeZone: tokyo)
        XCTAssertEqual(tile.value, "本日定休")
        XCTAssertEqual(tile.tone, .caution)
    }

    func test_今日_不明は時間の情報なし() {
        // 未登録の曜日・構造化データなしのどちらでも「営業中」と推測しない
        let unknownDay = CafeDetailHighlights.today(hours: hours, at: tokyoDate(day: 8, hour: 10, minute: 0), timeZone: tokyo)
        XCTAssertEqual(unknownDay.value, "時間の情報なし")
        XCTAssertEqual(unknownDay.tone, .unknown)
        XCTAssertEqual(CafeDetailHighlights.today(hours: nil, at: tokyoDate(hour: 10, minute: 0), timeZone: tokyo).value, "時間の情報なし")
    }

    func test_今日_曜日別がなくhours_textだけの店は営業時間は下記() {
        let tile = CafeDetailHighlights.today(
            hours: nil, hoursText: "11:00〜22:00(L.O.21:00)", at: tokyoDate(hour: 10, minute: 0), timeZone: tokyo
        )
        XCTAssertEqual(tile.value, "営業時間は下記")
        XCTAssertEqual(tile.tone, .neutral)
        // hours_text も空白だけなら時間の情報なし
        let blank = CafeDetailHighlights.today(
            hours: OpeningHours(), hoursText: "  ", at: tokyoDate(hour: 10, minute: 0), timeZone: tokyo
        )
        XCTAssertEqual(blank.value, "時間の情報なし")
        XCTAssertEqual(
            CafeDetailHighlights.today(hours: nil, hoursText: nil, at: tokyoDate(hour: 10, minute: 0), timeZone: tokyo).value,
            "時間の情報なし"
        )
    }

    func test_今日_曜日別があれば営業中の判定を優先する() {
        let tile = CafeDetailHighlights.today(
            hours: hours, hoursText: "原文", at: tokyoDate(hour: 10, minute: 0), timeZone: tokyo
        )
        XCTAssertEqual(tile.value, "営業中・19:00まで")
    }

    // MARK: - 予約・大型犬

    func test_予約_なければ情報なし() {
        XCTAssertEqual(CafeDetailHighlights.reservation(nil).value, "情報なし")
        XCTAssertEqual(CafeDetailHighlights.reservation("  ").value, "情報なし")
        XCTAssertEqual(CafeDetailHighlights.reservation(nil).tone, .unknown)
    }

    func test_予約_短い文はそのまま長い文は省略() {
        XCTAssertEqual(CafeDetailHighlights.reservation("予約可（電話）").value, "予約可（電話）")
        let long = String(repeating: "あ", count: 40)
        let tile = CafeDetailHighlights.reservation(long)
        XCTAssertEqual(tile.value.count, CafeDetailHighlights.reservationMaxLength)
        XCTAssertTrue(tile.value.hasSuffix("…"))
    }

    func test_予約_複数行なら最初の行() {
        XCTAssertEqual(CafeDetailHighlights.reservation("予約不可\n当日のみ受付").value, "予約不可")
    }

    func test_大型犬_可_不可_情報なし() {
        XCTAssertEqual(CafeDetailHighlights.largeDogs(true).value, "可")
        XCTAssertEqual(CafeDetailHighlights.largeDogs(false).value, "不可")
        XCTAssertEqual(CafeDetailHighlights.largeDogs(nil).value, "情報なし")
        XCTAssertEqual(CafeDetailHighlights.largeDogs(true).title, "大型犬")
    }

    func test_大型犬_未確認の店は可と言い切らず中立の記載あり() {
        let yes = CafeDetailHighlights.largeDogs(true, confirmed: false)
        XCTAssertEqual(yes.value, "記載あり（未確認）")
        XCTAssertEqual(yes.tone, .neutral)
        let no = CafeDetailHighlights.largeDogs(false, confirmed: false)
        XCTAssertEqual(no.value, "記載あり（未確認）")
        XCTAssertEqual(no.tone, .neutral)
        // 記載がなければ未確認でも情報なし
        XCTAssertEqual(CafeDetailHighlights.largeDogs(nil, confirmed: false).value, "情報なし")
    }

    func test_大型犬_サイズ制限の記載がある店は条件つきで可() {
        let tile = CafeDetailHighlights.largeDogs(true, confirmed: true, hasSizeLimit: true)
        XCTAssertEqual(tile.value, "条件つきで可")
        XCTAssertNotEqual(tile.tone, .good)
    }

    func test_要点タイル_確認日なしの店の大型犬は緑にならない() {
        var cafe = makeCafe()
        cafe.dogAmenities = DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil)
        cafe.lastVerified = nil
        let tile = CafeDetailHighlights.all(cafe: cafe, at: tokyoDate(hour: 10, minute: 0), timeZone: tokyo)[2]
        XCTAssertEqual(tile.value, "記載あり（未確認）")
        XCTAssertNotEqual(tile.tone, .good)

        cafe.lastVerified = Date(timeIntervalSince1970: 1_780_000_000)
        let confirmed = CafeDetailHighlights.all(cafe: cafe, at: tokyoDate(hour: 10, minute: 0), timeZone: tokyo)[2]
        XCTAssertEqual(confirmed.value, "可")
        XCTAssertEqual(confirmed.tone, .good)
    }

    func test_わんちゃん向け情報_未確認の店は可を緑の可にしない() {
        let rows = CafeDetailAmenities.rows(
            DogAmenities(indoor: true, terrace: false, largeDogs: nil, dogMenu: true), confirmed: false
        )
        XCTAssertEqual(rows.map(\.state), [.unconfirmed, .unconfirmed, .unknown, .unconfirmed])
        XCTAssertEqual(rows.map(\.valueText), ["記載あり（未確認）", "記載あり（未確認）", "情報なし", "記載あり（未確認）"])
    }

    // MARK: - 曜日別の表

    func test_曜日表_7行で今日だけ強調され不明は横線() {
        let rows = CafeDetailHoursTable.rows(hours: hours, at: tokyoDate(hour: 10, minute: 0), timeZone: tokyo)
        XCTAssertEqual(rows.map(\.weekday), Weekday.allCases)
        XCTAssertEqual(rows.filter(\.isToday).map(\.weekday), [.mon])
        XCTAssertEqual(rows[0].text, "09:00〜19:00")
        XCTAssertEqual(rows[1].text, "定休")
        XCTAssertEqual(rows[2].text, "—")
        XCTAssertEqual(rows[3].text, "09:00〜12:00, 13:00〜18:00")
    }

    // MARK: - わんちゃん向け情報

    func test_わんちゃん向け情報_状態を言葉で出す() {
        let rows = CafeDetailAmenities.rows(
            DogAmenities(indoor: false, terrace: true, largeDogs: nil, dogMenu: nil)
        )
        XCTAssertEqual(rows.map(\.label), ["店内", "テラス", "大型犬", "犬メニュー"])
        XCTAssertEqual(rows.map(\.valueText), ["不可", "可", "情報なし", "情報なし"])
        XCTAssertEqual(rows.map(\.state), [.no, .yes, .unknown, .unknown])
    }

    func test_わんちゃん向け情報_犬メニューはありなし() {
        let rows = CafeDetailAmenities.rows(
            DogAmenities(indoor: nil, terrace: nil, largeDogs: nil, dogMenu: true)
        )
        XCTAssertEqual(rows[3].valueText, "あり")
        let none = CafeDetailAmenities.rows(
            DogAmenities(indoor: nil, terrace: nil, largeDogs: nil, dogMenu: false)
        )
        XCTAssertEqual(none[3].valueText, "なし")
    }

    // MARK: - 共有文

    private func makeCafe(name: String = "テストカフェ", address: String? = "東京都渋谷区1-2-3") -> Cafe {
        Cafe(
            id: UUID(), placeID: nil, name: name,
            latitude: 35.6595, longitude: 139.7005,
            address: address, contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo"
        )
    }

    func test_共有文は店名_住所_地図URL_アプリ名の順() {
        let message = CafeDetailShare.message(for: makeCafe())
        XCTAssertEqual(
            message,
            """
            テストカフェ
            東京都渋谷区1-2-3
            https://www.google.com/maps/search/?api=1&query=35.6595,139.7005
            Puppy With Cafe で見つけました
            """
        )
    }

    func test_共有文は住所がなければ省く() {
        let message = CafeDetailShare.message(for: makeCafe(address: nil))
        XCTAssertEqual(message.split(separator: "\n").count, 3)
        XCTAssertFalse(message.contains("東京都"))
        let blank = CafeDetailShare.message(for: makeCafe(address: "  "))
        XCTAssertEqual(blank.split(separator: "\n").count, 3)
    }

    func test_地図URLは座標で作る() {
        XCTAssertEqual(
            CafeDetailShare.mapsURL(for: makeCafe())?.absoluteString,
            "https://www.google.com/maps/search/?api=1&query=35.6595,139.7005"
        )
    }

    // MARK: - 写真の帯

    func test_帯の色は同じ店IDなら常に同じ() {
        let id = UUID()
        XCTAssertEqual(CafeDetailBand.hue(for: id), CafeDetailBand.hue(for: id))
        let fixed = UUID(uuidString: "C0000000-0000-4000-8000-000000000002")!
        XCTAssertEqual(CafeDetailBand.hue(for: fixed), CafeDetailBand.hue(for: fixed))
        XCTAssertTrue(CafeDetailBand.hues.contains(CafeDetailBand.hue(for: fixed)))
    }

    func test_帯の色は店IDによって変わりうる() {
        let hues = Set((0..<50).map { _ in CafeDetailBand.hue(for: UUID()) })
        XCTAssertGreaterThan(hues.count, 1)
    }

    func test_頭文字は先頭の記号と空白を飛ばす() {
        XCTAssertEqual(CafeDetailBand.initial(of: "君のハンバーグを食べたい渋谷店"), "君")
        XCTAssertEqual(CafeDetailBand.initial(of: "  「カフェ」"), "カ")
        XCTAssertEqual(CafeDetailBand.initial(of: "aina cafe"), "A")
        XCTAssertEqual(CafeDetailBand.initial(of: "★☆"), "")
        XCTAssertEqual(CafeDetailBand.initial(of: ""), "")
    }

    func test_小さい画像は写真として使わない() {
        XCTAssertFalse(CafeDetailBand.isUsablePhoto(size: CGSize(width: 64, height: 64)))
        XCTAssertFalse(CafeDetailBand.isUsablePhoto(size: CGSize(width: 800, height: 100)))
        XCTAssertTrue(CafeDetailBand.isUsablePhoto(size: CGSize(width: 800, height: 420)))
    }
}
