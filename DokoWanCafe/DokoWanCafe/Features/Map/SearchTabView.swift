import CoreLocation
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
    /// 「うちの子OK」チップを未設定のまま押したとき（うちの子の設定を開く）
    let onNeedMyDog: () -> Void
    /// 検索画面・「いつ行く？」シートが開いているか（開いている間は初回の2問を出さない。RootView が閉じてから出す）
    @Binding var isModalOpen: Bool
    /// 詳細へ進む（さがすタブの NavigationStack に積む）
    let onShowDetail: (Cafe) -> Void

    @State private var recenterRequestID = 0
    /// 検索画面から店を開いたときの「この座標へ寄せる」要求（地図だけを動かす。起点は変えない）
    @State private var focusRequest: MapFocusRequest?
    /// 経路チューザー: 「経路」タップ時にAppleマップ/Googleマップを選ばせる対象
    @State private var routeTarget: Cafe?
    @State private var sheetDetent: CafeSheetDetent = .peek
    @State private var showSearch = false
    /// 「いつ行く？」シート
    @State private var showPlanSheet = false
    /// 「絞り込み」シート
    @State private var showFilterSheet = false
    /// 「絞り込み」シートを閉じたあとに開くもの（シートは重ねて出せないので、閉じ終わってから開く）
    @State private var afterFilterSheet: AfterFilterSheet?
    @State private var topOverlayHeight: CGFloat = 0
    /// カードを横にめくったときの「ピンを見える範囲へ出す」要求（地図だけを動かす）
    @State private var revealRequest: MapRevealRequest?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// ユーザーが地図を動かして止まったときの地図の中心と見えている幅（メートル）。「このあたりで探す」の判定に使う。
    /// プログラムで地図が動いたとき・ボタンを押したときは nil に戻る。端末の中だけで使い、保存も送信もしない。
    @State private var userMovedRegion: MovedRegion?
    /// 「このあたりで探す」を押した回数（触覚フィードバックのきっかけ）
    @State private var searchHereCount = 0

    private enum AfterFilterSheet {
        case plan
        case myDog
    }

    private struct MovedRegion {
        let center: CLLocationCoordinate2D
        let widthMeters: Double
    }

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
                    dog: viewModel.dogProfile,
                    selectedItem: $selectedMapItem,
                    recenterRequestID: recenterRequestID,
                    focusRequest: focusRequest,
                    // 「このあたりで探す」で起点が地図の中心になったときは、地図を動かさない
                    revealRequest: revealRequest,
                    coveredTop: proxy.safeAreaInsets.top + topOverlayHeight,
                    coveredBottom: selectedMapItem == nil ? 0 : cardCoveredHeight(containerHeight: proxy.size.height),
                    movesToCenterOnChange: !isMapCenterOrigin,
                    onRegionSettled: { center, widthMeters, byUser in
                        userMovedRegion = byUser ? MovedRegion(center: center, widthMeters: widthMeters) : nil
                    }
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
                    bottomArea(containerWidth: proxy.size.width, containerHeight: proxy.size.height)
                }

                // 探し直している間（前の結果を残している間）は「探しています…」、それ以外で条件を満たせば「このあたりで探す」
                if isSearchingWithResults {
                    SearchingIndicator()
                        .padding(.top, topOverlayHeight + 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity)
                } else if showsSearchHereButton {
                    SearchHereButton(action: searchHere)
                        .padding(.top, topOverlayHeight + 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity)
                }

                topOverlay
            }
            .animation(.easeInOut(duration: 0.2), value: showsSearchHereButton)
            .animation(.easeInOut(duration: 0.2), value: isSearchingWithResults)
            .animation(.easeInOut(duration: 0.2), value: selectedMapItem)
            .onChange(of: selectedMapItem?.cafe.id) { _, newID in
                if newID != nil { revealSelectedPin() }
            }
            .onPreferenceChange(TopOverlayHeightKey.self) { topOverlayHeight = $0 }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .light), trigger: searchHereCount)
        .onChange(of: showSearch || showPlanSheet || showFilterSheet || afterFilterSheet != nil) { _, isOpen in isModalOpen = isOpen }
        .fullScreenCover(isPresented: $showSearch) {
            CafeSearchView(
                allCafes: viewModel.allLoadedCafes,
                recentSearchStore: recentSearchStore,
                wantToGoIDs: savedStore.places.wantToGoIDs,
                origin: viewModel.origin,
                originCoordinate: viewModel.searchCenter,
                referenceTime: viewModel.referenceTime,
                isTargetTime: viewModel.isTargetTime,
                onSelectOrigin: { origin in
                    showSearch = false
                    changeOrigin(to: origin)
                },
                onApplyConditions: { conditions in
                    showSearch = false
                    applyConditions(conditions)
                },
                onSelectScene: { scene in
                    showSearch = false
                    selectedMapItem = nil
                    viewModel.applyScene(scene)
                },
                onSelectCafe: { cafe in
                    showSearch = false
                    openCafeFromSearch(cafe)
                },
                onCancel: { showSearch = false }
            )
        }
        .sheet(isPresented: $showPlanSheet) {
            PlanTimeSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showFilterSheet, onDismiss: openSheetAfterFilter) {
            FilterSheet(
                viewModel: viewModel,
                onOpenPlan: { afterFilterSheet = .plan },
                onNeedMyDog: { afterFilterSheet = .myDog }
            )
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
        case .loading:
            // 起点を変えて探し直す間は、前の結果を地図と一覧に残す（「このあたりで探す」で地図が一瞬隠れないように）。
            // まだ何も出ていない初回だけ読み込み中を出す
            return viewModel.displayedResults.isEmpty
        case .idle, .empty, .outOfArea, .locationDenied, .error:
            return true
        case .loaded, .offline:
            return false
        }
    }

    /// 「絞り込み」シートが閉じ終わったあとに、「いつ行く？」またはうちの子の設定を開く
    private func openSheetAfterFilter() {
        guard let next = afterFilterSheet else { return }
        afterFilterSheet = nil
        switch next {
        case .plan: showPlanSheet = true
        case .myDog: onNeedMyDog()
        }
    }

    // MARK: - 検索地点の切り替え

    /// 検索地点を変えて探し直す。別の場所の店のカードを残さない。
    private func changeOrigin(to origin: SearchOrigin) {
        selectedMapItem = nil
        viewModel.origin = origin
        Task { await viewModel.refresh() }
    }

    /// 検索画面の条件の提案を、地図の条件チップ（フィルタ）に反映する。オンにするだけで、起点は変えない。
    private func applyConditions(_ conditions: [SearchCondition]) {
        var amenities = viewModel.amenityFilter
        var openNowOnly = viewModel.openNowOnly
        var myDogOnly = viewModel.myDogOnly
        SearchCondition.apply(conditions, amenities: &amenities, openNowOnly: &openNowOnly, myDogOnly: &myDogOnly)
        viewModel.amenityFilter = amenities
        viewModel.openNowOnly = openNowOnly
        viewModel.myDogOnly = myDogOnly
    }

    /// 検索画面で選んだ店を開く。今の表示結果にいる店は、地図の上のカードを開いて地図をその店へ寄せる（起点は変えない）。
    /// 絞り込みで外れている店は、カードが出せないので詳細を開く。
    private func openCafeFromSearch(_ cafe: Cafe) {
        guard let item = viewModel.displayedResults.first(where: { $0.cafe.id == cafe.id }) else {
            onShowDetail(cafe)
            return
        }
        selectedMapItem = item
        focusRequest = MapFocusRequest(
            id: (focusRequest?.id ?? 0) + 1,
            coordinate: CLLocationCoordinate2D(latitude: cafe.latitude, longitude: cafe.longitude)
        )
    }

    private var isMapCenterOrigin: Bool {
        if case .mapCenter = viewModel.origin { return true }
        return false
    }

    /// 読み込み中で、前の結果をまだ地図と一覧に出しているか（このとき検索バーの下に「探しています…」を出す）
    private var isSearchingWithResults: Bool {
        viewModel.phase == .loading && !showsStateOverlay
    }

    /// 「このあたりで探す」を出すか（判定は `MapRecenterLogic`）。状態オーバーレイ（読み込み中・対象外など）の間は出さない
    private var showsSearchHereButton: Bool {
        guard !showsStateOverlay, let moved = userMovedRegion else { return false }
        return MapRecenterLogic.shouldOffer(
            didUserMove: true,
            mapCenter: moved.center,
            visibleWidthMeters: moved.widthMeters,
            searchCenter: viewModel.searchCenter,
            hasSelectedCard: selectedMapItem != nil,
            isSheetLarge: sheetDetent == .large
        )
    }

    /// 「このあたりで探す」: 地図の中心を起点にして探し直す（地図は動かさない）。最近の検索には残さない。
    private func searchHere() {
        guard let moved = userMovedRegion else { return }
        searchHereCount += 1
        userMovedRegion = nil
        changeOrigin(to: .mapCenter(latitude: moved.center.latitude, longitude: moved.center.longitude))
    }

    // MARK: - 上部（検索バー・チップ・バナー）

    private var topOverlay: some View {
        VStack(spacing: 8) {
            HomeSearchBar(
                dog: viewModel.dogProfile,
                originLabel: viewModel.origin.aroundLabel,
                onTapSearch: { showSearch = true },
                // ✕: 現在地に戻る（検索地点を変えるときと同じ扱い）
                onClearOrigin: { changeOrigin(to: .currentLocation) },
                onTapMyDog: onOpenMyDog
            )
            .padding(.horizontal, 12)

            FilterChipsView(
                targetLabel: viewModel.targetTime.map(TargetTime.shortLabel),
                openNowOnly: $viewModel.openNowOnly,
                myDogOnly: $viewModel.myDogOnly,
                hasMyDog: viewModel.dogProfile != nil,
                hasActiveChips: viewModel.hasActiveChips,
                activeFilterCount: viewModel.filterDraft.activeCount,
                onTapFilter: { showFilterSheet = true },
                onTapPlan: { showPlanSheet = true },
                onNeedMyDog: onNeedMyDog,
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

    /// 選択中の店と同じ場所（5m 以内）の店（選択中のときだけ計算する。地図のピンと同じ並び）
    private func sameSpotItems(of selected: CafeWithDistance) -> [CafeWithDistance] {
        SameSpotGrouping.group(
            of: selected, in: viewModel.displayedResults,
            favoriteIDs: savedStore.places.wantToGoIDs, at: viewModel.referenceTime
        ) ?? []
    }

    /// 店のカードが地図の下からふさぐ高さ（カードの高さ。地図の見える範囲の判定に使う）
    private func cardCoveredHeight(containerHeight: CGFloat) -> CGFloat {
        let hasSameSpotRow = selectedMapItem.map { sameSpotItems(of: $0).count > 1 } ?? false
        return CafeSheetDetent.cardHeight(
            containerHeight: containerHeight, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
            hasSameSpotRow: hasSameSpotRow
        )
    }

    /// カードをめくった・同じ場所の列で替えたとき、その店のピンが見える範囲の外なら地図を寄せる（見えているなら動かさない）
    private func selectFromCard(_ item: CafeWithDistance) {
        guard item.cafe.id != selectedMapItem?.cafe.id else { return }
        selectedMapItem = item
    }

    /// 選んだ店のピンがカードや上の検索バーに隠れるなら、見える所まで地図を寄せる（見えているなら動かさない）。
    /// ピンを押したとき・カードをめくったとき・同じ場所の列で替えたときに共通
    private func revealSelectedPin() {
        guard let cafe = selectedMapItem?.cafe else { return }
        revealRequest = MapRevealRequest(
            id: (revealRequest?.id ?? 0) + 1,
            coordinate: CLLocationCoordinate2D(latitude: cafe.latitude, longitude: cafe.longitude)
        )
    }

    private func bottomArea(containerWidth: CGFloat, containerHeight: CGFloat) -> some View {
        let place = selectedMapItem.flatMap { CardPaging.position(of: $0.cafe.id, in: viewModel.displayedResults) }
        let showsPosition = (place?.total ?? 0) > 1
        let showsLocationButton = sheetDetent != .large || selectedMapItem != nil
        return VStack(alignment: .trailing, spacing: 8) {
            if showsPosition || showsLocationButton {
                HStack(alignment: .bottom) {
                    // 何店目かの控えめな手がかり（横にめくれるカードのとき）
                    if showsPosition, let place {
                        CardPositionLabel(position: place)
                    }
                    Spacer(minLength: 0)
                    if showsLocationButton {
                        CurrentLocationButton {
                            // 「現在地に戻る」: 起点が現在地でなければ現在地に戻して探し直す（地図も現在地へ動く）。
                            // 起点がすでに現在地なら、地図だけを現在地へ戻す（現在地を探している間は何もしない。
                            // 前の検索地点へ動いてしまうため。確定すれば地図は現在地へ動く）
                            if viewModel.origin == .currentLocation {
                                if viewModel.phase != .loading { recenterRequestID += 1 }
                            } else {
                                changeOrigin(to: .currentLocation)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            if let selected = selectedMapItem {
                PlaceCardPager(
                    items: viewModel.displayedResults,
                    selected: selected,
                    savedPlaces: savedStore.places,
                    now: viewModel.referenceTime,
                    isTargetTime: viewModel.isTargetTime,
                    containerWidth: containerWidth,
                    containerHeight: containerHeight,
                    sameSpot: { sameSpotItems(of: $0) },
                    onSelect: selectFromCard,
                    onShowDetail: onShowDetail,
                    onOpenRoute: { routeTarget = $0 },
                    onToggleWantToGo: { savedStore.toggleWantToGo($0) },
                    onClose: { selectedMapItem = nil },
                    onSaveAction: { savedStore.apply($0, to: $1) }
                )
                // 横スクロールは縦に広がろうとするので、カードの高さに固定する（上の「2 / 12」と現在地ボタンを画面の外へ押し出さない）
                .frame(height: cardCoveredHeight(containerHeight: containerHeight), alignment: .bottom)
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
                        myDog: viewModel.myDogFilterDog,
                        includeUnverified: viewModel.includeUnverified,
                        sortOrder: viewModel.sortOrder,
                        // 結果が確定した起点で出す（探し直している間は前の結果のままなので、食い違わせない）
                        originName: viewModel.loadedOrigin.displayName,
                        isCurrentLocation: viewModel.loadedOrigin == .currentLocation,
                        items: viewModel.displayedResults,
                        referenceTime: viewModel.referenceTime
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
                    relaxation: viewModel.isEmptyDueToFilter ? viewModel.bestRelaxation() : nil,
                    onRelax: { viewModel.relax($0) },
                    onResetFilters: { viewModel.resetFilters() }
                )
                .transition(.move(edge: .bottom))
            }
        }
    }
}

/// 横にめくれるカードの「2 / 12」（何店目か）。控えめな札
private struct CardPositionLabel: View {
    let position: CardPaging.Position

    var body: some View {
        Text(position.text)
            .font(.caption.monospacedDigit().bold())
            .foregroundStyle(Color(.label))
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(Color(.systemBackground).opacity(0.92), in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            .accessibilityLabel(Text("\(position.number)店目、全\(position.total)店"))
    }
}
