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
}
