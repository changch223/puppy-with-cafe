import SwiftUI

/// 下のタブ（再設計 段階1a）
enum AppTab: Hashable {
    /// 地図と一覧
    case search
    /// 保存したお店（行きたい／行った）
    case saved
    /// うちの子（段階3で犬の設定が入る）
    case myDog
}

/// ルート画面（T021/T028）: 下に3つのタブ（さがす／保存／うちの子）。
/// 地図とシート内一覧・保存の一覧は同一の ViewModel（同一データ）を共有し、乖離させない（FR-003）。
/// タブごとに NavigationStack を持ち、さがす・保存の両方から店の詳細へ進める。
struct RootView: View {
    let dependencies: AppDependencies
    @StateObject private var searchViewModel: CafeListViewModel
    @StateObject private var recentSearchStore = RecentSearchStore()
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var savedStore: SavedPlacesStore
    @State private var tab: AppTab = .search
    @State private var searchPath = NavigationPath()
    @State private var savedPath = NavigationPath()
    /// 地図: ピン選択（一覧シートがその店のカードに変わる）。再読み込みで古い選択を残さないため、ここで保持する。
    @State private var selectedMapItem: CafeWithDistance?

    /// 営業中の判定・ピンの薄さ・営業の行を、時間が進んだぶん定期的に計算し直す
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _searchViewModel = StateObject(
            wrappedValue: CafeListViewModel(
                repository: dependencies.repository,
                locationService: dependencies.locationService,
                cacheStore: dependencies.cacheStore,
                savedStore: dependencies.savedStore
            )
        )
        _savedStore = ObservedObject(wrappedValue: dependencies.savedStore)
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $searchPath) {
                SearchTabView(
                    dependencies: dependencies,
                    viewModel: searchViewModel,
                    savedStore: savedStore,
                    recentSearchStore: recentSearchStore,
                    selectedMapItem: $selectedMapItem,
                    onOpenMyDog: { tab = .myDog },
                    onShowDetail: { searchPath.append($0) }
                )
                .navigationDestination(for: Cafe.self) { cafe in
                    CafeDetailView(cafe: cafe, dependencies: dependencies)
                }
            }
            .tabItem { Label(String(localized: "さがす"), systemImage: "map") }
            .tag(AppTab.search)

            NavigationStack(path: $savedPath) {
                SavedView(
                    viewModel: searchViewModel,
                    savedStore: savedStore,
                    onGoSearch: { tab = .search }
                )
                .navigationDestination(for: Cafe.self) { cafe in
                    CafeDetailView(cafe: cafe, dependencies: dependencies)
                }
            }
            .tabItem { Label(String(localized: "保存"), systemImage: "pawprint") }
            .tag(AppTab.saved)

            NavigationStack {
                MyDogView(
                    dataGeneratedAt: dependencies.dataGeneratedAt,
                    isSampleMode: dependencies.isSampleMode,
                    isReloading: searchViewModel.phase == .loading,
                    onReload: {
                        // 再読み込み（refresh経路）でも現在エリアに無い古い選択カードを残さない
                        selectedMapItem = nil
                        // 明示操作なのでリモート取得（強制）を待ってから再表示する
                        Task { await searchViewModel.reloadFromRemote() }
                    }
                )
            }
            .tabItem { Label(String(localized: "うちの子"), systemImage: "dog") }
            .tag(AppTab.myDog)
        }
        .tint(Color.brand)
        .task {
            // ローカルのデータで即表示 → 裏でリモート更新（stale-while-revalidate）
            await searchViewModel.refreshThenRevalidate()
        }
        // 前面に戻ったときも裏でデータ更新を確認する（取得間隔・失敗抑止は force:false の既存ルール。
        // 起動時の .task と重なっても revalidate 側で同時実行を避ける）
        .onReceive(minuteTimer) { _ in searchViewModel.tick() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                searchViewModel.tick()
                Task { await searchViewModel.revalidateInBackground() }
            }
        }
    }
}
