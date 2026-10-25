import XCTest
@testable import DokoWanCafe

/// 行・カードの表示用ロジック（頭文字タイル・タグ・条件の要点・営業の行・電話リンク・VoiceOver）のユニットテスト
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

    // MARK: - 頭文字タイル

    func test_頭文字は店名の先頭の1文字() {
        XCTAssertEqual(InitialTile.character(for: "君のハンバーグ"), "君")
        XCTAssertEqual(InitialTile.character(for: "カフェ・ド・ラ"), "カ")
    }

    func test_先頭の空白や記号は飛ばし英字は大文字() {
        XCTAssertEqual(InitialTile.character(for: "  【渋谷】Cafe"), "渋")
        XCTAssertEqual(InitialTile.character(for: "(cafe) blue"), "C")
    }

    func test_店名が空なら代替の1文字() {
        XCTAssertEqual(InitialTile.character(for: ""), "店")
        XCTAssertEqual(InitialTile.character(for: "   "), "店")
    }

    func test_タイルの色は店IDから決まり同じIDなら常に同じ() {
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let first = InitialTile.colorIndex(for: id)
        XCTAssertEqual(first, InitialTile.colorIndex(for: id))
        XCTAssertTrue((0..<InitialTile.paletteSize).contains(first))
    }

    func test_色番号はパレット内に収まり複数の色に散らばる() {
        let indexes = (0..<200).map { _ in InitialTile.colorIndex(for: UUID()) }
        XCTAssertTrue(indexes.allSatisfy { (0..<InitialTile.paletteSize).contains($0) })
        XCTAssertGreaterThan(Set(indexes).count, 3)
    }

    // MARK: - タグ・条件の要点

    func test_タグは可否を1つ出し大型犬OKなら足す() {
        let indoor = makeCafe(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil))
        XCTAssertEqual(CafePresentation.tags(for: indoor).map(\.label), ["店内OK", "大型犬OK"])

        let terrace = makeCafe(amenities: DogAmenities(indoor: false, terrace: true, largeDogs: false, dogMenu: nil))
        XCTAssertEqual(CafePresentation.tags(for: terrace).map(\.label), ["テラスのみ"])

        let unknown = makeCafe(amenities: nil)
        XCTAssertEqual(CafePresentation.tags(for: unknown).map(\.label), ["条件を確認"])

        let unverified = makeCafe(status: .unverified)
        XCTAssertEqual(CafePresentation.tags(for: unverified).map(\.label), ["未確認"])
    }

    func test_テラスのみは店内が不可と分かる店だけで不明なら断定しない() {
        let indoorNo = makeCafe(amenities: DogAmenities(indoor: false, terrace: true, largeDogs: nil, dogMenu: nil))
        XCTAssertEqual(CafePresentation.categoryLabel(for: indoorNo), "テラスのみ")
        // 店内が不明（nil）でテラスが可 → 「店内は不可」と断定しない
        let indoorUnknown = makeCafe(amenities: DogAmenities(indoor: nil, terrace: true, largeDogs: nil, dogMenu: nil))
        XCTAssertEqual(CafePresentation.categoryLabel(for: indoorUnknown), "テラスOK")
        XCTAssertEqual(CafePresentation.tags(for: indoorUnknown).map(\.label), ["テラスOK"])
        // ピンの分類（形・色）はどちらも同じ「テラス」
        XCTAssertEqual(MapPinCategory.category(for: indoorNo), .terraceOnly)
        XCTAssertEqual(MapPinCategory.category(for: indoorUnknown), .terraceOnly)
    }

    func test_大型犬OKはサイズの条件が書かれた店には付けない() {
        let plain = makeCafe(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil))
        XCTAssertTrue(CafePresentation.showsLargeDogTag(for: plain))

        let limited = makeCafe(sizeLimit: "体重10kgまで", amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil))
        XCTAssertFalse(CafePresentation.showsLargeDogTag(for: limited))
        XCTAssertEqual(CafePresentation.tags(for: limited).map(\.label), ["店内OK"])

        // サイズ制限が空白だけなら条件なしとして扱う
        let blank = makeCafe(sizeLimit: "  ", amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: true, dogMenu: nil))
        XCTAssertTrue(CafePresentation.showsLargeDogTag(for: blank))

        // 大型犬が不可・不明ならもちろん出さない
        let no = makeCafe(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: false, dogMenu: nil))
        XCTAssertFalse(CafePresentation.showsLargeDogTag(for: no))
    }

    func test_大型犬の可否が不明ならタグを出さない() {
        let cafe = makeCafe(amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil))
        XCTAssertEqual(CafePresentation.tags(for: cafe).map(\.label), ["店内OK"])
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
        XCTAssertEqual(OpenLine.make(hours: nil, at: monday(hour: 12)).text, "時間の情報なし")
        XCTAssertEqual(OpenLine.make(hours: nil, at: monday(hour: 12)).state, .unknown)
    }

    func test_読み上げの時刻() {
        XCTAssertEqual(OpenLine.spokenTime("19:00"), "19時")
        XCTAssertEqual(OpenLine.spokenTime("19:30"), "19時30分")
    }

    // MARK: - VoiceOver

    func test_行のVoiceOverは店名タグ営業徒歩を1つにまとめる() {
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
            CafePresentation.accessibilityLabel(for: item, isFavorite: true, at: monday(hour: 12)),
            "テストカフェ、保存済み、店内OK、営業中19時まで、徒歩約7分"
        )
    }

    func test_行のVoiceOverは条件の要点と鮮度警告も読む() {
        let cafe = makeCafe(
            name: "テストカフェ",
            condition: "テラス席のみ",
            lastVerified: nil,
            amenities: DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: nil),
            hours: mondayHours
        )
        let item = CafeWithDistance(cafe: cafe, distanceMeters: 520)
        XCTAssertEqual(
            CafePresentation.accessibilityLabel(for: item, at: monday(hour: 12)),
            "テストカフェ、店内OK、テラス席のみ、営業中19時まで、徒歩約7分、情報が古い可能性があります"
        )
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
