import SwiftUI

/// 犬同伴可否ステータスのバッジ（一覧・地図・詳細で共通の色対応, FR-006）
struct StatusBadge: View {
    let status: DogPolicyStatus
    var prominent = false

    var body: some View {
        Text(status.displayName)
            .font(prominent ? .subheadline.bold() : .caption.bold())
            .padding(.horizontal, prominent ? 10 : 8)
            .padding(.vertical, prominent ? 4 : 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
            .accessibilityLabel(Text("犬同伴: \(status.displayName)"))
    }

    private var color: Color {
        switch status {
        case .allowed: return .green
        case .conditional: return .orange
        case .notAllowed: return .red
        case .unverified: return .gray
        }
    }
}
