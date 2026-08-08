import XCTest
@testable import DokoWanCafe

/// 下部引き出し一覧シート（S1）: 最近傍detent判定・トグルの純ロジックのユニットテスト（憲章 原則IV）
final class CafeSheetDetentTests: XCTestCase {
    // containerHeight=800 のとき: peek=150（固定）, expanded=680
    private let containerHeight: CGFloat = 800

    func test_各段の高さはコンテナ高さから算出される() {
        XCTAssertEqual(CafeSheetDetent.peek.height(containerHeight: containerHeight), 150)
        XCTAssertEqual(CafeSheetDetent.expanded.height(containerHeight: containerHeight), 680)
    }

    func test_peekに近い高さはpeekへスナップする() {
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 100, containerHeight: containerHeight), .peek)
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 200, containerHeight: containerHeight), .peek)
    }

    func test_expandedに近い高さはexpandedへスナップする() {
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 600, containerHeight: containerHeight), .expanded)
        // 上限を超えて指を離しても、最も近い段（expanded）へスナップする
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 900, containerHeight: containerHeight), .expanded)
    }

    func test_境界付近は近い方の段へ決定的にスナップする() {
        // peek(150)とexpanded(680)の中間は415
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 400, containerHeight: containerHeight), .peek)
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 430, containerHeight: containerHeight), .expanded)
    }

    func test_下限を大きく下回ってもpeekへスナップする() {
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: -100, containerHeight: containerHeight), .peek)
    }

    func test_toggledは2段を入れ替える() {
        XCTAssertEqual(CafeSheetDetent.peek.toggled(), .expanded)
        XCTAssertEqual(CafeSheetDetent.expanded.toggled(), .peek)
    }
}
