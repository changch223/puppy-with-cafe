import SwiftUI

/// 下のタブ（再設計 段階1a）
enum AppTab: Hashable {
    /// 地図と一覧
    case search
    /// 保存したお店（行きたい／行った）
    case saved
    /// うちの子（犬の設定・データの更新日・ピンの見かた・このアプリについて）
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
    @ObservedObject private var dogStore: DogProfileStore
    @State private var tab: AppTab = .search
    @State private var searchPath = NavigationPath()
    @State private var savedPath = NavigationPath()
    /// 地図: ピン選択（一覧シートがその店のカードに変わる）。再読み込みで古い選択を残さないため、ここで保持する。
    @State private var selectedMapItem: CafeWithDistance?
    /// うちの子の設定シート（初回の2問・タブの「変更する」・チップからの設定で共通）
    @State private var dogSetupMode: MyDogSetupMode?
    /// 設定シートを「うちの子OK」チップから開いたか（保存したらそのままチップをオンにする）
    @State private var turnOnMyDogAfterSave = false
    /// さがすタブの検索画面・「いつ行く？」シートが開いているか。開いている間は初回の2問を出さず、閉じてから出す
    @State private var isSearchModalOpen = false

    /// 営業中の判定・ピンの薄さ・営業の行を、時間が進んだぶん定期的に計算し直す
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _searchViewModel = StateObject(
            wrappedValue: {
                let viewModel = CafeListViewModel(
                    repository: dependencies.repository,
                    locationService: dependencies.locationService,
                    cacheStore: dependencies.cacheStore,
                    savedStore: dependencies.savedStore
                )
                viewModel.dogProfile = dependencies.dogProfileStore.profile
                return viewModel
            }()
        )
        _savedStore = ObservedObject(wrappedValue: dependencies.savedStore)
        _dogStore = ObservedObject(wrappedValue: dependencies.dogProfileStore)
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
                    onNeedMyDog: { presentDogSetup(.onboarding, turnOnAfterSave: true) },
                    isModalOpen: $isSearchModalOpen,
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
                    dog: dogStore.profile,
                    onEditDog: { presentDogSetup(dogStore.profile == nil ? .onboarding : .edit) },
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
        // 行・カード・詳細が読む「うちの子」。変わったら絞り込み側（ViewModel）にも渡す
        .environment(\.dogProfile, dogStore.profile)
        .onChange(of: dogStore.profile) { _, newProfile in
            searchViewModel.dogProfile = newProfile
        }
        // 初回起動でデータを表示できたら、一度だけ「うちの子のことを教えてください」を出す
        .onChange(of: searchViewModel.phase) { _, _ in presentOnboardingIfNeeded() }
        // 検索画面・「いつ行く？」を閉じたあとに出す
        .onChange(of: isSearchModalOpen) { _, _ in presentOnboardingIfNeeded() }
        .sheet(item: $dogSetupMode) { mode in
            MyDogSetupSheet(
                mode: mode,
                initial: dogStore.profile,
                // 「出した」の記録は、シートが実際に表示されたときに付ける（出せなかったなら次の機会に出す）
                onAppear: { if mode == .onboarding { dogStore.markOnboardingShown() } },
                onSave: { profile in
                    dogStore.save(profile)
                    if turnOnMyDogAfterSave { searchViewModel.myDogOnly = true }
                    turnOnMyDogAfterSave = false
                    dogSetupMode = nil
                },
                onDismiss: {
                    turnOnMyDogAfterSave = false
                    dogSetupMode = nil
                }
            )
        }
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

    /// データを表示できていて、ほかのシートが開いていなければ、初回の2問を一度だけ出す。
    private func presentOnboardingIfNeeded() {
        switch searchViewModel.phase {
        case .loaded, .offline:
            guard dogStore.shouldPresentOnboarding(dataDisplayed: true),
                  dogSetupMode == nil, !isSearchModalOpen else { return }
            presentDogSetup(.onboarding)
        default:
            break
        }
    }

    /// うちの子の設定シートを開く。初回の2問は、シートが表示されたとき（`MyDogSetupSheet.onAppear`）に
    /// 「出した」と記録する（あとで設定するを選んでも二度と自動では出さない）。
    private func presentDogSetup(_ mode: MyDogSetupMode, turnOnAfterSave: Bool = false) {
        turnOnMyDogAfterSave = turnOnAfterSave
        dogSetupMode = mode
    }
}
