import SwiftUI
import UIKit
import XCTest
@testable import DokoWanCafe

/// 詳細の固定バー（経路・電話・保存）が、幅の狭い端末でも画面幅に収まるかのレイアウトテスト。
/// 幅375pt・電話あり・「行った ✓ 12/28」で横の余白にはみ出していた（保存のラベルが縮まなかった）。
@MainActor
final class CafeDetailBottomBarLayoutTests: XCTestCase {
    private let visitedDate: Date = {
        var components = DateComponents()
        components.year = 2026; components.month = 12; components.day = 28; components.hour = 12
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    /// バーが要求する横幅（提案幅を超えて要求すればはみ出す）と、保存ラベルに選ばれた大きさ
    private func layout(
        proposed: CGFloat, hasPhone: Bool, status: SavedStatus?, size: DynamicTypeSize
    ) -> (width: CGFloat, variant: CafeDetailBottomBar.SaveLabelVariant?) {
        var variant: CafeDetailBottomBar.SaveLabelVariant?
        var bar = CafeDetailBottomBar(
            hasPhone: hasPhone,
            saved: SaveStateButton.make(status: status, visitedDate: status == .visited ? visitedDate : nil),
            onRoute: {}, onCall: {}, onSaveAction: { _ in }
        )
        bar.onSaveLabelVariant = { variant = $0 }
        let host = UIHostingController(rootView: bar.environment(\.dynamicTypeSize, size))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: proposed, height: 200))
        window.rootViewController = host
        window.makeKeyAndVisible()
        let width = host.sizeThatFits(in: CGSize(width: proposed, height: 200)).width
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        return (width, variant)
    }

    private func requiredWidth(
        proposed: CGFloat, hasPhone: Bool, status: SavedStatus?, size: DynamicTypeSize
    ) -> CGFloat {
        layout(proposed: proposed, hasPhone: hasPhone, status: status, size: size).width
    }

    func test_402ptの標準の文字で電話あり_行ったは日付つきの文言が選ばれる() {
        let result = layout(proposed: 402, hasPhone: true, status: .visited, size: .large)
        XCTAssertEqual(result.variant, .full, "経路の最小幅を残した上で、保存ラベルに先に幅を配る")
        XCTAssertLessThanOrEqual(result.width, 402)
    }

    func test_375ptの標準の文字で電話あり_行ったは日付を落として幅に収まる() {
        let result = layout(proposed: 375, hasPhone: true, status: .visited, size: .large)
        XCTAssertNotNil(result.variant)
        XCTAssertNotEqual(result.variant, .full)
        XCTAssertLessThanOrEqual(result.width, 375)
    }

    func test_375ptで電話あり_行った日付つきでも幅に収まる() {
        for size in [DynamicTypeSize.xSmall, .small, .medium, .large, .xLarge, .xxxLarge, .accessibility1, .accessibility5] {
            for status in [nil, SavedStatus.wantToGo, .visited] {
                let width = requiredWidth(proposed: 375, hasPhone: true, status: status, size: size)
                XCTAssertLessThanOrEqual(width, 375, "\(size) \(String(describing: status))")
            }
        }
    }

    func test_360ptでも幅に収まる() {
        for size in [DynamicTypeSize.large, .xxxLarge, .accessibility1] {
            let width = requiredWidth(proposed: 360, hasPhone: true, status: .visited, size: size)
            XCTAssertLessThanOrEqual(width, 360, "\(size)")
        }
    }
}
