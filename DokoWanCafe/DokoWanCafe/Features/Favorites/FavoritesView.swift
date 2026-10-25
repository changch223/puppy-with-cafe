import SwiftUI

/// 「保存」タブ（再設計 段階1a。段階2で「行きたい／行った」に分ける）: 保存済みのカフェのみを
/// 距離順（現在の検索起点から）で、さがすタブと同じ新しい行で一覧表示する。犬向け条件・未確認フィルタは無視し、常に全件を表示する。
/// `CafeListViewModel.favoriteCafes` を参照し、地図・一覧と同じデータソースを共有する（乖離させない）。
struct FavoritesView: View {
    @ObservedObject var viewModel: CafeListViewModel
    @ObservedObject var favoritesStore: FavoritesStore
    /// 空のときの「さがすタブへ」
    let onGoSearch: () -> Void

    var body: some View {
        Group {
            if viewModel.favoriteCafes.isEmpty {
                emptyStateView
            } else {
                List(viewModel.favoriteCafes) { item in
                    NavigationLink(value: item.cafe) {
                        CafeRowView(item: item, isFavorite: favoritesStore.contains(item.cafe.id), now: viewModel.clock)
                    }
                }
                .listStyle(.plain)
                .accessibilityLabel(Text("保存したカフェの一覧（近い順）"))
            }
        }
        .navigationTitle(String(localized: "保存"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 未保存時の空状態
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "pawprint")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(String(localized: "気になるお店の「保存」を押すと、ここに並びます"))
                .font(.headline)
                .multilineTextAlignment(.center)
            Button(action: onGoSearch) {
                Label(String(localized: "さがすタブへ"), systemImage: "magnifyingglass")
            }
            .buttonStyle(BrandProminentButtonStyle())
            .fixedSize()
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}
