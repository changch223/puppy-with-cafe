import XCTest
@testable import DokoWanCafe

/// 店詳細の「答えのカード」と根拠1行のユニットテスト（再設計 段階1b, 憲章 原則I・IV）
final class CafeDetailAnswerTests: XCTestCase {
    private func makeCafe(
        status: DogPolicyStatus = .allowed,
        condition: String? = nil,
        amenities: DogAmenities? = nil,
        sizeLimit: String? = nil,
        lastVerified: Date? = Date(timeIntervalSince1970: 1_780_000_000)
    ) -> Cafe {
        Cafe(
            id: UUID(), placeID: nil, name: "テストカフェ",
            latitude: 35.68, longitude: 139.76,
            address: nil, contact: nil,
            dogPolicyStatus: status, dogPolicyCondition: condition,
            lastVerified: lastVerified, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo",
            dogAmenities: amenities, dogSizeLimit: sizeLimit
        )
    }

    private func amenities(
        indoor: Bool? = nil, terrace: Bool? = nil, largeDogs: Bool? = nil
    ) -> DogAmenities {
        DogAmenities(indoor: indoor, terrace: terrace, largeDogs: largeDogs, dogMenu: nil)
    }

    // MARK: - 答えのカード

    func test_店内が可なら店内で一緒に過ごせます() {
        let answer = CafeDetailAnswer.make(cafe: makeCafe(amenities: amenities(indoor: true)))
        XCTAssertEqual(answer.kind, .indoor)
        XCTAssertEqual(answer.headline, "店内で一緒に過ごせます")
        XCTAssertTrue(answer.notes.isEmpty)
    }

    func test_店内もテラスも可なら店内が優先() {
        let answer = CafeDetailAnswer.make(
            cafe: makeCafe(status: .conditional, amenities: amenities(indoor: true, terrace: true))
        )
        XCTAssertEqual(answer.kind, .indoor)
    }

    func test_店内が不可でテラスが可ならテラス席で店内は不可を添える() {
        let answer = CafeDetailAnswer.make(
            cafe: makeCafe(status: .conditional, amenities: amenities(indoor: false, terrace: true))
        )
        XCTAssertEqual(answer.kind, .terrace)
        XCTAssertEqual(answer.headline, "テラス席で一緒に過ごせます")
        XCTAssertEqual(answer.notes, ["店内は不可"])
    }

    func test_店内が不明でテラスが可ならテラス席だが店内は不可とは言わない() {
        let answer = CafeDetailAnswer.make(
            cafe: makeCafe(amenities: amenities(indoor: nil, terrace: true))
        )
        XCTAssertEqual(answer.kind, .terrace)
        XCTAssertFalse(answer.notes.contains("店内は不可"))
    }

    func test_店内が不明のとき店内で一緒にとは言わない() {
        // 憲章 原則I: indoor が nil なら緑の「店内で一緒に…」を出さない
        let cafes = [
            makeCafe(status: .allowed, amenities: nil),
            makeCafe(status: .allowed, amenities: amenities(indoor: nil, terrace: nil)),
            makeCafe(status: .conditional, amenities: amenities(indoor: nil, terrace: nil)),
            makeCafe(status: .allowed, amenities: amenities(indoor: false, terrace: false)),
        ]
        for cafe in cafes {
            XCTAssertNotEqual(CafeDetailAnswer.make(cafe: cafe).kind, .indoor)
        }
    }

    func test_条件つきで席の種類が不明なら条件つきで一緒に入れます() {
        let answer = CafeDetailAnswer.make(
            cafe: makeCafe(status: .conditional, condition: "ケージ・カート利用", amenities: nil)
        )
        XCTAssertEqual(answer.kind, .conditional)
        XCTAssertEqual(answer.headline, "条件つきで一緒に入れます")
        XCTAssertEqual(answer.conditionLine, "ケージ・カート利用")
    }

    func test_可だが席の種類が不明なら席の種類は確認中と添える() {
        let answer = CafeDetailAnswer.make(cafe: makeCafe(status: .allowed, amenities: nil))
        XCTAssertEqual(answer.kind, .seatUnknown)
        XCTAssertEqual(answer.notes, ["席の種類は確認中"])
    }

