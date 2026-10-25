import SwiftUI

/// 保存タブの2つのリスト
private enum SavedList: Hashable {
    case wantToGo
    case visited
}

/// 「保存」タブ（再設計 段階2）: 上の「行きたい（N）／行った（N）」で切り替え、保存したお店を
/// さがすタブと同じ行で一覧表示する（営業の行は「いつ行く？」で決めた対象時刻で出す）。
/// 並びは 行きたい＝追加が新しい順、行った＝行った日が新しい順。左スワイプで外す。
/// 犬向け条件・未確認フィルタは無視し、常に全件を表示する。
/// `CafeListViewModel.wantToGoCafes` / `visitedCafes` を参照し、地図・一覧と同じデータソースを共有する（乖離させない）。
struct SavedView: View {
    @ObservedObject var viewModel: CafeListViewModel
    @ObservedObject var savedStore: SavedPlacesStore
    /// 空のときの「さがすタブへ」
    let onGoSearch: () -> Void

    @State private var list: SavedList = .wantToGo

    var body: some View {
        let wantToGo = viewModel.wantToGoCafes
        let visited = viewModel.visitedCafes
        VStack(spacing: 0) {
            Picker(String(localized: "保存の種類"), selection: $list) {
                Text("行きたい（\(wantToGo.count)）").tag(SavedList.wantToGo)
                Text("行った（\(visited.count)）").tag(SavedList.visited)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            let items = list == .wantToGo ? wantToGo : visited
            if items.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(items) { item in
                        NavigationLink(value: item.cafe) {
                            CafeRowView(
                                item: item,
                                savedStatus: savedStore.status(of: item.cafe.id),
                                now: viewModel.referenceTime,
                                isTargetTime: viewModel.isTargetTime,
                                clock: viewModel.clock,
                                caption: caption(for: item.cafe)
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                savedStore.remove(item.cafe.id)
                            } label: {
                                Label(String(localized: "外す"), systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .accessibilityLabel(Text(list == .wantToGo ? "行きたいお店の一覧（追加が新しい順）" : "行ったお店の一覧（行った日が新しい順）"))
            }
        }
        .navigationTitle(String(localized: "保存"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if list == .wantToGo, !wantToGo.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: SavedListShare.message(for: wantToGo.map(\.cafe))) {
                        Label(String(localized: "リストを共有"), systemImage: "square.and.arrow.up")
                    }
                    .accessibilityLabel(Text("行きたいリストを共有"))
                }
            }
        }
    }

    /// 行った店には「10/25 に行った」を添える
    private func caption(for cafe: Cafe) -> String? {
        guard list == .visited, let date = savedStore.visitedDate(of: cafe.id) else { return nil }
        return String(localized: "\(TargetTime.monthDayText(date)) に行った")
    }

    /// 0件の文言（リストごと）
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: list == .wantToGo ? "pawprint" : "checkmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(list == .wantToGo
                ? String(localized: "気になるお店の「行きたい」を押すと、ここに並びます")
                : String(localized: "お店の詳細で「行った」を押すと、ここに記録されます"))
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
