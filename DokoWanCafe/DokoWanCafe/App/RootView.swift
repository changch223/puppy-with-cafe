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
    @ObservedObject private var favoritesStore: FavoritesStore
    @State private var mode: DisplayMode = .map
    @State private var path = NavigationPath()
    @State private var showAreaPicker = false
    // 地図: ピン選択（下部コンパクトカード）・現在地ボタンの再センタリング要求（UI/UXブラッシュアップ設計書2）
    @State private var selectedMapItem: CafeWithDistance?
    @State private var recenterRequestID = 0

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _searchViewModel = StateObject(
            wrappedValue: CafeListViewModel(
                repository: dependencies.repository,
                locationService: dependencies.locationService,
                cacheStore: dependencies.cacheStore,
                favoritesStore: dependencies.favoritesStore
            )
        )
        _favoritesStore = ObservedObject(wrappedValue: dependencies.favoritesStore)
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
                // 表示モード切替時に下部カードを残さない（QA指摘: 地図→一覧で古い選択が残留）
                // iOS 16対応のため単一引数版のonChangeを使う
                .onChange(of: mode) { _ in
                    selectedMapItem = nil
                }

                ZStack {
                    switch mode {
                    case .map:
                        mapContent
                    case .list:
                        CafeListView(viewModel: searchViewModel, favoriteIDs: favoritesStore.favoriteIDs)
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
                    sortMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // 再読み込み（refresh経路）でも現在エリアに無い古い選択カードを残さない（QA指摘）
                        selectedMapItem = nil
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
                    // エリア変更で古い選択カードを残さない（QA指摘: 別エリアの店のカードが残留）
                    selectedMapItem = nil
                    searchViewModel.origin = origin
                    Task { await searchViewModel.refresh() }
                }
            }
            .task {
                await searchViewModel.refresh()
            }
        }
    }

    /// 状態オーバーレイを出すフェーズ（オフラインはバナーのみで結果は表示する）。
    /// `.loaded` はフィルタ起因の0件（`isEmptyDueToFilter`）の時のみオーバーレイを出す（設計書4）。
    private var showsStateOverlay: Bool {
        switch searchViewModel.phase {
        case .idle, .loading, .empty, .outOfArea, .locationDenied, .error:
            return true
        case .loaded:
            return searchViewModel.isEmptyDueToFilter
        case .offline:
            return false
        }
    }

    // MARK: - 地図タブ（数字クラスタ廃止・下部コンパクトカード・凡例・現在地ボタン, UI/UXブラッシュアップ設計書2）

    private var mapContent: some View {
        ZStack(alignment: .bottom) {
            CafeMapView(
                items: searchViewModel.displayedResults,
                center: searchViewModel.searchCenter,
                favoriteIDs: favoritesStore.favoriteIDs,
                selectedItem: $selectedMapItem,
                recenterRequestID: recenterRequestID
            )

            if selectedMapItem == nil {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 12) {
                        MapLegendView(showsUnverified: hasUnverifiedResult)
                        CurrentLocationButton {
                            recenterRequestID += 1
                        }
                    }
                }
                .padding(.trailing, 12)
                .padding(.bottom, 12)
            }

            if let selectedMapItem {
                MapPlaceCardView(
                    item: selectedMapItem,
                    onShowDetail: {
                        self.selectedMapItem = nil
                        path.append(selectedMapItem.cafe)
                    },
                    onOpenRoute: {
                        MapViewModel.openInMaps(cafe: selectedMapItem.cafe)
                    },
                    onClose: {
                        self.selectedMapItem = nil
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedMapItem)
    }

    /// 現在の表示結果に未確認ピン（灰）が含まれるか（凡例に灰エントリを足すかの判定に使う）
    private var hasUnverifiedResult: Bool {
        searchViewModel.displayedResults.contains { MapPinCategory.category(for: $0.cafe) == .unverified }
    }

    @ViewBuilder
    private var banners: some View {
        if dependencies.isSampleMode {
            NoticeBanner(
                text: String(localized: "サンプルデータ表示中（架空の店舗情報です）"),
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange
            )
        } else if let generatedAt = dependencies.dataGeneratedAt {
            // FR-032: データの生成日時（鮮度）を提示
            NoticeBanner(
                text: String(localized: "データ更新: \(generatedAt.formatted(date: .abbreviated, time: .omitted)) 時点"),
                systemImage: "arrow.triangle.2.circlepath",
                tint: .gray
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

    /// フィルタメニュー（可否4値ではなく犬向け条件＋表示設定, 設計書4）。
    /// 適用中の条件数をアイコンにバッジ表示する。
    private var filterMenu: some View {
        Menu {
            Section(String(localized: "犬向け条件")) {
                Toggle(String(localized: "店内OK"), isOn: $searchViewModel.amenityFilter.indoorOnly)
                Toggle(String(localized: "テラスOK"), isOn: $searchViewModel.amenityFilter.terraceOnly)
                Toggle(String(localized: "大型犬OK"), isOn: $searchViewModel.amenityFilter.largeDogOnly)
                Toggle(String(localized: "犬メニューあり"), isOn: $searchViewModel.amenityFilter.dogMenuOnly)
            }
            Section(String(localized: "表示")) {
                Toggle(String(localized: "未確認の店も表示"), isOn: $searchViewModel.includeUnverified)
                Toggle(String(localized: "お気に入りのみ"), isOn: $searchViewModel.favoritesOnly)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: searchViewModel.activeFilterCount > 0
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
                if searchViewModel.activeFilterCount > 0 {
                    Text("\(searchViewModel.activeFilterCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Circle().fill(Color.red))
                        .offset(x: 10, y: -8)
                }
            }
        }
        .accessibilityLabel(Text(
            searchViewModel.activeFilterCount > 0
                ? "犬向け条件で絞り込み、\(searchViewModel.activeFilterCount)件適用中"
                : "犬向け条件で絞り込み"
        ))
    }

    /// 並び替えメニュー（距離順/確認日が新しい順, 設計書4）
    private var sortMenu: some View {
        Menu {
            Picker(String(localized: "並び替え"), selection: $searchViewModel.sortOrder) {
                Text("距離順").tag(CafeSortOrder.distance)
                Text("確認日が新しい順").tag(CafeSortOrder.recentlyVerified)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
        .accessibilityLabel(Text("並び替え"))
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
