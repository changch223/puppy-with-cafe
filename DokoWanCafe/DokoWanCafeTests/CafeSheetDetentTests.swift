import XCTest
@testable import DokoWanCafe

/// 下部引き出し一覧シート: 3段（見出しだけ／半分／ほぼ全画面）の高さ・最近傍判定・切り替えの純ロジックのユニットテスト（憲章 原則IV）
final class CafeSheetDetentTests: XCTestCase {
    // containerHeight=800・上部（検索バー＋チップ）に120を残すとき: peek=96（固定）, medium=360（45%）, large=680
    private let containerHeight: CGFloat = 800
    private let topReserved: CGFloat = 120

    func test_各段の高さはコンテナ高さから算出される() {
        XCTAssertEqual(CafeSheetDetent.peek.height(containerHeight: containerHeight, topReserved: topReserved), 96)
        XCTAssertEqual(CafeSheetDetent.medium.height(containerHeight: containerHeight, topReserved: topReserved), 360)
        XCTAssertEqual(CafeSheetDetent.large.height(containerHeight: containerHeight, topReserved: topReserved), 680)
    }

    func test_ほぼ全画面は上部の検索バーとチップの下まで() {
        XCTAssertEqual(CafeSheetDetent.large.height(containerHeight: 800, topReserved: 200), 600)
    }

    func test_上部が大きすぎてもほぼ全画面は半分より低くならない() {
        XCTAssertEqual(CafeSheetDetent.large.height(containerHeight: 400, topReserved: 390), 180)
    }

    func test_peekに近い高さはpeekへスナップする() {
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 50, containerHeight: containerHeight, topReserved: topReserved), .peek)
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 200, containerHeight: containerHeight, topReserved: topReserved), .peek)
    }

    func test_mediumに近い高さはmediumへスナップする() {
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 300, containerHeight: containerHeight, topReserved: topReserved), .medium)
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 450, containerHeight: containerHeight, topReserved: topReserved), .medium)
    }

    func test_largeに近い高さはlargeへスナップする() {
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 600, containerHeight: containerHeight, topReserved: topReserved), .large)
        // 上限を超えて指を離しても、最も近い段（large）へスナップする
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 900, containerHeight: containerHeight, topReserved: topReserved), .large)
    }

    func test_境界付近は近い方の段へ決定的にスナップする() {
        // peek(96)とmedium(360)の中間は228、mediumとlarge(680)の中間は520
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 220, containerHeight: containerHeight, topReserved: topReserved), .peek)
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 236, containerHeight: containerHeight, topReserved: topReserved), .medium)
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 510, containerHeight: containerHeight, topReserved: topReserved), .medium)
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: 530, containerHeight: containerHeight, topReserved: topReserved), .large)
    }

    func test_下限を大きく下回ってもpeekへスナップする() {
        XCTAssertEqual(CafeSheetDetent.nearest(toHeight: -100, containerHeight: containerHeight, topReserved: topReserved), .peek)
    }

    func test_見出しだけの段は見出しの高さに合わせて伸びるが基本の高さより小さくならない() {
        // 通常の文字サイズ: 見出しブロック60 + 覗き分24 = 84 → 基本の96のまま
        XCTAssertEqual(CafeSheetDetent.peekHeight(headerBlockHeight: 60), 96)
        // アクセシビリティサイズ: 見出しブロック180 → 180 + 24
        XCTAssertEqual(CafeSheetDetent.peekHeight(headerBlockHeight: 180), 204)
        // 伸びた高さが peek の高さとして使われる
        XCTAssertEqual(
            CafeSheetDetent.peek.height(containerHeight: containerHeight, topReserved: topReserved, peekHeight: 204),
            204
        )
    }

    func test_見出しだけの段は半分より高くならない() {
        XCTAssertEqual(
            CafeSheetDetent.peek.height(containerHeight: 400, topReserved: 100, peekHeight: 500),
            180
        )
    }

    func test_伸びたpeekでも最寄り段を判定できる() {
        XCTAssertEqual(
            CafeSheetDetent.nearest(toHeight: 230, containerHeight: containerHeight, topReserved: topReserved, peekHeight: 204),
            .peek
        )
        XCTAssertEqual(
            CafeSheetDetent.nearest(toHeight: 330, containerHeight: containerHeight, topReserved: topReserved, peekHeight: 204),
            .medium
        )
    }

    func test_VoiceOverで読む段の名前() {
        XCTAssertEqual(CafeSheetDetent.peek.accessibilityName, "見出しだけ")
        XCTAssertEqual(CafeSheetDetent.medium.accessibilityName, "半分")
        XCTAssertEqual(CafeSheetDetent.large.accessibilityName, "ほぼ全画面")
    }

    func test_toggledは見出しだけ_半分_ほぼ全画面の順に進み一周する() {
        XCTAssertEqual(CafeSheetDetent.peek.toggled(), .medium)
        XCTAssertEqual(CafeSheetDetent.medium.toggled(), .large)
        XCTAssertEqual(CafeSheetDetent.large.toggled(), .peek)
    }

    func test_カードの高さは半分より少し低い固定の高さで小さな画面では上限がある() {
        // 800 の 40% = 320（medium の 360 より低い）
        XCTAssertEqual(CafeSheetDetent.cardHeight(containerHeight: 800), 320)
        // 600 の 40% = 240 だが下限 300
        XCTAssertEqual(CafeSheetDetent.cardHeight(containerHeight: 600), 300)
        // 300 のとき下限 300 でも画面の 80% = 240 に抑える
        XCTAssertEqual(CafeSheetDetent.cardHeight(containerHeight: 300), 240)
    }
}
