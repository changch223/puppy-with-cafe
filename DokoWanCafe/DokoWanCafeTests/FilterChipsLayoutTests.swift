import SwiftUI
import XCTest
@testable import DokoWanCafe

/// 地図の上の条件チップ（4つ）が、幅375ptの機種でも横スクロールなしの1行に収まること。
@MainActor
final class FilterChipsLayoutTests: XCTestCase {
    private func width(compact: Bool, targetLabel: String?, hasActive: Bool, count: Int) -> CGFloat {
        let row = FilterChipsRow(
            compact: compact, targetLabel: targetLabel,
            openNowOnly: .constant(targetLabel != nil), myDogOnly: .constant(false), hasMyDog: true,
            hasActiveChips: hasActive, activeFilterCount: count,
            onTapFilter: {}, onTapPlan: {}, onNeedMyDog: {}, onClear: {}
        )
        let host = UIHostingController(rootView: row)
        return host.sizeThatFits(in: CGSize(width: 10_000, height: 100)).width
    }

    func test_幅375ptでも4つのチップが1行に収まる() {
        // 何も選んでいない・バッジあり＋クリアあり（時刻なし）の、いちばん広くなる組み合わせ
        let usual = width(compact: true, targetLabel: nil, hasActive: false, count: 0)
        let active = width(compact: true, targetLabel: nil, hasActive: true, count: 9)
        print("CHIPS compact usual=\(usual) active=\(active)")
        XCTAssertLessThanOrEqual(usual, 375)
        XCTAssertLessThanOrEqual(active, 375)
    }
}
