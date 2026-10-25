import SwiftUI

/// 上部オーバーレイ（検索バー＋チップ＋バナー）の高さを親へ伝える
private struct TopOverlayHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 「さがす」タブ（再設計 段階1a）: 地図を常時ベースに、上に検索バーと条件チップ、下に3段の一覧シート。
/// ピンを選ぶとシートの中身がその店のカードに変わる。地図とシート内一覧は同一の ViewModel を共有する（FR-003）。
struct SearchTabView: View {
    let dependencies: AppDependencies
    @ObservedObject var viewModel: CafeListViewModel
    @ObservedObject var savedStore: SavedPlacesStore
    @ObservedObject var recentSearchStore: RecentSearchStore
    @Binding var selectedMapItem: CafeWithDistance?
    let onOpenMyDog: () -> Void
    /// 詳細へ進む（さがすタブの NavigationStack に積む）
    let onShowDetail: (Cafe) -> Void

    @State private var recenterRequestID = 0
    /// 経路チューザー: 「経路」タップ時にAppleマップ/Googleマップを選ばせる対象
    @State private var routeTarget: Cafe?
    @State private var sheetDetent: CafeSheetDetent = .peek
    @State private var showSearch = false
    /// 「いつ行く？」シート
    @State private var showPlanSheet = false
    @State private var topOverlayHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                CafeMapView(
                    items: viewModel.displayedResults,
                    itemsRevision: viewModel.displayRevision,
                    center: viewModel.searchCenter,
                    savedPlaces: savedStore.places,
                    now: viewModel.referenceTime,
                    isTargetTime: viewModel.isTargetTime,
                    clock: viewModel.clock,
                    selectedItem: $selectedMapItem,
                    recenterRequestID: recenterRequestID
                )
                .ignoresSafeArea(edges: .top)

                if showsStateOverlay {
                    SearchStateView(viewModel: viewModel) {
                        showSearch = true
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, topOverlayHeight)
                    .background(.regularMaterial)
                } else {
                    bottomArea(containerHeight: proxy.size.height)
                }

                topOverlay
            }
            .animation(.easeInOut(duration: 0.2), value: selectedMapItem)
            .onPreferenceChange(TopOverlayHeightKey.self) { topOverlayHeight = $0 }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showSearch) {
            CafeSearchView(
                allCafes: viewModel.allLoadedCafes,
                recentSearchStore: recentSearchStore,
                onSelectOrigin: { origin in
                    showSearch = false
                    // 検索地点が変わったとき、別の場所の店のカードを残さない
                    selectedMapItem = nil
                    viewModel.origin = origin
                    Task { await viewModel.refresh() }
                },
                onSelectCafe: { cafe in
                    showSearch = false
                    onShowDetail(cafe)
                },
                onCancel: { showSearch = false }
            )
        }
        .sheet(isPresented: $showPlanSheet) {
            PlanTimeSheet(viewModel: viewModel)
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
        // フィルタ変更や再読み込みで選択中の店が displayedResults から外れたらカードを残さない。
        // 残っている場合は、更新後の最新の店データ（営業時間・距離など）に引き直す。
        .onChange(of: viewModel.displayedResults) { _, newResults in
            guard let selectedMapItem else { return }
            if let fresh = newResults.first(where: { $0.cafe.id == selectedMapItem.cafe.id }) {
                if fresh != selectedMapItem { self.selectedMapItem = fresh }
            } else {
                self.selectedMapItem = nil
            }
        }
    }

    /// 状態オーバーレイを出すフェーズ（オフラインはバナーのみで結果は表示する）。
    /// フィルタ起因の0件はシート内の「条件に合うお店がありません」で扱う。
    private var showsStateOverlay: Bool {
        switch viewModel.phase {
        case .idle, .loading, .empty, .outOfArea, .locationDenied, .error:
            return true
        case .loaded, .offline:
            return false
        }
    }

    // MARK: - 上部（検索バー・チップ・バナー）

    private var topOverlay: some View {
        VStack(spacing: 8) {
            HomeSearchBar(
                onTapSearch: { showSearch = true },
                onTapMyDog: onOpenMyDog
            )
            .padding(.horizontal, 12)

            FilterChipsView(
                targetLabel: viewModel.targetTime.map(TargetTime.shortLabel),
                openNowOnly: $viewModel.openNowOnly,
                amenityFilter: $viewModel.amenityFilter,
                hasActiveChips: viewModel.hasActiveChips,
                onTapPlan: { showPlanSheet = true },
                onClear: { viewModel.resetFilters() }
            )

            banners
                .padding(.horizontal, 12)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { inner in
                Color.clear.preference(key: TopOverlayHeightKey.self, value: inner.size.height)
            }
        )
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var banners: some View {
        VStack(spacing: 4) {
            if dependencies.isSampleMode {
                NoticeBanner(
                    text: String(localized: "サンプルデータ表示中（架空の店舗情報です）"),
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            }
            if case .offline(let fetchedAt) = viewModel.phase {
                NoticeBanner(
                    text: String(localized: "オフライン: \(fetchedAt.formatted(date: .abbreviated, time: .shortened)) 時点の情報です（最新でない可能性があります）"),
                    systemImage: "wifi.slash",
                    tint: .gray
                )
            }
        }
    }

    // MARK: - 下部（一覧シート／店のカード）

    private func bottomArea(containerHeight: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            if sheetDetent != .large || selectedMapItem != nil {
                CurrentLocationButton {
                    recenterRequestID += 1
                }
                .padding(.trailing, 12)
            }

            if let selected = selectedMapItem {
                PlaceCardView(
                    item: selected,
                    savedStatus: savedStore.status(of: selected.cafe.id),
                    now: viewModel.referenceTime,
                    isTargetTime: viewModel.isTargetTime,
                    containerHeight: containerHeight,
                    onShowDetail: { onShowDetail(selected.cafe) },
                    onOpenRoute: { routeTarget = selected.cafe },
                    onToggleWantToGo: { savedStore.toggleWantToGo(selected.cafe.id) },
                    onClose: { selectedMapItem = nil }
                )
                .transition(.move(edge: .bottom))
            } else {
                CafeBottomSheet(
                    containerHeight: containerHeight,
                    topReserved: topOverlayHeight,
                    detent: $sheetDetent,
                    headline: SheetHeadline.make(
                        count: viewModel.displayedResults.count,
                        amenities: viewModel.amenityFilter,
                        openNowOnly: viewModel.openNowOnly,
                        targetLabel: viewModel.targetTime.map(TargetTime.shortLabel),
                        includeUnverified: viewModel.includeUnverified,
                        sortOrder: viewModel.sortOrder,
                        originName: viewModel.origin.displayName,
                        isCurrentLocation: viewModel.origin == .currentLocation
                    ),
                    sortOrder: $viewModel.sortOrder,
                    items: viewModel.displayedResults,
                    savedStatuses: savedStore.places,
                    now: viewModel.referenceTime,
                    isTargetTime: viewModel.isTargetTime,
                    clock: viewModel.clock,
                    isEmptyDueToFilter: viewModel.isEmptyDueToFilter,
                    unverifiedCandidateCount: viewModel.unverifiedCandidateCount,
                    includeUnverified: $viewModel.includeUnverified,
                    onResetFilters: { viewModel.resetFilters() }
                )
                .transition(.move(edge: .bottom))
            }
        }
    }
}
