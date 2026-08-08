import SwiftUI

/// 下部引き出し一覧シートの3段階の高さ（S3設計書: peek/medium/large, Googleマップ流）。
/// 高さ計算・最近傍段の判定は UI 非依存の純ロジックとして分離し、XCTest で検証する（憲章 原則IV）。
enum CafeSheetDetent: CaseIterable, Equatable {
    /// グラバー＋ヘッダー＋先頭1〜2行が覗く最小段
    case peek
    /// 画面の約半分
    case medium
    /// ナビバー下までの約9割
    case large

    /// peekの固定高さ（凡例・現在地ボタンをこの少し上に配置するためにも参照する）
    static let peekHeight: CGFloat = 150
    private static let mediumRatio: CGFloat = 0.5
    private static let largeRatio: CGFloat = 0.9

    /// 地図表示領域（コンテナ）の高さに対する各段の実際の高さ。
    func height(containerHeight: CGFloat) -> CGFloat {
        switch self {
        case .peek: return Self.peekHeight
        case .medium: return containerHeight * Self.mediumRatio
        case .large: return containerHeight * Self.largeRatio
        }
    }

    /// ドラッグ終了時点の高さから最も近い段を求める純関数。
    /// グラバー/ヘッダーのドラッグを離した時に、この段へスプリングスナップする（S3設計書）。
    static func nearest(toHeight height: CGFloat, containerHeight: CGFloat) -> CafeSheetDetent {
        allCases.min { lhs, rhs in
            abs(lhs.height(containerHeight: containerHeight) - height)
                < abs(rhs.height(containerHeight: containerHeight) - height)
        } ?? .peek
    }
}

/// 下部から引き出せるカフェ一覧のカスタムシート（S3設計書, 機能1）。
/// system の `.sheet` は使わない（単一の `NavigationStack` を保ち、行タップの詳細遷移とピンカードを両立させるため）。
/// 中身は `CafeListViewModel.displayedResults` をそのまま流用し、地図・一覧で表示結果を乖離させない（FR-003）。
struct CafeBottomSheet: View {
    /// 地図表示領域（親のZStack）の高さ。medium/largeの割合計算に使う。
    let containerHeight: CGFloat
    @Binding var detent: CafeSheetDetent
    let items: [CafeWithDistance]
    /// ヘッダーに表示する検索起点名（現在地/手動エリア/検索結果地点, FR-017）
    let originName: String
    let favoriteIDs: Set<UUID>
    /// フィルタ起因の0件か（true の時のみシート内に空状態＋条件リセットを出す, 設計書4踏襲）
    let isEmptyDueToFilter: Bool
    let onResetFilters: () -> Void

    /// ドラッグ中の追従用オフセット（離すと `withAnimation` でスプリングスナップしつつ0に戻す）
    @State private var dragTranslation: CGFloat = 0

    private var baseHeight: CGFloat { detent.height(containerHeight: containerHeight) }

    private var currentHeight: CGFloat {
        let proposed = baseHeight - dragTranslation
        let minHeight = CafeSheetDetent.peek.height(containerHeight: containerHeight)
        let maxHeight = CafeSheetDetent.large.height(containerHeight: containerHeight)
        return min(max(proposed, minHeight), maxHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            Divider()
            content
        }
        .frame(maxWidth: .infinity)
        .frame(height: currentHeight)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
    }

    /// グラバー＋ヘッダー（ドラッグでdetentを切り替える領域。一覧本体のスクロールとは独立させる）
    private var dragHandle: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(items.count)件のカフェ")
                        .font(.headline)
                    Text(originName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("ドラッグして一覧の高さを変更できます"))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                let proposedHeight = baseHeight - value.translation.height
                let nextDetent = CafeSheetDetent.nearest(toHeight: proposedHeight, containerHeight: containerHeight)
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.86)) {
                    detent = nextDetent
                    dragTranslation = 0
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if isEmptyDueToFilter {
            emptyStateView
        } else {
            List(items) { item in
                NavigationLink(value: item.cafe) {
                    CafeRowView(item: item, isFavorite: favoriteIDs.contains(item.cafe.id))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    /// フィルタ起因の0件（設計書4踏襲: `SearchStateView` と同じ文言・導線をシート内でも提供）
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("条件に合う犬同伴OKのカフェが見つかりませんでした")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button {
                onResetFilters()
            } label: {
                Label(String(localized: "条件をリセット"), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
