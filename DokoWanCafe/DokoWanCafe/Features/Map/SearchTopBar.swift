import SwiftUI

/// 地図の上の検索バー。タップで検索画面を開く。右端の犬のボタンは「うちの子」タブへ切り替える。
/// うちの子が設定済みなら、犬のボタンに大きさの頭文字（小・中・大）の小さな印を出す。
/// 起点が現在地以外のとき（`originLabel` あり）は、虫めがねの代わりに場所のピンと「◯◯の周り」を出し、
/// 右に✕（現在地に戻る）を置く。今どこを見ているかが分かるように。
struct HomeSearchBar: View {
    /// うちの子の設定（未設定は nil）
    var dog: DogProfile?
    /// 起点が現在地以外のときの「◯◯の周り」（現在地は nil）
    var originLabel: String?
    let onTapSearch: () -> Void
    /// ✕（現在地に戻る）。`originLabel` があるときだけ出る
    var onClearOrigin: () -> Void = {}
    let onTapMyDog: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onTapSearch) {
                HStack(spacing: 8) {
                    if let originLabel {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Color.brand)
                        // 長い名前は末尾を省略して1行にとどめる
                        Text(originLabel)
                            .font(.body.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        // 検索バーは地図の上に常に出る固定の帯。最大の文字では帯が画面を占めてしまうので、
                        // 1行で全文が読める大きさ（xxxLarge）までにとどめる（一覧・詳細などは最大まで拡大する）
                        Text("店名・駅・エリアで検索")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 14)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(originLabel.map { Text("検索。今は\($0)") } ?? Text("店名・駅・エリアで検索"))
            .accessibilityHint(Text("検索画面を開きます"))

            if originLabel != nil {
                Button(action: onClearOrigin) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("現在地に戻る"))
            }

            Button(action: onTapMyDog) {
                Image(systemName: "dog.fill")
                    .font(.body)
                    .foregroundStyle(Color.brand)
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .topTrailing) {
                        if let dog {
                            Text(dog.size.initial)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.onBrand)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Color.brand))
                                .offset(x: -2, y: 4)
                                .accessibilityHidden(true)
                        }
                    }
            }
            .accessibilityLabel(Text(dog.map { String(localized: "うちの子（\($0.size.displayName)）") } ?? String(localized: "うちの子")))
        }
        .padding(.trailing, 4)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }
}

/// 地図を動かしたあとに出る「このあたりで探す」ボタン（カプセル）。押したときだけ地図の中心を検索の起点にする。
struct SearchHereButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.bold())
                Text("このあたりで探す")
                    .font(.subheadline.bold())
                    .lineLimit(1)
            }
            .foregroundStyle(Color.brand)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityHint(Text("地図の中心の周りのお店を近い順に並べます"))
    }
}

/// 探し直している間（前の結果を残している間）に検索バーの下へ出す「探しています…」の小さなカプセル。
struct SearchingIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("探しています…")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 36)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .combine)
    }
}

