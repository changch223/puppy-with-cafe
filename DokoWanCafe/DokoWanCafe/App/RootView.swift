import SwiftUI

/// `RootView` の `NavigationStack(path:)` に積む値ベースの遷移先（S1修正）。
/// `navigationDestination(for: Cafe.self)` と同じ path 上に乗せることで、
/// `navigationDestination(isPresented:)` との混在（SwiftUI既知の競合でお気に入りタップが効かなくなる不具合）を解消する。
enum AppRoute: Hashable {
    case favorites
}

/// ルート画面（T021/T028）: 地図を常時ベース表示し、下部引き出しシートで一覧を併存させる
/// （Googleマップ流、S3設計書: 上部の地図/一覧セグメントは廃止）。
/// 地図とシート内一覧は同一の ViewModel（同一データ）を共有し、乖離させない（FR-003）。
struct RootView: View {
    let dependencies: AppDependencies
    @StateObject private var searchViewModel: CafeListViewModel
    @ObservedObject private var favoritesStore: FavoritesStore
    @State private var path = NavigationPath()
    @State private var showAreaPicker = false
    // 地図: ピン選択（下部コンパクトカード）・現在地ボタンの再センタリング要求（UI/UXブラッシュアップ設計書2）
    @State private var selectedMapItem: CafeWithDistance?
    @State private var recenterRequestID = 0
    // 経路チューザー（S1）: 「経路」タップ時にAppleマップ/Googleマップを選ばせる対象
    @State private var routeTarget: Cafe?
    // 下部引き出し一覧シート（S3）: 現在の段（peek/expanded）。ピンカードを閉じるとpeekへ復帰する。
    @State private var sheetDetent: CafeSheetDetent = .peek

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

                ZStack {
                    mapContent

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
                    Button {
                        // お気に入り遷移も path（値ベース）に統一する（S1修正）
                        path.append(AppRoute.favorites)
                    } label: {
                        Image(systemName: "pawprint.fill")
                    }
                    .accessibilityLabel(Text("お気に入り一覧を開く"))
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
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .favorites:
                    FavoritesView(viewModel: searchViewModel, favoritesStore: favoritesStore)
                }
            }
            .sheet(isPresented: $showAreaPicker) {
                AreaPickerView { origin in
                    // エリア変更で古い選択カードを残さない（QA指摘: 別エリアの店のカードが残留）
                    selectedMapItem = nil
                    searchViewModel.origin = origin
                    Task { await searchViewModel.refresh() }
                }
            }
            .confirmationDialog(
                String(localized: "経路を開くアプリを選択"),
                isPresented: Binding(
                    get: { routeTarget != nil },
                    set: { isPresented in if !isPresented { routeTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let routeTarget {
                    Button(String(localized: "Apple マップ")) {
                        RouteLauncher.open(cafe: routeTarget, using: .apple)
                    }
                    Button(String(localized: "Google マップ")) {
                        RouteLauncher.open(cafe: routeTarget, using: .google)
                    }
                }
                Button(String(localized: "キャンセル"), role: .cancel) {}
            }
            .task {
                await searchViewModel.refresh()
            }
            // ピンカードを閉じたら下部シートをpeekへ復帰させる（S3設計書:「カード閉じでpeek復帰」）
            // iOS 16対応のため単一引数版のonChangeを使う
            .onChange(of: selectedMapItem) { newValue in
                if newValue == nil {
                    sheetDetent = .peek
                }
            }
            // フィルタ変更（amenityFilter/includeUnverified/favoritesOnly）で選択中の店が
            // displayedResults から外れたらカードを残さない（QA指摘#2）
            .onChange(of: searchViewModel.displayedResults) { newResults in
                if let selectedMapItem, !newResults.contains(where: { $0.cafe.id == selectedMapItem.cafe.id }) {
                    self.selectedMapItem = nil
                }
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

    // MARK: - 地図（数字クラスタ廃止・下部コンパクトカード・凡例・現在地ボタン・下部引き出し一覧シート, S3設計書）

    private var mapContent: some View {
        GeometryReader { proxy in
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
                    // 右下・peek高さの少し上に配置（シート展開時は覆われてよい, S3設計書）
                    .padding(.bottom, CafeSheetDetent.peekHeight + 12)
                }

                // ピンタップ時は下部シートを下げて隠し、ピンのコンパクトカードを表示する
                // （下部要素を同時に2つ出さない, S3設計書）
                if let selectedMapItem {
                    MapPlaceCardView(
                        item: selectedMapItem,
                        onShowDetail: {
                            self.selectedMapItem = nil
                            path.append(selectedMapItem.cafe)
                        },
                        onOpenRoute: {
                            routeTarget = selectedMapItem.cafe
                        },
                        onClose: {
                            self.selectedMapItem = nil
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    CafeBottomSheet(
                        containerHeight: proxy.size.height,
                        detent: $sheetDetent,
                        items: searchViewModel.displayedResults,
                        originName: searchViewModel.origin.displayName,
                        favoriteIDs: favoritesStore.favoriteIDs,
                        isEmptyDueToFilter: searchViewModel.isEmptyDueToFilter,
                        onResetFilters: { searchViewModel.resetFilters() }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedMapItem)
        }
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
