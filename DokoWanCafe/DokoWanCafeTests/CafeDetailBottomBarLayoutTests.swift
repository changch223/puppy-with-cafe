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

    /// バーが要求する横幅（提案幅を超えて要求すればはみ出す）
    private func requiredWidth(
        proposed: CGFloat, hasPhone: Bool, status: SavedStatus?, size: DynamicTypeSize
    ) -> CGFloat {
        let bar = CafeDetailBottomBar(
            hasPhone: hasPhone,
            saved: SaveStateButton.make(status: status, visitedDate: status == .visited ? visitedDate : nil),
            onRoute: {}, onCall: {}, onSaveAction: { _ in }
        )
        .environment(\.dynamicTypeSize, size)
        let host = UIHostingController(rootView: bar)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: proposed, height: 200))
        window.rootViewController = host
        window.makeKeyAndVisible()
        return host.sizeThatFits(in: CGSize(width: proposed, height: 200)).width
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
