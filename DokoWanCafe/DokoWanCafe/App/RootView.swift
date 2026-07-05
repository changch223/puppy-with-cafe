import SwiftUI

/// ルート画面（T021/T028）: 現在地起点の地図＋一覧を切り替え・連動表示する。
/// 地図と一覧は同一の ViewModel（同一データ）を共有し、乖離させない（FR-003）。
struct RootView: View {
    private enum DisplayMode: Hashable {
        case map
        case list
    }

    let dependencies: AppDependencies
    @StateObject private var searchViewModel: CafeListViewModel
    @State private var mode: DisplayMode = .map
    @State private var path = NavigationPath()
    @State private var showAreaPicker = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _searchViewModel = StateObject(
            wrappedValue: CafeListViewModel(
                repository: dependencies.repository,
                locationService: dependencies.locationService,
                cacheStore: dependencies.cacheStore
            )
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                banners

                Picker(String(localized: "表示"), selection: $mode) {
                    Text("地図").tag(DisplayMode.map)
                    Text("一覧").tag(DisplayMode.list)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .accessibilityLabel(Text("表示切り替え"))

                ZStack {
                    switch mode {
                    case .map:
                        CafeMapView(
                            items: searchViewModel.displayedResults,
                            center: searchViewModel.searchCenter,
                            radiusMeters: searchViewModel.radiusMeters,
                            onSelect: { cafe in path.append(cafe) }
                        )
                    case .list:
                        CafeListView(viewModel: searchViewModel)
                    }

                    if showsStateOverlay {
                        SearchStateView(viewModel: searchViewModel) {
                            showAreaPicker = true
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.regularMaterial)
                    }
                }
            }
            .navigationTitle("Puppy With Cafe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAreaPicker = true
                    } label: {
                        Label(searchViewModel.origin.displayName, systemImage: "mappin.and.ellipse")
                            .labelStyle(.titleAndIcon)
                    }
                    .accessibilityLabel(Text("検索する地域を変更"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await searchViewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(Text("再読み込み"))
                }
            }
            .navigationDestination(for: Cafe.self) { cafe in
                CafeDetailView(cafe: cafe, dependencies: dependencies)
            }
            .sheet(isPresented: $showAreaPicker) {
                AreaPickerView { origin in
                    searchViewModel.origin = origin
                    Task { await searchViewModel.refresh() }
                }
            }
            .task {
                await searchViewModel.refresh()
            }
        }
    }

    /// 状態オーバーレイを出すフェーズ（オフラインはバナーのみで結果は表示する）
    private var showsStateOverlay: Bool {
        switch searchViewModel.phase {
        case .idle, .loading, .empty, .outOfArea, .locationDenied, .error:
            return true
        case .loaded, .offline:
            return false
        }
    }

    @ViewBuilder
    private var banners: some View {
        if dependencies.isSampleMode {
            NoticeBanner(
                text: String(localized: "サンプルデータ表示中（バックエンド未設定・架空の店舗情報です）"),
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange
            )
        }
        if case .offline(let fetchedAt) = searchViewModel.phase {
            NoticeBanner(
                text: String(localized: "オフライン: \(fetchedAt.formatted(date: .abbreviated, time: .shortened)) 時点の情報です（最新でない可能性があります）"),
                systemImage: "wifi.slash",
                tint: .gray
            )
        }
    }

    private var filterMenu: some View {
        Menu {
            ForEach(DogPolicyStatus.allCases) { status in
                Button {
                    if searchViewModel.statusFilter.contains(status) {
                        searchViewModel.statusFilter.remove(status)
                    } else {
                        searchViewModel.statusFilter.insert(status)
                    }
                } label: {
                    Label(
                        status.displayName,
                        systemImage: searchViewModel.statusFilter.contains(status)
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel(Text("犬同伴可否で絞り込み"))
    }
}

/// 画面上部の通知バナー（サンプルモード・オフライン等の明示に使用）
struct NoticeBanner: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tint.opacity(0.15))
        .foregroundStyle(tint == .gray ? Color.primary : tint)
        .accessibilityElement(children: .combine)
    }
}
