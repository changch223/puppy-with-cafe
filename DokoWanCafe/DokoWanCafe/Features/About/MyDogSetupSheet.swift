import SwiftUI

/// うちの子の設定シートの使いどころ
enum MyDogSetupMode: String, Identifiable {
    /// 初回の2問（データを表示できた後に一度だけ）。または未設定のまま「うちの子OK」を押したとき
    case onboarding
    /// 「うちの子」タブの「変更する」
    case edit

    var id: String { rawValue }
}

/// うちの子の設定シート（再設計 段階3）: 大きさ（1つ）と、お店での過ごし方（いくつでも）の2問。
/// 名前などの個人情報は聞かない。保存は端末内のみ（憲章 原則III）。大きさを選ぶまでは保存できない（既定値で決めつけない）。
struct MyDogSetupSheet: View {
    let mode: MyDogSetupMode
    let initial: DogProfile?
    /// シートが実際に表示されたとき
    var onAppear: () -> Void = {}
    let onSave: (DogProfile) -> Void
    /// 「あとで設定する」／「キャンセル」／下へスワイプして閉じる
    let onDismiss: () -> Void

    @State private var size: DogSize?
    @State private var styles: Set<DogStyle>

    init(
        mode: MyDogSetupMode,
        initial: DogProfile?,
        onAppear: @escaping () -> Void = {},
        onSave: @escaping (DogProfile) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.mode = mode
        self.initial = initial
        self.onAppear = onAppear
        self.onSave = onSave
        self.onDismiss = onDismiss
        _size = State(initialValue: initial?.size)
        _styles = State(initialValue: initial?.styles ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(mode == .onboarding ? "うちの子のことを教えてください" : "うちの子を変更")
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("入れるお店がひと目で分かるようになります。設定はこの端末の中だけに保存され、外へは送られません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("1. 大きさは？")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(DogSize.allCases) { option in
                        OptionRow(
                            title: option.displayName,
                            symbol: size == option ? "largecircle.fill.circle" : "circle",
                            isSelected: size == option
                        ) {
                            size = option
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("2. お店での過ごし方は？（いくつでも）")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(DogStyle.allCases) { option in
                        let isOn = styles.contains(option)
                        OptionRow(
                            title: option.displayName,
                            symbol: isOn ? "checkmark.square.fill" : "square",
                            isSelected: isOn
                        ) {
                            if isOn { styles.remove(option) } else { styles.insert(option) }
                        }
                    }
                }

                VStack(spacing: 8) {
                    Button {
                        if let size { onSave(DogProfile(size: size, styles: styles)) }
                    } label: {
                        Text(mode == .onboarding ? "はじめる" : "保存する")
                    }
                    .buttonStyle(BrandProminentButtonStyle())
                    .disabled(size == nil)
                    .opacity(size == nil ? 0.4 : 1)

                    if size == nil {
                        Text("大きさを選ぶと進めます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: onDismiss) {
                        Text(mode == .onboarding ? "あとで設定する" : "キャンセル")
                            .font(.subheadline.bold())
                            // ボタンの色味（tint）が薄く混ざって読みにくくならないよう、固定のラベル色にする
                            .foregroundStyle(Color(.secondaryLabel))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .presentationDragIndicator(.visible)
        .onAppear(perform: onAppear)
    }
}

/// 選択肢の1行（ラジオ／チェック共通）
private struct OptionRow: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.brand : Color(.tertiaryLabel))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.brand.opacity(0.12) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.brand : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
