import XCTest
@testable import DokoWanCafe

/// T017: 距離計算のユニットテスト（憲章 原則IV）
final class DistanceCalculatorTests: XCTestCase {
    func test_同一地点の距離は0() {
        let distance = DistanceCalculator.distanceMeters(
            fromLatitude: 35.6812, fromLongitude: 139.7671,
            toLatitude: 35.6812, toLongitude: 139.7671
        )
        XCTAssertEqual(distance, 0, accuracy: 0.001)
    }

    func test_東京駅から渋谷駅はおよそ6_4km() {
        // 東京駅 (35.6812, 139.7671) → 渋谷駅 (35.6580, 139.7016)
        let distance = DistanceCalculator.distanceMeters(
            fromLatitude: 35.6812, fromLongitude: 139.7671,
            toLatitude: 35.6580, toLongitude: 139.7016
        )
        // 実距離 約6.4km。ハバースイン概算として ±5% を許容
        XCTAssertEqual(distance, 6_400, accuracy: 6_400 * 0.05)
    }

    func test_距離は対称() {
        let forward = DistanceCalculator.distanceMeters(
            fromLatitude: 35.6812, fromLongitude: 139.7671,
            toLatitude: 35.7295, toLongitude: 139.7109
        )
        let backward = DistanceCalculator.distanceMeters(
            fromLatitude: 35.7295, fromLongitude: 139.7109,
            toLatitude: 35.6812, toLongitude: 139.7671
        )
        XCTAssertEqual(forward, backward, accuracy: 0.001)
    }

    func test_近距離の精度_約100m() {
        // 緯度 0.0009度 ≒ 100m
        let distance = DistanceCalculator.distanceMeters(
            fromLatitude: 35.6800, fromLongitude: 139.7700,
            toLatitude: 35.6809, toLongitude: 139.7700
        )
        XCTAssertEqual(distance, 100, accuracy: 2)
    }
}
