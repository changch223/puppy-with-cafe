import CoreLocation
import XCTest
@testable import DokoWanCafe

/// 住所・駅名検索機能: `GeocodingService.PureLogic`（クエリ正規化・regionヒント生成）のユニットテスト。
/// `CLGeocoder` 自体のネットワーク呼び出しはXCTest対象外（純ロジックのみを検証, 憲章 原則IV）。
final class GeocodingServiceTests: XCTestCase {
    func test_前後の空白は取り除かれる() {
        XCTAssertEqual(GeocodingService.PureLogic.normalizedQuery("  渋谷駅  "), "渋谷駅")
    }

    func test_空文字や空白のみはnilになる() {
        XCTAssertNil(GeocodingService.PureLogic.normalizedQuery(""))
        XCTAssertNil(GeocodingService.PureLogic.normalizedQuery("   "))
        XCTAssertNil(GeocodingService.PureLogic.normalizedQuery("\n\t"))
    }

    func test_通常のクエリはそのまま返る() {
        XCTAssertEqual(GeocodingService.PureLogic.normalizedQuery("東京駅"), "東京駅")
    }

    func test_日本regionヒントは日本全土を包含する妥当な範囲になる() {
        let region = GeocodingService.PureLogic.japanRegionHint()
        XCTAssertEqual(region.identifier, "japan")
        XCTAssertGreaterThan(region.radius, 0)

        // 沖縄・北海道を含む、日本の主な地域が半径内に収まることを確認する
        let sapporo = CLLocation(latitude: 43.0621, longitude: 141.3544)
        let naha = CLLocation(latitude: 26.2124, longitude: 127.6809)
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        XCTAssertLessThan(sapporo.distance(from: center), region.radius)
        XCTAssertLessThan(naha.distance(from: center), region.radius)
    }
}
