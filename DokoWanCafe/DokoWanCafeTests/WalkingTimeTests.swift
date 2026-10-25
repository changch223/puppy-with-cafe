import XCTest
@testable import DokoWanCafe

/// 徒歩の目安（分速80m・切り上げ・2km超は距離のみ）のユニットテスト（憲章 原則IV）
final class WalkingTimeTests: XCTestCase {
    func test_分速80mで切り上げる() {
        XCTAssertEqual(WalkingTime.minutes(meters: 80), 1)
        XCTAssertEqual(WalkingTime.minutes(meters: 81), 2)
        XCTAssertEqual(WalkingTime.minutes(meters: 560), 7)
        XCTAssertEqual(WalkingTime.minutes(meters: 561), 8)
    }

    func test_ごく近い店でも最低1分() {
        XCTAssertEqual(WalkingTime.minutes(meters: 0), 1)
        XCTAssertEqual(WalkingTime.minutes(meters: 5), 1)
        XCTAssertEqual(WalkingTime.minutes(meters: -10), 1)
    }

    func test_2kmちょうどまでは徒歩の目安を出す() {
        XCTAssertTrue(WalkingTime.isWalkable(meters: 2_000))
        XCTAssertEqual(WalkingTime.summary(meters: 2_000).headline, "徒歩約25分")
    }

    func test_2kmを超えたら徒歩は出さず距離のkmだけ() {
        XCTAssertFalse(WalkingTime.isWalkable(meters: 2_001))
        let summary = WalkingTime.summary(meters: 3_200)
        XCTAssertEqual(summary.headline, "3.2 km")
        XCTAssertNil(summary.detail)
    }

    func test_徒歩圏は徒歩の分数と小さな距離を返す() {
        let summary = WalkingTime.summary(meters: 520)
        XCTAssertEqual(summary.headline, "徒歩約7分")
        XCTAssertEqual(summary.detail, "520 m")
        XCTAssertEqual(summary.spoken, "徒歩約7分")
    }

    func test_距離の表記() {
        XCTAssertEqual(WalkingTime.distanceText(meters: 4), "10 m")
        XCTAssertEqual(WalkingTime.distanceText(meters: 324), "320 m")
        XCTAssertEqual(WalkingTime.distanceText(meters: 994), "990 m")
        XCTAssertEqual(WalkingTime.distanceText(meters: 996), "1.0 km")
        XCTAssertEqual(WalkingTime.distanceText(meters: 1_000), "1.0 km")
        XCTAssertEqual(WalkingTime.distanceText(meters: 12_340), "12.3 km")
    }
}
