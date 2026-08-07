import CoreLocation
import MapKit
import UIKit
import XCTest
@testable import DokoWanCafe

/// 地図の初期カメラ半径算出ロジックのユニットテスト（憲章 原則IV）。
/// データ層は全カフェを絞り込みなしで保持するため、地図の「近さ感」は
/// 初期カメラの表示範囲（span）だけで演出する。疎な地域での空白地図を防ぎつつ、
/// 密な地域では現在地起点の近距離感を保つことを検証する。
final class MapViewModelTests: XCTestCase {
    private func makeItem(distanceMeters: Double) -> CafeWithDistance {
        CafeWithDistance(
            cafe: Cafe(
                id: UUID(), placeID: nil, name: "テスト",
                latitude: 35.68, longitude: 139.76,
                address: nil, contact: nil,
                dogPolicyStatus: .allowed, dogPolicyCondition: nil,
                lastVerified: nil, representativeSourceID: nil,
                hasConflict: false, isClosed: false, area: "tokyo"
            ),
            distanceMeters: distanceMeters
        )
    }

    func test_十分な件数が近くにあれば下限付近に収まる() {
        // 東京駅級の密集地点を想定: 5件目までがごく近い
        let items = [100.0, 300.0, 500.0, 800.0, 1_200.0].map(makeItem(distanceMeters:))
        let span = MapViewModel.initialCameraSpanMeters(items: items)
        XCTAssertEqual(span, MapViewModel.minInitialCameraMeters, accuracy: 0.1)
    }

    func test_疎な地点では上限でクランプされる() {
        // 八王子・葛飾級の疎な地点を想定: 最寄りでも数十km離れている
        let items = [40_000.0, 45_000.0, 50_000.0].map(makeItem(distanceMeters:))
        let span = MapViewModel.initialCameraSpanMeters(items: items)
        XCTAssertEqual(span, MapViewModel.maxInitialCameraMeters, accuracy: 0.1)
    }

    func test_5件未満でも最遠件までの距離を基準にする() {
        let items = [500.0, 1_000.0].map(makeItem(distanceMeters:))
        let span = MapViewModel.initialCameraSpanMeters(items: items)
        // 最遠(1,000m) * 1.3 = 1,300m だが下限3,000mでクランプされる
        XCTAssertEqual(span, MapViewModel.minInitialCameraMeters, accuracy: 0.1)
    }

    func test_中間的な距離では比例して広がる() {
        // 5件目までの距離が 10,000m のケース: 10,000 * 1.3 = 13,000m（下限・上限の中間）
        let items = Array(repeating: 10_000.0, count: 5).map(makeItem(distanceMeters:))
        let span = MapViewModel.initialCameraSpanMeters(items: items)
        XCTAssertEqual(span, 13_000, accuracy: 0.1)
    }

    func test_カフェが1件もなければフォールバックで下限を返す() {
        let span = MapViewModel.initialCameraSpanMeters(items: [])
        XCTAssertEqual(span, MapViewModel.minInitialCameraMeters, accuracy: 0.1)
    }

    func test_initialCameraRegionは中心座標を保持する() {
        let center = CLLocationCoordinate2D(latitude: 35.6896, longitude: 139.7006)
        let region = MapViewModel.initialCameraRegion(center: center, items: [])
        XCTAssertEqual(region.center.latitude, center.latitude, accuracy: 0.0001)
        XCTAssertEqual(region.center.longitude, center.longitude, accuracy: 0.0001)
    }

    // MARK: - displayPriority（数字クラスタ廃止の代替, UI/UXブラッシュアップ設計書2）

    func test_近い順位はrequired中間はdefaultHigh遠い順位はdefaultLow() {
        XCTAssertEqual(MapViewModel.displayPriority(rank: 0), .required)
        XCTAssertEqual(MapViewModel.displayPriority(rank: MapViewModel.requiredPinRank - 1), .required)
        XCTAssertEqual(MapViewModel.displayPriority(rank: MapViewModel.requiredPinRank), .defaultHigh)
        XCTAssertEqual(MapViewModel.displayPriority(rank: MapViewModel.highPriorityPinRank - 1), .defaultHigh)
        XCTAssertEqual(MapViewModel.displayPriority(rank: MapViewModel.highPriorityPinRank), .defaultLow)
    }

    func test_displayPrioritiesは距離昇順のランクで割り当てる() {
        // 距離順ではなく元の並びを崩した入力でも、距離順にランク付けされることを確認
        let far = makeItem(distanceMeters: 9_000)
        let near = makeItem(distanceMeters: 100)
        let priorities = MapViewModel.displayPriorities(for: [far, near])
        XCTAssertEqual(priorities[near.cafe.id], .required)
        XCTAssertEqual(priorities[far.cafe.id], .required) // 2件のみなら両方 requiredPinRank 未満
    }

    // MARK: - markerTintColor（旧 markerTintColor(for: DogPolicyStatus) を置換, 設計書1a/2）

    func test_MapPinCategoryごとのマーカー色() {
        // UIColor は Equatable ではないため isEqual(_:) で比較する
        XCTAssertTrue(MapViewModel.markerTintColor(for: .indoorOK).isEqual(UIColor.systemGreen))
        XCTAssertTrue(MapViewModel.markerTintColor(for: .terraceOnly).isEqual(UIColor.systemTeal))
        XCTAssertTrue(MapViewModel.markerTintColor(for: .checkDetail).isEqual(UIColor.systemOrange))
        XCTAssertTrue(MapViewModel.markerTintColor(for: .unverified).isEqual(UIColor.systemGray))
    }

    // MARK: - signature（お気に入り・分類の変化を再描画のトリガーに含める, 設計書2）

    func test_signatureはお気に入りの変化で異なる値になる() {
        let item = makeItem(distanceMeters: 100)
        let withoutFavorite = MapViewModel.signature(of: [item], favoriteIDs: [])
        let withFavorite = MapViewModel.signature(of: [item], favoriteIDs: [item.cafe.id])
        XCTAssertNotEqual(withoutFavorite, withFavorite)
    }
}
