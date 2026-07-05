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

/// 営業状態バッジ（FR-102）。構造化営業時間のある店のみ表示（unknown は何も出さない）。
struct OpenStateBadge: View {
    let state: OpenState

    var body: some View {
        if let text = state.displayText {
            HStack(spacing: 4) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("営業状態: \(text)"))
        }
    }

    private var dotColor: Color {
        switch state {
        case .open: return .green
        case .outsideHours: return .gray
        case .closedToday: return .orange
        case .unknown: return .clear
        }
    }
}

/// 犬向け設備の1項目（✓/✕/不明の三値, FR-104: 不明を✕と混同しない）
struct AmenityBadge: View {
    let label: String
    let value: Bool?

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.10)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(label): \(valueText)"))
    }

    private var symbol: String {
        switch value {
        case true: return "checkmark.circle.fill"
        case false: return "xmark.circle"
        default: return "questionmark.circle"
        }
    }

    private var color: Color {
        switch value {
        case true: return .green
        case false: return .red
        default: return .gray
        }
    }

    private var valueText: String {
        switch value {
        case true: return String(localized: "はい")
        case false: return String(localized: "いいえ")
        default: return String(localized: "不明")
        }
    }
}
