import XCTest
@testable import DokoWanCafe

/// T061: 提供エリア判定のユニットテスト（FR-022, 憲章 原則IV）
final class SupportedAreaTests: XCTestCase {
    func test_東京駅は対象エリア内() {
        XCTAssertNotNil(SupportedArea.area(containingLatitude: 35.6812, longitude: 139.7671))
    }

    func test_立川も対象エリア内() {
        XCTAssertNotNil(SupportedArea.area(containingLatitude: 35.6977, longitude: 139.4137))
    }

    func test_横浜は対象エリア外() {
        // 横浜駅 (35.4437, 139.6380) — 東京の南限より南
        XCTAssertNil(SupportedArea.area(containingLatitude: 35.4437, longitude: 139.6380))
    }

    func test_大阪は対象エリア外() {
        XCTAssertNil(SupportedArea.area(containingLatitude: 34.7025, longitude: 135.4959))
    }

    func test_境界値は含む() {
        let tokyo = SupportedArea.tokyo
        XCTAssertTrue(tokyo.contains(latitude: tokyo.minLatitude, longitude: tokyo.minLongitude))
        XCTAssertTrue(tokyo.contains(latitude: tokyo.maxLatitude, longitude: tokyo.maxLongitude))
    }

    func test_境界外は含まない() {
        let tokyo = SupportedArea.tokyo
        XCTAssertFalse(tokyo.contains(latitude: tokyo.maxLatitude + 0.001, longitude: 139.7))
        XCTAssertFalse(tokyo.contains(latitude: 35.7, longitude: tokyo.minLongitude - 0.001))
    }
}
