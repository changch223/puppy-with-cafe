import XCTest
@testable import DokoWanCafe

/// 行・カードの表示用ロジック（タグ・答えの1行・条件の要点・営業の行・電話リンク・VoiceOver）のユニットテスト
final class CafePresentationTests: XCTestCase {
    private func makeCafe(
        name: String = "テストカフェ",
        id: UUID = UUID(),
        status: DogPolicyStatus = .allowed,
        condition: String? = nil,
        sizeLimit: String? = nil,
        lastVerified: Date? = nil,
        amenities: DogAmenities? = nil,
        hours: OpeningHours? = nil,
        phone: String? = nil
    ) -> Cafe {
        Cafe(
            id: id, placeID: nil, name: name,
            latitude: 35.68, longitude: 139.76,
            address: nil, contact: nil,
            dogPolicyStatus: status, dogPolicyCondition: condition,
            lastVerified: lastVerified, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo",
            phone: phone, hours: hours, dogAmenities: amenities, dogSizeLimit: sizeLimit
        )
    }

    /// 2026-07-06（月曜）の東京時間
    private func monday(hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026; components.month = 7; components.day = 6
        components.hour = hour; components.minute = minute
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(from: components)!
    }

    private var mondayHours: OpeningHours {
        OpeningHours(mon: [TimeRange(open: "09:00", close: "19:00")], tue: [], wed: nil, thu: nil, fri: nil, sat: nil, sun: nil)
    }

    // MARK: - タグ・条件の要点

    func test_ピンの分類は店内が不可かどうかに関わらずテラスは同じ() {
        let indoorNo = makeCafe(amenities: DogAmenities(indoor: false, terrace: true, largeDogs: nil, dogMenu: nil))
        let indoorUnknown = makeCafe(amenities: DogAmenities(indoor: nil, terrace: true, largeDogs: nil, dogMenu: nil))
        XCTAssertEqual(MapPinCategory.category(for: indoorNo), .terraceOnly)
        XCTAssertEqual(MapPinCategory.category(for: indoorUnknown), .terraceOnly)
    }

