import XCTest
@testable import DokoWanCafe

/// 「まだ分かっていないこと」の純ロジックのユニットテスト（憲章 原則I: 分からないことは分からないと言う）
final class CafeDetailUnknownsTests: XCTestCase {
    private let verified = Date(timeIntervalSince1970: 1_700_000_000)

    /// 確認済み・追加情報なしの店（5項目すべてが分かっていない）
    private func makeCafe(status: DogPolicyStatus = .allowed, lastVerified: Date? = Date(timeIntervalSince1970: 1_700_000_000)) -> Cafe {
        Cafe(
            id: UUID(), placeID: nil, name: "テストカフェ",
            latitude: 35.6595, longitude: 139.7005,
            address: nil, contact: nil,
            dogPolicyStatus: status, dogPolicyCondition: nil,
            lastVerified: lastVerified, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo"
        )
    }

    private let allUnknown = [
        "店内に入れるか", "大型犬が入れるか", "予約が要るか", "営業時間", "犬用メニューがあるか",
    ]

    func test_何も分からない店は5項目を決まった順で出す() {
        XCTAssertEqual(CafeDetailUnknowns.make(cafe: makeCafe()), allUnknown)
    }

    func test_店内の可否が分かれば店内の項目は出ない() {
        var cafe = makeCafe()
        cafe.dogAmenities = DogAmenities(indoor: false, terrace: nil, largeDogs: nil, dogMenu: nil)
        XCTAssertEqual(CafeDetailUnknowns.make(cafe: cafe), Array(allUnknown.dropFirst()))
    }

    func test_大型犬は可否かサイズ上限の明記があれば出ない() {
        var cafe = makeCafe()
        cafe.dogAmenities = DogAmenities(indoor: true, terrace: nil, largeDogs: false, dogMenu: true)
        XCTAssertFalse(CafeDetailUnknowns.make(cafe: cafe).contains("大型犬が入れるか"))

        // 自由記述のサイズ上限
        var limited = makeCafe()
        limited.dogAmenities = DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: true)
        limited.dogSizeLimit = "小型・中型犬のみ"
        XCTAssertFalse(CafeDetailUnknowns.make(cafe: limited).contains("大型犬が入れるか"))

        // 席ごとのサイズ上限
        var seat = makeCafe()
        seat.dogAmenities = DogAmenities(
            indoor: true, terrace: nil, largeDogs: nil, dogMenu: true, sizeMaxIndoor: .small, sizeMaxTerrace: nil, indoorStyle: nil
        )
        XCTAssertFalse(CafeDetailUnknowns.make(cafe: seat).contains("大型犬が入れるか"))

        // 空白だけのサイズ上限は明記と見なさない
        var blank = makeCafe()
        blank.dogAmenities = DogAmenities(indoor: true, terrace: nil, largeDogs: nil, dogMenu: true)
        blank.dogSizeLimit = "  "
        XCTAssertTrue(CafeDetailUnknowns.make(cafe: blank).contains("大型犬が入れるか"))
    }

    func test_予約はタイルと同じ条件で空のときだけ出る() {
        var cafe = makeCafe()
        cafe.reservation = "  "
        XCTAssertTrue(CafeDetailUnknowns.make(cafe: cafe).contains("予約が要るか"))
        XCTAssertNil(CafeDetailHighlights.reservationFirstLine("  "))
        cafe.reservation = "予約不可"
        XCTAssertFalse(CafeDetailUnknowns.make(cafe: cafe).contains("予約が要るか"))
        XCTAssertEqual(CafeDetailHighlights.reservation("予約不可").tone, .neutral)
        XCTAssertEqual(CafeDetailHighlights.reservation("  ").tone, .unknown)
    }

    func test_営業時間は構造化もhours_textもないときだけ出る() {
        var structured = makeCafe()
        structured.hours = OpeningHours(mon: [TimeRange(open: "09:00", close: "18:00")])
        XCTAssertFalse(CafeDetailUnknowns.make(cafe: structured).contains("営業時間"))

        var text = makeCafe()
        text.hoursText = "11:00〜20:00"
        XCTAssertFalse(CafeDetailUnknowns.make(cafe: text).contains("営業時間"))

        var blank = makeCafe()
        blank.hoursText = " "
        XCTAssertTrue(CafeDetailUnknowns.make(cafe: blank).contains("営業時間"))
    }

    func test_犬用メニューが分かれば出ない() {
        var cafe = makeCafe()
        cafe.dogAmenities = DogAmenities(indoor: nil, terrace: nil, largeDogs: nil, dogMenu: false)
        XCTAssertFalse(CafeDetailUnknowns.make(cafe: cafe).contains("犬用メニューがあるか"))
    }

    func test_すべて分かっている店は空() {
        var cafe = makeCafe()
        cafe.reservation = "予約可"
        cafe.hoursText = "11:00〜20:00"
        cafe.dogAmenities = DogAmenities(indoor: true, terrace: false, largeDogs: true, dogMenu: true)
        XCTAssertTrue(CafeDetailUnknowns.make(cafe: cafe).isEmpty)
    }

    func test_未確認と確認日なしの店は答えのカードが確認中なので出さない() {
        XCTAssertTrue(CafeDetailUnknowns.make(cafe: makeCafe(status: .unverified)).isEmpty)
        XCTAssertTrue(CafeDetailUnknowns.make(cafe: makeCafe(lastVerified: nil)).isEmpty)
    }

    func test_同伴不可の店と閉店の店は出さない() {
        XCTAssertTrue(CafeDetailUnknowns.make(cafe: makeCafe(status: .notAllowed)).isEmpty)
        var closed = makeCafe()
        closed.isClosed = true
        XCTAssertTrue(CafeDetailUnknowns.make(cafe: closed).isEmpty)
    }
}
