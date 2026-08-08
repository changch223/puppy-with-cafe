import XCTest
@testable import DokoWanCafe

/// 下部引き出し一覧シート（S3）: 最近傍detent判定の純ロジックのユニットテスト（憲章 原則IV）
final class CafeSheetDetentTests: XCTestCase {
    // containerHeight=800 のとき: peek=150（固定）, medium=400, large=720
    private let containerHeight: CGFloat = 800

    func test_各段の高さはコンテナ高さから算出される() {
        XCTAssertEqual(CafeSheetDetent.peek.height(containerHeight: containerHeight), 150)
        XCTAssertEqual(CafeSheetDetent.medium.height(containerHeight: containerHeight), 400)
        XCTAssertEqual(CafeSheetDetent.large.height(containerHeight: containerHeight), 720)
    }

    func test_peekに近い高さはpeekへスナップする() {
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 100, containerHeight: containerHeight), .peek)
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 200, containerHeight: containerHeight), .peek)
    }

    func test_mediumに近い高さはmediumへスナップする() {
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 400, containerHeight: containerHeight), .medium)
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 500, containerHeight: containerHeight), .medium)
    }

    func test_largeに近い高さはlargeへスナップする() {
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 700, containerHeight: containerHeight), .large)
        // 上限を超えて指を離しても、最も近い段（large）へスナップする
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 900, containerHeight: containerHeight), .large)
    }

    func test_境界付近は近い方の段へ決定的にスナップする() {
        // peek(150)とmedium(400)の中間は275
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 250, containerHeight: containerHeight), .peek)
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 300, containerHeight: containerHeight), .medium)

        // medium(400)とlarge(720)の中間は560
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 550, containerHeight: containerHeight), .medium)
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 570, containerHeight: containerHeight), .large)
    }

    func test_下限を大きく下回ってもpeekへスナップする() {
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: -100, containerHeight: containerHeight), .peek)
    }
}
