import SwiftUI

/// お気に入り専用画面（機能4, S4設計書）: 保存済みのカフェのみを距離順（現在の検索起点から）で一覧表示する
/// （Googleマップの「保存済み」相当）。犬向け条件・未確認フィルタは無視し、常に全件を表示する。
/// `RootView` のツールバー肉球ボタンから push される（`CafeListViewModel.favoriteCafes` を参照し、
/// 地図・一覧と同じデータソースを共有する＝乖離させない）。
struct FavoritesView: View {
    @ObservedObject var viewModel: CafeListViewModel
    @ObservedObject var favoritesStore: FavoritesStore

    var body: some View {
        Group {
            if viewModel.favoriteCafes.isEmpty {
                emptyStateView
            } else {
                List(viewModel.favoriteCafes) { item in
                    NavigationLink(value: item.cafe) {
                        CafeRowView(item: item, isFavorite: favoritesStore.contains(item.cafe.id))
                    }
                }
                .listStyle(.plain)
                .accessibilityLabel(Text("お気に入りのカフェ一覧（近い順）"))
            }
        }
        .navigationTitle(String(localized: "お気に入り"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 未保存時の空状態（設計書S4: 店の肉球ボタンで保存できることを案内）
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "pawprint")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(String(localized: "お気に入りはまだありません"))
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(String(localized: "店の詳細画面にある肉球ボタンで保存できます"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}
