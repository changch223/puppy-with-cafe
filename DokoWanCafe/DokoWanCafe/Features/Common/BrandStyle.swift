import SwiftUI
import UIKit

extension UIColor {
    /// ブランド色「芝生の緑」#23735A（ダーク時 #5CC198）。チップ・主ボタン・営業中の表示に使う（定義はここ1か所）。
    static let brand = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x5C / 255, green: 0xC1 / 255, blue: 0x98 / 255, alpha: 1)
            : UIColor(red: 0x23 / 255, green: 0x73 / 255, blue: 0x5A / 255, alpha: 1)
    }
}

extension Color {
    static let brand = Color(UIColor.brand)

    /// ブランド色の上に載せる文字色（ライト時は白、ダーク時は明るい緑の上なので濃い色）
    static let onBrand = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.04, green: 0.16, blue: 0.12, alpha: 1) : .white
    })
}

extension MapPinCategory {
    /// タグ・凡例に使う色（ピンの色と揃える）
    var tint: Color {
        switch self {
        case .indoorOK: return Color.brand
        case .terraceOnly: return Color(UIColor.systemTeal)
        case .checkDetail: return Color(UIColor.systemOrange)
        case .unverified: return Color(UIColor.systemGray)
        }
    }
}

/// 主ボタン（経路など）: ブランド色の塗り
struct BrandProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(Color.onBrand)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.brand.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

/// 副ボタン（電話・保存）: 薄い塗り＋ブランド色の文字
struct BrandSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(Color.brand)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.brand.opacity(configuration.isPressed ? 0.2 : 0.12), in: Capsule())
    }
}
