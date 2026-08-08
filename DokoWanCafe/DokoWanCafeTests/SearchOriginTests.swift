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
}