    func test_未確認は設備が可でも確認中() {
        let answer = CafeDetailAnswer.make(
            cafe: makeCafe(
                status: .unverified,
                condition: "何かの条件",
                amenities: amenities(indoor: true, terrace: true, largeDogs: true)
            )
        )
        XCTAssertEqual(answer.kind, .unverified)
        XCTAssertEqual(answer.headline, "犬同伴の情報を確認中です")
        XCTAssertNil(answer.conditionLine)
        XCTAssertTrue(answer.notes.isEmpty)
    }

    func test_犬不可なら一緒に過ごせるとは言わない() {
        let answer = CafeDetailAnswer.make(
            cafe: makeCafe(status: .notAllowed, amenities: amenities(indoor: true))
        )
        XCTAssertEqual(answer.kind, .notAllowed)
        XCTAssertNil(answer.conditionLine)
    }

    func test_大型犬が可なら大型犬もOKを添える() {
        let indoor = CafeDetailAnswer.make(cafe: makeCafe(amenities: amenities(indoor: true, largeDogs: true)))
        XCTAssertEqual(indoor.notes, ["大型犬もOK"])

        let terrace = CafeDetailAnswer.make(
            cafe: makeCafe(amenities: amenities(indoor: false, terrace: true, largeDogs: true))
        )
        XCTAssertEqual(terrace.notes, ["店内は不可", "大型犬もOK"])
    }

    func test_大型犬が不可または不明なら添えない() {
        for large in [false, nil] as [Bool?] {
            let answer = CafeDetailAnswer.make(
                cafe: makeCafe(amenities: amenities(indoor: true, largeDogs: large))
            )
            XCTAssertFalse(answer.notes.contains("大型犬もOK"))
        }
    }

    func test_条件の要点は条件文_サイズ制限は別の行() {
        let both = CafeDetailAnswer.make(
            cafe: makeCafe(condition: "要予約", amenities: amenities(indoor: true), sizeLimit: "小型犬のみ")
        )
        XCTAssertEqual(both.conditionLine, "要予約")
        XCTAssertEqual(both.sizeLimitLine, "小型犬のみ")

        let sizeOnly = CafeDetailAnswer.make(
            cafe: makeCafe(amenities: amenities(indoor: true), sizeLimit: "小型犬のみ")
        )
        XCTAssertNil(sizeOnly.conditionLine)
        XCTAssertEqual(sizeOnly.sizeLimitLine, "小型犬のみ")

        let blank = CafeDetailAnswer.make(
            cafe: makeCafe(condition: "  ", amenities: amenities(indoor: true), sizeLimit: " ")
        )
        XCTAssertNil(blank.conditionLine)
        XCTAssertNil(blank.sizeLimitLine)
    }

    func test_条件とサイズ制限が同文なら1回だけ出す() {
        let answer = CafeDetailAnswer.make(
            cafe: makeCafe(condition: "小型犬のみ", amenities: amenities(indoor: true), sizeLimit: "小型犬のみ")
        )
        XCTAssertEqual(answer.conditionLine, "小型犬のみ")
        XCTAssertNil(answer.sizeLimitLine)
    }

    func test_サイズ制限の記載がある店は大型犬もOKを添えない() {
        // The House of Hounds 相当: 大型犬はテラス・屋上席のみ（largeDogs は true だが席の制限つき）
        let answer = CafeDetailAnswer.make(
            cafe: makeCafe(
                status: .conditional,
                condition: "要予約",
                amenities: amenities(indoor: false, terrace: true, largeDogs: true),
                sizeLimit: "大型犬はテラス・屋上席のみ"
            )
        )
        XCTAssertEqual(answer.kind, .terrace)
        XCTAssertEqual(answer.notes, ["店内は不可"])
        XCTAssertEqual(answer.conditionLine, "要予約")
        XCTAssertEqual(answer.sizeLimitLine, "大型犬はテラス・屋上席のみ")
    }

    func test_確認日がない店は設備が可でも確認中() {
        let answer = CafeDetailAnswer.make(
            cafe: makeCafe(
                status: .allowed,
                amenities: amenities(indoor: true, terrace: true, largeDogs: true),
                lastVerified: nil
            )
        )
        XCTAssertEqual(answer.kind, .unverified)
        XCTAssertEqual(answer.headline, "犬同伴の情報を確認中です")
        XCTAssertTrue(answer.notes.isEmpty)
        XCTAssertFalse(CafeDetailAnswer.isConfirmed(makeCafe(lastVerified: nil)))
        XCTAssertFalse(CafeDetailAnswer.isConfirmed(makeCafe(status: .unverified)))
        XCTAssertTrue(CafeDetailAnswer.isConfirmed(makeCafe()))
    }