/// 条件チップ（4つだけ）: 絞り込み・いつ行く？・うちの子OK・営業中。オンはブランド色で塗る。
/// 「絞り込み」はシートを開き、シートの中で効いている条件（店内OK・テラス・大型犬OK・犬メニューなど）の数をバッジで出す（1つ以上オンなら塗る）。
/// 1つ以上オンなら末尾に「クリア」。
/// 「いつ行く？」は対象時刻を決めると「土 12:00」の表示に変わり、「営業中」は「その時間に営業」に変わる。
/// 並べ方: 広い画面は絵柄つき、幅375ptの機種などは絵柄と余白を詰めて横スクロールなしの1行に収める。
/// 文字を大きくして詰めても入らないときだけ、横スクロールにする。
struct FilterChipsView: View {
    /// 対象時刻の短い表記（例: 「土 12:00」）。nil は「今」
    let targetLabel: String?
    @Binding var openNowOnly: Bool
    /// 「うちの子OK」チップ（入れると明記された店だけ）
    @Binding var myDogOnly: Bool
    /// うちの子が設定済みか。未設定でチップを押したときは、オンにせず設定（初回の2問）を開く
    let hasMyDog: Bool
    let hasActiveChips: Bool
    /// 「絞り込み」のバッジに出す、オンの条件の数（「いつ行く？」は数えない）
    let activeFilterCount: Int
    let onTapFilter: () -> Void
    let onTapPlan: () -> Void
    let onNeedMyDog: () -> Void
    let onClear: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(compact: false)
            row(compact: true)
            ScrollView(.horizontal, showsIndicators: false) {
                row(compact: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(compact: Bool) -> FilterChipsRow {
        FilterChipsRow(
            compact: compact,
            targetLabel: targetLabel,
            openNowOnly: $openNowOnly,
            myDogOnly: $myDogOnly,
            hasMyDog: hasMyDog,
            hasActiveChips: hasActiveChips,
            activeFilterCount: activeFilterCount,
            onTapFilter: onTapFilter,
            onTapPlan: onTapPlan,
            onNeedMyDog: onNeedMyDog,
            onClear: onClear
        )
    }
}

/// チップを横に並べた1行（`FilterChipsView` が幅に合わせて `compact` を選ぶ）。
struct FilterChipsRow: View {
    /// 絵柄をやめて余白を詰める（幅が足りないとき）
    let compact: Bool
    let targetLabel: String?
    @Binding var openNowOnly: Bool
    @Binding var myDogOnly: Bool
    let hasMyDog: Bool
    let hasActiveChips: Bool
    let activeFilterCount: Int
    let onTapFilter: () -> Void
    let onTapPlan: () -> Void
    let onNeedMyDog: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: compact ? 4 : 8) {
            FilterChip(
                title: String(localized: "絞り込み"),
                systemImage: "line.3.horizontal.decrease",
                isOn: .constant(activeFilterCount > 0),
                action: onTapFilter,
                badgeCount: activeFilterCount,
                accessibilityTitle: FilterDraft.chipAccessibilityLabel(activeCount: activeFilterCount),
                accessibilityHint: String(localized: "条件を選ぶシートを開きます"),
                compact: compact
            )
            FilterChip(
                title: targetLabel ?? String(localized: "いつ行く？"),
                systemImage: "clock",
                isOn: .constant(targetLabel != nil),
                action: onTapPlan,
                accessibilityTitle: targetLabel.map { String(localized: "いつ行く？ \($0)") },
                accessibilityHint: String(localized: "日時を選ぶシートを開きます"),
                compact: compact
            )
            FilterChip(
                title: String(localized: "うちの子OK"),
                systemImage: "dog.fill",
                isOn: Binding(
                    get: { myDogOnly && hasMyDog },
                    set: { newValue in
                        if hasMyDog { myDogOnly = newValue } else { onNeedMyDog() }
                    }
                ),
                accessibilityHint: hasMyDog ? nil : String(localized: "うちの子の設定を開きます"),
                compact: compact
            )
            FilterChip(
                title: targetLabel == nil ? String(localized: "営業中") : String(localized: "その時間に営業"),
                isOn: $openNowOnly,
                compact: compact
            )
            if hasActiveChips {
                Button(action: onClear) {
                    if compact {
                        // 幅が足りないときは「クリア」を✕の絵柄だけにする（読み上げは「条件をクリア」）
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 44)
                    } else {
                        Text("クリア")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                    }
                }
                .accessibilityLabel(Text("条件をクリア"))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, compact ? 8 : 12)
    }
}

private struct FilterChip: View {
    let title: String
    var systemImage: String?
    @Binding var isOn: Bool
    /// 指定すると、タップで ON/OFF を切り替えずにこの処理を呼ぶ（「いつ行く？」「絞り込み」はシートを開く）
    var action: (() -> Void)?
    /// 1以上のとき、タイトルの右に数のバッジを出す（「絞り込み」のオンの条件の数）
    var badgeCount = 0
    var accessibilityTitle: String?
    var accessibilityHint: String?
    /// 幅が足りないとき: 絵柄を出さず、文字と余白を詰める
    var compact = false

    var body: some View {
        Button {
            if let action { action() } else { isOn.toggle() }
        } label: {
            HStack(spacing: 4) {
                if let systemImage, !compact {
                    Image(systemName: systemImage)
                        .font(.caption.bold())
                }
                Text(title)
                    .font((compact ? Font.footnote : Font.subheadline).bold())
                    .lineLimit(1)
                if badgeCount > 0 {
                    Text(verbatim: "\(badgeCount)")
                        .font(.caption.bold())
                        .foregroundStyle(Color.brand)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Circle().fill(Color.onBrand))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isOn ? Color.onBrand : Color.primary)
            .padding(.horizontal, compact ? 8 : 14)
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
        .accessibilityLabel(Text(accessibilityTitle ?? title))
        .accessibilityValue(action == nil ? Text(isOn ? "オン" : "オフ") : Text(verbatim: ""))
        .accessibilityHint(Text(accessibilityHint ?? ""))
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
