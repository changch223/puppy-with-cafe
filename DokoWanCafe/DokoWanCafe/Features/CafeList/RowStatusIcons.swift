import SwiftUI

// 一覧の行・ピンのカードに添える小さな状態アイコン（鮮度警告・行きたい・行った）

/// 鮮度警告アイコン（未確認 or 最終確認から1年超, 一覧行の犬目線化で使用, UI/UXブラッシュアップ設計書4）
struct FreshnessWarningIcon: View {
    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.caption2)
            .foregroundStyle(.orange)
            .accessibilityLabel(Text("情報が古い可能性があります"))
    }
}

/// 「行きたい」を示す小さな肉球アイコン（一覧行で使用, UI/UXブラッシュアップ設計書4）
struct FavoritePawIcon: View {
    var body: some View {
        Image(systemName: "pawprint.fill")
            .font(.caption2)
            .foregroundStyle(.pink)
            .accessibilityLabel(Text("行きたい"))
    }
}

/// 「行った」を示す小さなチェックアイコン（一覧行で使用）
struct VisitedCheckIcon: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.caption2)
            .foregroundStyle(Color.brand)
            .accessibilityLabel(Text("行った"))
    }
}
