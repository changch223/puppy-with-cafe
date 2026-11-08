import CoreLocation
import XCTest
@testable import DokoWanCafe

/// 「このあたりで探す」ボタンを出すかの判定（純ロジック）のユニットテスト
final class MapRecenterLogicTests: XCTestCase {
    /// 検索地点（東京駅あたり）
    private let search = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)

    /// 検索地点から真北へ約 `meters` メートルの地図の中心
    private func north(of coordinate: CLLocationCoordinate2D, meters: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude + meters / 111_320, longitude: coordinate.longitude)
    }

    private func offer(
        didUserMove: Bool = true,
        mapCenter: CLLocationCoordinate2D? = nil,
        width: Double = 1_600,
        searchCenter: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        hasSelectedCard: Bool = false,
        isSheetLarge: Bool = false
    ) -> Bool {
        MapRecenterLogic.shouldOffer(
            didUserMove: didUserMove,
            mapCenter: mapCenter ?? north(of: search, meters: 1_200),
            visibleWidthMeters: width,
            searchCenter: searchCenter,
            hasSelectedCard: hasSelectedCard,
            isSheetLarge: isSheetLarge
        )
    }

    func test_すべての条件を満たすと出す() {
        XCTAssertTrue(offer())
    }

    func test_ユーザーが動かしたのでなければ出さない() {
        XCTAssertFalse(offer(didUserMove: false))
    }

    func test_検索地点がまだなければ出さない() {
        XCTAssertFalse(offer(searchCenter: nil))
    }

    func test_中心が見えている幅の半分より近ければ出さない() {
        // 幅 1600m の半分は 800m。700m のずれでは出さない
        XCTAssertFalse(offer(mapCenter: north(of: search, meters: 700), width: 1_600))
    }

    func test_中心が見えている幅の半分以上離れたら出す() {
        XCTAssertTrue(offer(mapCenter: north(of: search, meters: 900), width: 1_600))
    }

    func test_幅が狭くても500m未満なら出さない() {
        // 幅 400m の半分は 200m だが、500m に満たないうちは出さない
        XCTAssertFalse(offer(mapCenter: north(of: search, meters: 400), width: 400))
    }

    func test_幅が狭いときは500m以上で出す() {
        XCTAssertTrue(offer(mapCenter: north(of: search, meters: 600), width: 400))
    }

    func test_距離がちょうど閾値なら出す() {
        // 幅 1000m → 閾値は max(500, 500) = 500m。ほぼ 500m（少し余裕を見て 505m）
        XCTAssertTrue(offer(mapCenter: north(of: search, meters: 505), width: 1_000))
        XCTAssertFalse(offer(mapCenter: north(of: search, meters: 495), width: 1_000))
    }

    func test_地図の中心が提供エリアの外なら出さない() {
        // 緯度 36.0 は東京の提供エリア（35.50〜35.90）の外
        let outside = CLLocationCoordinate2D(latitude: 36.0, longitude: 139.7671)
        XCTAssertNil(SupportedArea.area(containingLatitude: outside.latitude, longitude: outside.longitude))
        XCTAssertFalse(offer(mapCenter: outside))
    }

    func test_選択中の店のカードが出ているときは出さない() {
        XCTAssertFalse(offer(hasSelectedCard: true))
    }

    func test_一覧シートが最大まで開いているときは出さない() {
        XCTAssertFalse(offer(isSheetLarge: true))
    }

    func test_幅が不正なら出さない() {
        XCTAssertFalse(offer(width: 0))
        XCTAssertFalse(offer(width: .nan))
    }

    func test_中心の座標が不正なら出さない() {
        XCTAssertFalse(offer(mapCenter: CLLocationCoordinate2D(latitude: .nan, longitude: 139.7)))
    }

    func test_見えている幅は経度の広がりを緯度で補正して求める() {
        // 赤道では経度1度 ≒ 111.32km
        XCTAssertEqual(MapRecenterLogic.visibleWidthMeters(longitudeDelta: 1, latitude: 0), 111_320, accuracy: 1)
        // 緯度60度では cos60 = 0.5 倍
        XCTAssertEqual(MapRecenterLogic.visibleWidthMeters(longitudeDelta: 1, latitude: 60), 55_660, accuracy: 1)
    }
}