    func test_大型犬OKの前提はサイズの条件が書かれていない店() {
        let plain = makeCafe(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil))
        XCTAssertTrue(CafePresentation.showsLargeDogTag(for: plain))
        let limited = makeCafe(sizeLimit: "体重10kgまで", amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil))
        XCTAssertFalse(CafePresentation.showsLargeDogTag(for: limited))
        // サイズ制限が空白だけなら条件なしとして扱う
        let blank = makeCafe(sizeLimit: "  ", amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil))
        XCTAssertTrue(CafePresentation.showsLargeDogTag(for: blank))
        let no = makeCafe(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: false, dogMenu: nil))
        XCTAssertFalse(CafePresentation.showsLargeDogTag(for: no))
    }

    func test_条件の要点は条件を優先しなければサイズ制限() {
        XCTAssertEqual(CafePresentation.conditionSummary(for: makeCafe(condition: "テラス席のみ", sizeLimit: "小型犬")), "テラス席のみ")
        XCTAssertEqual(CafePresentation.conditionSummary(for: makeCafe(condition: nil, sizeLimit: "小型犬")), "小型犬")
        XCTAssertEqual(CafePresentation.conditionSummary(for: makeCafe(condition: "  ", sizeLimit: "中型犬まで")), "中型犬まで")
        XCTAssertNil(CafePresentation.conditionSummary(for: makeCafe()))
    }

    // MARK: - 営業の行

    func test_営業中は閉店時刻つき() {
        let line = OpenLine.make(hours: mondayHours, at: monday(hour: 12))
        XCTAssertEqual(line.state, .open)
        XCTAssertEqual(line.text, "営業中・19:00まで")
        XCTAssertEqual(line.spokenText, "営業中19時まで")
    }

    func test_時間外_定休_不明を区別する() {
        XCTAssertEqual(OpenLine.make(hours: mondayHours, at: monday(hour: 20)).text, "営業時間外")
        // 2026-07-07 は火曜（空配列＝定休）
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday(hour: 12))!
        XCTAssertEqual(OpenLine.make(hours: mondayHours, at: tuesday).text, "本日定休")
        XCTAssertEqual(OpenLine.make(hours: nil, at: monday(hour: 12)).text, "営業時間は分かりません")
        XCTAssertEqual(OpenLine.make(hours: nil, at: monday(hour: 12)).state, .unknown)
    }

    func test_読み上げの時刻() {
        XCTAssertEqual(OpenLine.spokenTime("19:00"), "19時")
        XCTAssertEqual(OpenLine.spokenTime("19:30"), "19時30分")
    }

    // MARK: - VoiceOver

    func test_行のVoiceOverは店名答え営業徒歩を1つにまとめる() {
        // 確認日が新しく、条件の要点もない店
        let cafe = makeCafe(
            name: "テストカフェ",
            lastVerified: monday(hour: 9),
            amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil),
            hours: mondayHours
        )
        let item = CafeWithDistance(cafe: cafe, distanceMeters: 520)
        XCTAssertEqual(
            CafePresentation.accessibilityLabel(for: item, at: monday(hour: 12)),
            "テストカフェ、店内OK、営業中19時まで、徒歩約7分"
        )
        XCTAssertEqual(
            CafePresentation.accessibilityLabel(for: item, savedStatus: .wantToGo, at: monday(hour: 12)),
            "テストカフェ、行きたいに登録済み、店内OK、営業中19時まで、徒歩約7分"
        )
    }

    func test_行のVoiceOverは答えの補足と鮮度警告も読み条件文は読まない() {
        let cafe = makeCafe(
            name: "テストカフェ",
            condition: "テラス席のみ",
            lastVerified: monday(hour: 9),
            amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil, indoorStyle: [.floor]),
            hours: mondayHours
        )
        let item = CafeWithDistance(cafe: cafe, distanceMeters: 520)
        // 条件文は行から外した（カードと詳細に残る）ので読まない。補足は落とさず読む
        XCTAssertEqual(
            CafePresentation.accessibilityLabel(for: item, at: monday(hour: 12)),
            "テストカフェ、店内OK、床で待てる、営業中19時まで、徒歩約7分"
        )
        // 確認日がない店は「情報が古い可能性」も読む
        let stale = makeCafe(
            name: "テストカフェ", lastVerified: nil,
            amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil), hours: mondayHours
        )
        XCTAssertEqual(
            CafePresentation.accessibilityLabel(for: CafeWithDistance(cafe: stale, distanceMeters: 520), at: monday(hour: 12)),
            "テストカフェ、店内OK、営業中19時まで、徒歩約7分、情報が古い可能性があります"
        )
    }

    func test_行のVoiceOverはうちの子の答えを読む() {
        let cafe = makeCafe(
            name: "テストカフェ",
            lastVerified: monday(hour: 9),
            amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil),
            hours: mondayHours
        )
        let item = CafeWithDistance(cafe: cafe, distanceMeters: 520)
        XCTAssertEqual(
            CafePresentation.accessibilityLabel(for: item, at: monday(hour: 12), dog: DogProfile(size: .small)),
            "テストカフェ、うちの子は店内OK、営業中19時まで、徒歩約7分"
        )
    }

    func test_行のVoiceOverは行った日の一言と対象時刻の営業を読む() {
        let cafe = makeCafe(
            name: "テストカフェ",
            lastVerified: monday(hour: 9),
            amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil),
            hours: mondayHours
        )
        let item = CafeWithDistance(cafe: cafe, distanceMeters: 520)
        XCTAssertEqual(
            CafePresentation.accessibilityLabel(
                for: item, savedStatus: .visited, at: monday(hour: 12), isTargetTime: true, caption: "10/25 に行った"
            ),
            "テストカフェ、行った、10/25 に行った、店内OK、月 12:00 は営業中19時まで、徒歩約7分"
        )
    }

    func test_情報が古い可能性は対象時刻ではなく今で判定する() {
        // 今から見れば確認日は360日前（新しい）。対象時刻（10日後）から見ると370日前になるが、警告は今で判定する。
        let now = monday(hour: 12)
        let target = now.addingTimeInterval(10 * 24 * 60 * 60)
        let cafe = makeCafe(
            lastVerified: now.addingTimeInterval(-360 * 24 * 60 * 60),
            amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil)
        )
        let item = CafeWithDistance(cafe: cafe, distanceMeters: 520)
        let label = CafePresentation.accessibilityLabel(for: item, at: target, isTargetTime: true, clock: now)
        XCTAssertFalse(label.contains("情報が古い可能性があります"))
        // 今を渡さなければ従来どおり `at` で判定する
        XCTAssertTrue(CafePresentation.accessibilityLabel(for: item, at: target).contains("情報が古い可能性があります"))
    }

    // MARK: - 答えの1行

    private func confirmed(
        status: DogPolicyStatus = .allowed, sizeLimit: String? = nil, amenities: DogAmenities?
    ) -> Cafe {
        makeCafe(status: status, sizeLimit: sizeLimit, lastVerified: monday(hour: 9), amenities: amenities)
    }

    func test_答え_うちの子なしはカテゴリから() {
        let indoor = CafePresentation.answerLine(
            for: confirmed(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil)))
        XCTAssertEqual(indoor.main, "店内OK")
        XCTAssertEqual(indoor.tone, .indoor)
        XCTAssertNil(indoor.supplement)

        // 店内が不明のテラスは「テラスならOK」、店内が不可と分かる店だけ「テラスのみOK」
        let terraceUnknown = CafePresentation.answerLine(
            for: confirmed(amenities: DogAmenities(indoor: nil, terrace: true, largeDogs: nil, dogMenu: nil)))
        XCTAssertEqual(terraceUnknown.main, "テラスならOK")
        XCTAssertEqual(terraceUnknown.tone, .terrace)
        let terraceOnly = CafePresentation.answerLine(
            for: confirmed(amenities: DogAmenities(indoor: false, terrace: true, largeDogs: nil, dogMenu: nil)))
        XCTAssertEqual(terraceOnly.main, "テラスのみOK")

        let check = CafePresentation.answerLine(for: confirmed(amenities: nil))
        XCTAssertEqual(check.main, "条件を確認")
        XCTAssertEqual(check.tone, .attention)

        let unverified = CafePresentation.answerLine(for: makeCafe(status: .unverified))
        XCTAssertEqual(unverified.main, "未確認")
        XCTAssertEqual(unverified.tone, .unverified)
    }

    func test_答え_条件つきの店は条件ありを添える() {
        let cafe = confirmed(status: .conditional, amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil))
        XCTAssertEqual(CafePresentation.answerLine(for: cafe).main, "店内OK（条件あり）")
        XCTAssertEqual(CafePresentation.answerLine(for: cafe, dog: DogProfile(size: .small)).main, "うちの子は店内OK（条件あり）")
    }

    func test_答え_補足は過ごし方が大型犬OKより優先で1つだけ() {
        let both = confirmed(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil, indoorStyle: [.hold, .floor]))
        let line = CafePresentation.answerLine(for: both)
        // 並びは 床 → カート・キャリー → 抱っこ の先頭
        XCTAssertEqual(line.supplement, "床で待てる")
        XCTAssertEqual(line.text, "店内OK・床で待てる")
        XCTAssertEqual(line.spoken, "店内OK、床で待てる")

        let largeOnly = confirmed(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil))
        XCTAssertEqual(CafePresentation.answerLine(for: largeOnly).supplement, "大型犬OK")

        // サイズの条件が書かれた店の大型犬OKは出さない（条件つき）
        let limited = confirmed(sizeLimit: "10kgまで", amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil))
        XCTAssertNil(CafePresentation.answerLine(for: limited).supplement)

        // 過ごし方が明記されていなければ補足なし
        XCTAssertNil(CafePresentation.answerLine(
            for: confirmed(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil))).supplement)
    }

    func test_答え_大型犬OKは主文の席を大型犬でDogFit評価して入れる店だけ() {
        // Le Maghreb 型: 店内の大きさ上限は明記なし・テラスは大型犬まで・large_dogs=true → 店内は DogFit で unknown なので出さない
        let twoSeats = confirmed(amenities: DogAmenities(
            indoor: true, terrace: true, largeDogs: true, dogMenu: nil, sizeMaxTerrace: .large
        ))
        let twoSeatsLine = CafePresentation.answerLine(for: twoSeats)
        XCTAssertEqual(twoSeatsLine.main, "店内OK")
        XCTAssertNil(twoSeatsLine.supplement)
        XCTAssertEqual(DogFit.evaluate(cafe: twoSeats, dog: DogProfile(size: .large)).indoor, .unknown(.sizeNotStated))

        // 席が1つだけでサイズ上限なし → 大型犬が入れると判定できるので出す
        let indoorOnly = confirmed(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil))
        XCTAssertEqual(CafePresentation.answerLine(for: indoorOnly).supplement, "大型犬OK")
        // テラスの答えにはテラス席で評価する
        let terrace = confirmed(amenities: DogAmenities(indoor: nil, terrace: true, largeDogs: true, dogMenu: nil))
        XCTAssertEqual(CafePresentation.answerLine(for: terrace).text, "テラスならOK・大型犬OK")
        // 席を言わない答え（条件を確認）には出さない
        XCTAssertNil(CafePresentation.answerLine(for: confirmed(amenities: DogAmenities(indoor: nil, terrace: nil, largeDogs: true, dogMenu: nil))).supplement)
        // うちの子が設定済みのときは、大型犬OKの補足を一切出さない
        XCTAssertNil(CafePresentation.answerLine(for: indoorOnly, dog: DogProfile(size: .large)).supplement)
        XCTAssertNil(CafePresentation.answerLine(for: indoorOnly, dog: DogProfile(size: .small)).supplement)
    }

    func test_答え_店内が不可と分かる店には過ごし方を添えない() {
        let terrace = confirmed(amenities: DogAmenities(indoor: false, terrace: true, largeDogs: nil, dogMenu: nil, indoorStyle: [.floor]))
        XCTAssertNil(CafePresentation.answerLine(for: terrace).supplement)
    }

    func test_答え_うちの子ありはDogFitの判定に合わせる() {
        let small = DogProfile(size: .small)
        let indoor = confirmed(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil, indoorStyle: [.floor, .carrier]))
        // 店内に入れると明記 → うちの子は店内OK。過ごし方は、うちの子の設定に含まれ店に明記があるもの
        let fits = CafePresentation.answerLine(for: indoor, dog: DogProfile(size: .small, styles: [.carrier]))
        XCTAssertEqual(fits.main, "うちの子は店内OK")
        XCTAssertEqual(fits.supplement, "カート・キャリー")
        XCTAssertEqual(fits.tone, .indoor)

        // テラスだけ入れると明記
        let terrace = confirmed(amenities: DogAmenities(indoor: false, terrace: true, largeDogs: nil, dogMenu: nil))
        let terraceFit = CafePresentation.answerLine(for: terrace, dog: small)
        XCTAssertEqual(terraceFit.main, "うちの子はテラスならOK")
        XCTAssertEqual(terraceFit.tone, .terrace)

        // 入れないと明記 → DogFit の rowNote と同じ文
        let tooBig = confirmed(amenities: DogAmenities(indoor: true, terrace: false, largeDogs: nil, dogMenu: nil, sizeMaxIndoor: .small))
        let big = DogProfile(size: .large)
        let no = CafePresentation.answerLine(for: tooBig, dog: big)
        XCTAssertEqual(no.main, DogFit.evaluate(cafe: tooBig, dog: big).rowNote)
        XCTAssertEqual(no.main, "うちの子は不可（店内は小型犬まで・テラスは不可）")
        XCTAssertEqual(no.tone, .notAllowed)
        XCTAssertNil(no.supplement)

        // 判定できない → 分かりません（推測で OK と言わない）
        let unknownSize = confirmed(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil))
        let unknown = CafePresentation.answerLine(for: unknownSize, dog: big)
        XCTAssertEqual(unknown.main, "うちの子は分かりません")
        XCTAssertEqual(unknown.supplement, "店内OKの店")
        XCTAssertEqual(unknown.text, "うちの子は分かりません・店内OKの店")
        XCTAssertEqual(unknown.spoken, "うちの子は分かりません、店内OKの店")
        XCTAssertEqual(unknown.tone, .attention)
        // 席の種類は補足で残す（テラス・テラスのみ）。条件を確認・未確認は補足なし
        let terraceUnknown = confirmed(amenities: DogAmenities(indoor: nil, terrace: true, largeDogs: nil, dogMenu: nil))
        XCTAssertEqual(CafePresentation.answerLine(for: terraceUnknown, dog: big).supplement, "テラスOKの店")
        let terraceOnlyUnknown = confirmed(amenities: DogAmenities(indoor: false, terrace: true, largeDogs: nil, dogMenu: nil))
        XCTAssertEqual(CafePresentation.answerLine(for: terraceOnlyUnknown, dog: big).supplement, "テラスのみの店")
        let checkLine = CafePresentation.answerLine(for: confirmed(amenities: nil), dog: small)
        XCTAssertEqual(checkLine.main, "うちの子は分かりません")
        XCTAssertNil(checkLine.supplement)
        XCTAssertEqual(checkLine.tone, .attention)
        // 未確認の店はグレー・補足なし
        let unverifiedLine = CafePresentation.answerLine(for: makeCafe(status: .unverified), dog: small)
        XCTAssertEqual(unverifiedLine.tone, .unverified)
        XCTAssertNil(unverifiedLine.supplement)
    }

    // MARK: - あと◯分で閉店

    private func date(addingDays days: Int, hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(byAdding: .day, value: days, to: monday(hour: hour, minute: minute))!
    }

    func test_閉店まで60分以内は残り分を出す() {
        let line = OpenLine.make(hours: mondayHours, at: monday(hour: 18, minute: 20))
        XCTAssertEqual(line.state, .closingSoon)
        XCTAssertEqual(line.text, "あと40分で閉店")
        XCTAssertEqual(line.spokenText, "営業中、あと40分で閉店")
        XCTAssertTrue(line.state.isOpen)
        // 境界: ちょうど60分前は出す、61分前は「営業中・19:00まで」
        XCTAssertEqual(OpenLine.make(hours: mondayHours, at: monday(hour: 18)).text, "あと60分で閉店")
        XCTAssertEqual(OpenLine.make(hours: mondayHours, at: monday(hour: 17, minute: 59)).text, "営業中・19:00まで")
        XCTAssertEqual(OpenLine.make(hours: mondayHours, at: monday(hour: 18, minute: 59)).text, "あと1分で閉店")
    }

    func test_いつ行くの指定中はあと何分を出さない() {
        let line = OpenLine.make(hours: mondayHours, at: monday(hour: 18, minute: 20), isTargetTime: true)
        XCTAssertEqual(line.state, .open)
        XCTAssertEqual(line.text, "月 18:20 は営業中・19:00まで")
    }

    func test_日またぎ営業でも閉店までの分が正しい() {
        // 月 18:00〜翌02:00（データ上は close <= open）
        let overnight = OpeningHours(mon: [TimeRange(open: "18:00", close: "02:00")], tue: nil, wed: nil, thu: nil, fri: nil, sat: nil, sun: nil)
        // 月 23:30 → 翌 02:00 まで 150 分 → まだ出さない
        XCTAssertEqual(OpenLine.make(hours: overnight, at: monday(hour: 23, minute: 30)).text, "営業中・02:00まで")
        // 火 01:10 は月曜の枠の続き → 残り 50 分
        let carry = OpenLine.make(hours: overnight, at: date(addingDays: 1, hour: 1, minute: 10))
        XCTAssertEqual(carry.state, .closingSoon)
        XCTAssertEqual(carry.text, "あと50分で閉店")
        // 24:00 終わりの店
        let toMidnight = OpeningHours(mon: [TimeRange(open: "18:00", close: "24:00")], tue: nil, wed: nil, thu: nil, fri: nil, sat: nil, sun: nil)
        XCTAssertEqual(OpenLine.make(hours: toMidnight, at: monday(hour: 23, minute: 15)).text, "あと45分で閉店")
    }

    func test_日またぎ営業の閉店が60分以内なら当日の枠からも出す() {
        // 月 23:00〜翌 00:30: 月 23:30 は翌日の閉店まで 60 分
        let overnight = OpeningHours(mon: [TimeRange(open: "23:00", close: "00:30")], tue: nil, wed: nil, thu: nil, fri: nil, sat: nil, sun: nil)
        XCTAssertEqual(OpenLine.make(hours: overnight, at: monday(hour: 23, minute: 30)).text, "あと60分で閉店")
        XCTAssertEqual(OpenLine.make(hours: overnight, at: monday(hour: 23, minute: 5)).text, "営業中・00:30まで")
    }

    func test_続けて営業する枠は最後の閉店で数える() {
        let contiguous = OpeningHours(
            mon: [TimeRange(open: "10:00", close: "17:00"), TimeRange(open: "17:00", close: "23:00")],
            tue: nil, wed: nil, thu: nil, fri: nil, sat: nil, sun: nil
        )
        XCTAssertEqual(OpenLine.make(hours: contiguous, at: monday(hour: 16, minute: 30)).text, "営業中・23:00まで")
        XCTAssertEqual(OpenLine.make(hours: contiguous, at: monday(hour: 22, minute: 10)).text, "あと50分で閉店")
    }

    // MARK: - 電話

    func test_電話はtelのURLにする() {
        XCTAssertEqual(PhoneLink.url(for: "03-1234-5678")?.absoluteString, "tel:0312345678")
        XCTAssertEqual(PhoneLink.url(for: "+81 3-1234-5678")?.absoluteString, "tel:+81312345678")
    }

    func test_番号がないか短すぎるなら電話ボタンを出さない() {
        XCTAssertNil(PhoneLink.url(for: nil))
        XCTAssertNil(PhoneLink.url(for: ""))
        XCTAssertNil(PhoneLink.url(for: "非公開"))
        XCTAssertNil(PhoneLink.url(for: "12-34"))
    }
}
