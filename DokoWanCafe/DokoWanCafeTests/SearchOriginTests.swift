import XCTest
@testable import DokoWanCafe

/// 住所・駅名検索機能: `SearchOrigin.searched` のユニットテスト（displayName / Equatable, FR-017）
final class SearchOriginTests: XCTestCase {
    func test_searchedのdisplayNameは検索結果名になる() {
        let origin = SearchOrigin.searched(name: "渋谷駅", latitude: 35.6580, longitude: 139.7016)
        XCTAssertEqual(origin.displayName, "渋谷駅")
    }

    func test_searchedは緯度経度と名前が同じなら等しい() {
        let a = SearchOrigin.searched(name: "渋谷駅", latitude: 35.6580, longitude: 139.7016)
        let b = SearchOrigin.searched(name: "渋谷駅", latitude: 35.6580, longitude: 139.7016)
        XCTAssertEqual(a, b)
    }

    func test_searchedは緯度経度か名前が異なれば等しくない() {
        let base = SearchOrigin.searched(name: "渋谷駅", latitude: 35.6580, longitude: 139.7016)
        let differentName = SearchOrigin.searched(name: "新宿駅", latitude: 35.6580, longitude: 139.7016)
        let differentCoordinate = SearchOrigin.searched(name: "渋谷駅", latitude: 35.0, longitude: 139.7016)
        XCTAssertNotEqual(base, differentName)
        XCTAssertNotEqual(base, differentCoordinate)
    }

    func test_searchedはcurrentLocationやmanualとは等しくない() {
        let searched = SearchOrigin.searched(name: "渋谷駅", latitude: 35.6580, longitude: 139.7016)
        let area = ManualArea(id: "shibuya", name: "渋谷", latitude: 35.6580, longitude: 139.7016)
        XCTAssertNotEqual(searched, .currentLocation)
        XCTAssertNotEqual(searched, .manual(area))
    }

    // MARK: - 地図の中心（このあたりで探す）と「◯◯の周り」

    func test_mapCenterのdisplayNameは地図の中心() {
        XCTAssertEqual(SearchOrigin.mapCenter(latitude: 35.68, longitude: 139.76).displayName, "地図の中心")
    }

    func test_mapCenterは緯度経度が同じなら等しく違えば等しくない() {
        let a = SearchOrigin.mapCenter(latitude: 35.68, longitude: 139.76)
        XCTAssertEqual(a, .mapCenter(latitude: 35.68, longitude: 139.76))
        XCTAssertNotEqual(a, .mapCenter(latitude: 35.69, longitude: 139.76))
        XCTAssertNotEqual(a, .currentLocation)
    }

    func test_aroundLabelは現在地ならnilでそれ以外は周りが付く() {
        let area = ManualArea(id: "shibuya", name: "渋谷", latitude: 35.6580, longitude: 139.7016)
        XCTAssertNil(SearchOrigin.currentLocation.aroundLabel)
        XCTAssertEqual(SearchOrigin.searched(name: "渋谷駅", latitude: 35.658, longitude: 139.7016).aroundLabel, "渋谷駅の周り")
        XCTAssertEqual(SearchOrigin.manual(area).aroundLabel, "渋谷の周り")
        XCTAssertEqual(SearchOrigin.mapCenter(latitude: 35.68, longitude: 139.76).aroundLabel, "地図の中心の周り")
    }
}