    func test_可で店内が不可かつテラスが可でない店は店内は不可だけ添える() {
        for terrace in [nil, false] as [Bool?] {
            let answer = CafeDetailAnswer.make(
                cafe: makeCafe(status: .allowed, amenities: amenities(indoor: false, terrace: terrace))
            )
            XCTAssertEqual(answer.kind, .seatUnknown)
            XCTAssertEqual(answer.headline, "犬連れで利用できます")
            XCTAssertEqual(answer.notes, ["店内は不可"])
        }
    }

    func test_条件つきで店内が不可かつテラスが可でない店も店内は不可を添える() {
        let answer = CafeDetailAnswer.make(
            cafe: makeCafe(status: .conditional, amenities: amenities(indoor: false, terrace: nil, largeDogs: true))
        )
        XCTAssertEqual(answer.kind, .conditional)
        XCTAssertEqual(answer.notes, ["店内は不可", "大型犬もOK"])
    }

    // MARK: - 根拠の1行

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.timeZone = tokyo
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        return calendar.date(from: components)!
    }

    func test_根拠の文は出典の種類と確認年月() {
        let verified = date(year: 2026, month: 8, day: 14)
        let expected: [(SourceType, String)] = [
            (.officialHP, "公式サイトで確認・2026年8月"),
            (.sns, "公式SNSで確認・2026年8月"),
            (.tabelog, "食べログで確認・2026年8月"),
            (.blog, "ブログで確認・2026年8月"),
            (.other, "その他の出典で確認・2026年8月"),
            (.googleMap, "その他の出典で確認・2026年8月"),
        ]
        for (type, text) in expected {
            let evidence = CafeDetailEvidence.make(
                sourceType: type, lastVerified: verified, hasConflict: false, timeZone: tokyo
            )
            XCTAssertEqual(evidence.text, text)
            XCTAssertFalse(evidence.hasConflict)
        }
    }

    func test_確認日がないときは確認日の記録なしと書く() {
        let evidence = CafeDetailEvidence.make(
            sourceType: .officialHP, lastVerified: nil, hasConflict: false, timeZone: tokyo
        )
        XCTAssertEqual(evidence.text, "公式サイトで確認（確認日の記録なし）")
    }

    func test_出典の種類が不明でも確認日があれば年月だけ出す() {
        let evidence = CafeDetailEvidence.make(
            sourceType: nil, lastVerified: date(year: 2026, month: 1, day: 3), hasConflict: false, timeZone: tokyo
        )
        XCTAssertEqual(evidence.text, "2026年1月に確認")
    }

    func test_出典も確認日もなければ記録なし() {
        let evidence = CafeDetailEvidence.make(
            sourceType: nil, lastVerified: nil, hasConflict: false, timeZone: tokyo
        )
        XCTAssertEqual(evidence.text, "確認の記録がありません")
    }

    func test_出典も確認日もなく食い違いがあれば食い違いを伝える() {
        let evidence = CafeDetailEvidence.make(
            sourceType: nil, lastVerified: nil, hasConflict: true, timeZone: tokyo
        )
        XCTAssertEqual(evidence.text, "出典の記載が食い違っています")
        XCTAssertTrue(evidence.textIsWarning)
        // 文そのものが警告なので「出典に食い違いあり」は重ねない
        XCTAssertFalse(evidence.hasConflict)
    }

    func test_食い違いありはフラグが立つ() {
        let evidence = CafeDetailEvidence.make(
            sourceType: .tabelog, lastVerified: date(year: 2026, month: 8, day: 1), hasConflict: true, timeZone: tokyo
        )
        XCTAssertTrue(evidence.hasConflict)
        XCTAssertEqual(evidence.text, "食べログで確認・2026年8月")
    }

    func test_年月は東京時間で数える() {
        // 2026-07-31 23:30 UTC = 東京の 2026-08-01 08:30 → 8月
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 31
        components.hour = 23
        components.minute = 30
        components.timeZone = TimeZone(identifier: "UTC")
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let instant = utc.date(from: components)!
        XCTAssertEqual(CafeDetailEvidence.yearMonthText(instant, timeZone: tokyo), "2026年8月")
    }
}
