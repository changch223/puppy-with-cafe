import XCTest
@testable import DokoWanCafe

/// 一覧シートの見出し文言（純関数）のユニットテスト
final class SheetHeadlineTests: XCTestCase {
    func test_条件なしは犬OKのお店で2行目に現在地から近い順() {
        let text = SheetHeadline.make(
            count: 546, amenities: AmenityFilter(), openNowOnly: false,
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(text.title, "犬OKのお店 546件")
        XCTAssertEqual(text.subtitle, "現在地から近い順")
    }

    func test_営業中オンは今開いている() {
        let text = SheetHeadline.make(
            count: 18, amenities: AmenityFilter(), openNowOnly: true,
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(text.title, "今開いている犬OKのお店 18件")
    }

    func test_犬向け条件は見出しに入る() {
        let text = SheetHeadline.make(
            count: 12, amenities: AmenityFilter(indoorOnly: true, largeDogOnly: true), openNowOnly: false,
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(text.title, "店内OK・大型犬OKのお店 12件")
    }

    func test_営業中と犬向け条件の組み合わせ() {
        let text = SheetHeadline.make(
            count: 3, amenities: AmenityFilter(terraceOnly: true), openNowOnly: true,
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(text.title, "今開いている、テラスのお店 3件")
    }

    func test_検索した場所は起点名から近い順() {
        let text = SheetHeadline.make(
            count: 40, amenities: AmenityFilter(), openNowOnly: false,
            originName: "渋谷駅", isCurrentLocation: false
        )
        XCTAssertEqual(text.title, "犬OKのお店 40件")
        XCTAssertEqual(text.subtitle, "渋谷駅から近い順")
    }

    func test_確認日順のときは2行目が確認日が新しい順() {
        let text = SheetHeadline.make(
            count: 40, amenities: AmenityFilter(), openNowOnly: false, sortOrder: .recentlyVerified,
            originName: "渋谷駅", isCurrentLocation: false
        )
        XCTAssertEqual(text.subtitle, "確認日が新しい順")
    }

    func test_未確認を含むときは犬OKと言い切らず未確認を含むと添える() {
        let all = SheetHeadline.make(
            count: 600, amenities: AmenityFilter(), openNowOnly: false, includeUnverified: true,
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(all.title, "犬同伴のお店 600件（未確認を含む）")

        let open = SheetHeadline.make(
            count: 20, amenities: AmenityFilter(), openNowOnly: true, includeUnverified: true,
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(open.title, "今開いている犬同伴のお店 20件（未確認を含む）")

        let amenity = SheetHeadline.make(
            count: 5, amenities: AmenityFilter(indoorOnly: true), openNowOnly: false, includeUnverified: true,
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(amenity.title, "店内OKのお店 5件（未確認を含む）")
    }

    func test_0件でも見出しは件数を出す() {
        let text = SheetHeadline.make(
            count: 0, amenities: AmenityFilter(dogMenuOnly: true), openNowOnly: false,
            originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(text.title, "犬メニューのお店 0件")
    }

    func test_地図の中心を起点にすると2行目は地図の中心から近い順() {
        let text = SheetHeadline.make(
            count: 30, amenities: AmenityFilter(), openNowOnly: false,
            originName: SearchOrigin.mapCenter(latitude: 35.68, longitude: 139.76).displayName, isCurrentLocation: false
        )
        XCTAssertEqual(text.subtitle, "地図の中心から近い順")
    }


    // MARK: - 2行目は答え（近い順のとき）

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

    private func item(meters: Double, hours: OpeningHours?) -> CafeWithDistance {
        let cafe = Cafe(
            id: UUID(), placeID: nil, name: "店", latitude: 35.68, longitude: 139.76,
            address: nil, contact: nil,
            dogPolicyStatus: .allowed, dogPolicyCondition: nil,
            lastVerified: nil, representativeSourceID: nil,
            hasConflict: false, isClosed: false, area: "tokyo",
            phone: nil, hours: hours, dogAmenities: nil, dogSizeLimit: nil
        )
        return CafeWithDistance(cafe: cafe, distanceMeters: meters)
    }

    private var openAllDay: OpeningHours {
        OpeningHours(mon: [TimeRange(open: "09:00", close: "22:00")], tue: [], wed: nil, thu: nil, fri: nil, sat: nil, sun: nil)
    }

    private func answer(
        _ items: [CafeWithDistance], at date: Date? = nil, targetLabel: String? = nil,
        origin: String = "現在地", isCurrentLocation: Bool = true, sortOrder: CafeSortOrder = .distance
    ) -> String {
        SheetHeadline.make(
            count: items.count, amenities: AmenityFilter(), openNowOnly: false, targetLabel: targetLabel,
            sortOrder: sortOrder, originName: origin, isCurrentLocation: isCurrentLocation,
            items: items, referenceTime: date ?? monday(hour: 12)
        ).subtitle
    }

    func test_2行目は一番近い営業中の店までの徒歩() {
        // 1番目（200m）は営業時間が分からない・2番目（320m）は営業中 → 営業中と分かる店だけ数える
        let items = [item(meters: 200, hours: nil), item(meters: 320, hours: openAllDay), item(meters: 900, hours: openAllDay)]
        XCTAssertEqual(answer(items), "いちばん近い営業中の店は徒歩約4分")
    }

    func test_営業時間が分からない店は営業中に数えない() {
        let items = [item(meters: 200, hours: nil), item(meters: 300, hours: nil)]
        XCTAssertEqual(answer(items), "今、営業中と分かっているお店はありません")
    }

    func test_営業時間外の店だけなら営業中の店はなし() {
        let items = [item(meters: 200, hours: openAllDay)]
        XCTAssertEqual(answer(items, at: monday(hour: 23)), "今、営業中と分かっているお店はありません")
    }

    func test_遠いときは距離のまま() {
        let items = [item(meters: 3_200, hours: openAllDay)]
        XCTAssertEqual(answer(items), "いちばん近い営業中の店は3.2 km")
    }

    func test_起点が現在地でないときは先頭に起点名() {
        let items = [item(meters: 240, hours: openAllDay)]
        XCTAssertEqual(
            answer(items, origin: "渋谷駅", isCurrentLocation: false),
            "渋谷駅から・いちばん近い営業中の店は徒歩約3分"
        )
        XCTAssertEqual(
            answer([item(meters: 240, hours: nil)], origin: "渋谷駅", isCurrentLocation: false),
            "渋谷駅から・今、営業中と分かっているお店はありません"
        )
    }

    func test_いつ行くの指定中は営業中をその時間に営業していると言い換える() {
        let items = [item(meters: 240, hours: openAllDay)]
        XCTAssertEqual(answer(items, targetLabel: "月 12:00"), "その時間に営業している、いちばん近い店は徒歩約3分")
        XCTAssertEqual(
            answer([item(meters: 240, hours: nil)], targetLabel: "月 12:00"),
            "その時間に営業していると分かっているお店はありません"
        )
        // 対象時刻の営業で判定する（今は営業中でも、その時刻に時間外なら数えない）
        XCTAssertEqual(
            answer(items, at: monday(hour: 23), targetLabel: "月 23:00"),
            "その時間に営業していると分かっているお店はありません"
        )
    }

    func test_0件と確認日順は従来の2行目() {
        XCTAssertEqual(answer([]), "現在地から近い順")
        XCTAssertEqual(answer([], origin: "渋谷駅", isCurrentLocation: false), "渋谷駅から近い順")
        XCTAssertEqual(answer([item(meters: 200, hours: openAllDay)], sortOrder: .recentlyVerified), "確認日が新しい順")
    }

    func test_itemsを渡さなければ従来の2行目() {
        let text = SheetHeadline.make(
            count: 10, amenities: AmenityFilter(), openNowOnly: false, originName: "現在地", isCurrentLocation: true
        )
        XCTAssertEqual(text.subtitle, "現在地から近い順")
    }
}
