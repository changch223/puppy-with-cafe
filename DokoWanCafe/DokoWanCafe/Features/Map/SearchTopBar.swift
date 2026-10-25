import SwiftUI

/// 地図の上の検索バー。タップで検索画面を開く。右端の犬のボタンは「うちの子」タブへ切り替える。
struct HomeSearchBar: View {
    let onTapSearch: () -> Void
    let onTapMyDog: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onTapSearch) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text("店名・駅・エリアで検索")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 14)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("店名・駅・エリアで検索"))
            .accessibilityHint(Text("検索画面を開きます"))

            Button(action: onTapMyDog) {
                Image(systemName: "dog.fill")
                    .font(.body)
                    .foregroundStyle(Color.brand)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("うちの子"))
        }
        .padding(.trailing, 4)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }
}

/// 条件チップ（横スクロール）: 営業中・店内OK・テラス・大型犬OK・犬メニュー。オンはブランド色で塗る。
/// 1つ以上オンなら末尾に「クリア」。
struct FilterChipsView: View {
    @Binding var openNowOnly: Bool
    @Binding var amenityFilter: AmenityFilter
    let hasActiveChips: Bool
    let onClear: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: String(localized: "営業中"), systemImage: "clock", isOn: $openNowOnly)
                FilterChip(title: String(localized: "店内OK"), isOn: $amenityFilter.indoorOnly)
                FilterChip(title: String(localized: "テラス"), isOn: $amenityFilter.terraceOnly)
                FilterChip(title: String(localized: "大型犬OK"), isOn: $amenityFilter.largeDogOnly)
                FilterChip(title: String(localized: "犬メニュー"), isOn: $amenityFilter.dogMenuOnly)
                if hasActiveChips {
                    Button(action: onClear) {
                        Text("クリア")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                    }
                    .accessibilityLabel(Text("条件をクリア"))
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct FilterChip: View {
    let title: String
    var systemImage: String?
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.bold())
                }
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? Color.onBrand : Color.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background {
                if isOn {
                    Capsule().fill(Color.brand)
                } else {
                    Capsule().fill(.regularMaterial)
                }
            }
            .shadow(color: .black.opacity(isOn ? 0 : 0.12), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isOn ? "オン" : "オフ"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// 画面上部の通知バナー（サンプルモード・オフライン等の明示に使用）。地図の上に小さく出す。
struct NoticeBanner: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption)
        .foregroundStyle(tint == .gray ? Color.primary : tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
