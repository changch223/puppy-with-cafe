import UIKit
import XCTest
@testable import DokoWanCafe

/// 写真のない店のタイル（地＝ピンの色×不透明度、文字＝`tileGlyphColor`）の文字が、ライト・ダークのどちらでも読めること。
final class CategoryTileColorTests: XCTestCase {
    private func rgb(_ color: UIColor, style: UIUserInterfaceStyle) -> (CGFloat, CGFloat, CGFloat) {
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(resolved.getRed(&r, green: &g, blue: &b, alpha: &a))
        return (r, g, b)
    }

    private func luminance(_ c: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
        let linear = [c.0, c.1, c.2].map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    /// 背景（不透明）の上に、色を不透明度つきで重ねた合成色
    private func composite(_ color: (CGFloat, CGFloat, CGFloat), opacity: Double, over background: (CGFloat, CGFloat, CGFloat)) -> (CGFloat, CGFloat, CGFloat) {
        let o = CGFloat(opacity)
        return (color.0 * o + background.0 * (1 - o), color.1 * o + background.1 * (1 - o), color.2 * o + background.2 * (1 - o))
    }

    private func ratio(_ a: (CGFloat, CGFloat, CGFloat), _ b: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// タイルが載る背景（一覧・カード・詳細・保存）
    private let backgrounds: [(String, UIColor)] = [
        ("systemBackground", .systemBackground),
        ("secondarySystemBackground", .secondarySystemBackground),
        ("systemGroupedBackground", .systemGroupedBackground),
        ("secondarySystemGroupedBackground", .secondarySystemGroupedBackground),
    ]

    func test_タイルの文字は地と3対1以上_ライトとダーク() {
        let categories: [MapPinCategory] = [.indoorOK, .terraceOnly, .checkDetail, .unverified]
        for style in [UIUserInterfaceStyle.light, .dark] {
            for category in categories {
                let fill = rgb(MapPinRenderer.fillColor(for: category), style: style)
                let glyph = rgb(MapPinRenderer.tileGlyphColor(for: category), style: style)
                let opacity = MapPinRenderer.tileBackgroundOpacity(for: category)
                for (name, background) in backgrounds {
                    let base = rgb(background, style: style)
                    let tile = composite(fill, opacity: opacity, over: base)
                    let value = ratio(glyph, tile)
                    XCTAssertGreaterThanOrEqual(value, 3, "\(category) \(style == .dark ? "dark" : "light") on \(name): \(value)")
                }
            }
        }
    }
}
