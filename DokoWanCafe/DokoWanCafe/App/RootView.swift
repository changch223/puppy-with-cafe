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
    /// 初回の2問を出したいが、ほかのモーダルが開いていて出せなかった（閉じたら出す）
    @State private var onboardingPending = false
    /// 初回の2問のシートが実際に表示された（`MyDogSetupSheet.onAppear`）。表示されなかったときだけ取り下げる判断に使う
    @State private var onboardingSheetAppeared = false

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
        // 詳細の「今日」タイルが「いつ行く？」の対象時刻を反映する
        .environment(\.targetTime, searchViewModel.targetTime)
        .onChange(of: dogStore.profile) { _, newProfile in
            searchViewModel.dogProfile = newProfile
        }
        // 初回起動でデータを表示できたら、一度だけ「うちの子のことを教えてください」を出す
        .onChange(of: searchViewModel.phase) { _, _ in presentOnboardingIfNeeded() }
        // 検索画面・「いつ行く？」を閉じたあとに出す
        .onChange(of: isSearchModalOpen) { _, _ in presentOnboardingIfNeeded() }
        .sheet(item: $dogSetupMode) { mode in
            // シートはタブの外側に出るので、ブランド色の指定が届かない。ここでも指定する
            MyDogSetupSheet(
                mode: mode,
                initial: dogStore.profile,
                // 「出した」の記録は、シートが実際に表示されたときに付ける（出せなかったなら次の機会に出す）
                onAppear: {
                    if mode == .onboarding {
                        onboardingSheetAppeared = true
                        dogStore.markOnboardingShown()
                    }
                },
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
            .tint(Color.brand)
        }
        // ほかのモーダル（共有シート・アプリ内ブラウザなど）が開いていて出せなかった初回の2問は、閉じるのを待って出す
        // 再試行は上限（`OnboardingGate.maxRetries`）まで。使い切ったら待つのをやめ、次の契機（データ表示・
        // モーダルを閉じた・前面に戻った）で改めて判定する。
        .task(id: onboardingPending) {
            var attempts = 0
            while onboardingPending && !Task.isCancelled && attempts < OnboardingGate.maxRetries {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                attempts += 1
                presentOnboardingIfNeeded()
            }
            if onboardingPending && attempts >= OnboardingGate.maxRetries { onboardingPending = false }
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
                presentOnboardingIfNeeded()
                searchViewModel.tick()
                Task { await searchViewModel.revalidateInBackground() }
            }
        }
    }

    /// データを表示できていて、どのモーダルも出ていなければ、初回の2問を一度だけ出す（判定は `OnboardingGate`）。
    /// ほかのモーダルが開いていて出せなかったとき、またはシートが実際には表示されなかったときは、
    /// `dogSetupMode` を戻して `onboardingPending` にし、閉じてから出し直す。
    private func presentOnboardingIfNeeded() {
        // 設定シートが（編集用も含めて）すでに出ている間は何もしない
        guard dogSetupMode == nil else { return }
        let displayed: Bool
        switch searchViewModel.phase {
        case .loaded, .offline: displayed = true
        default: displayed = false
        }
        let decision = dogStore.onboardingDecision(
            dataDisplayed: displayed,
            anotherModalOpen: isSearchModalOpen || Self.isAnyModalPresented
        )
        switch decision {
        case .skip:
            // データ未表示のときは、表示できた時点（phase の変化）でもう一度判定される
            onboardingPending = false
        case .waitForModal:
            onboardingPending = true
        case .present:
            onboardingPending = false
            onboardingSheetAppeared = false
            presentDogSetup(.onboarding)
            // 2秒たってもシートが表示されなかった（onAppear が呼ばれなかった）なら取り下げて、次の機会に出す
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if dogSetupMode == .onboarding, !onboardingSheetAppeared {
                    dogSetupMode = nil
                    onboardingPending = true
                }
            }
        }
    }

    /// 何かのモーダル（シート・全画面表示・共有シート・確認ダイアログなど）が前面に出ているか。
    /// SwiftUI のシートは UIKit の表示として積まれるので、ルートの presentedViewController で判定する。
    private static var isAnyModalPresented: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .contains { $0.isKeyWindow && $0.rootViewController?.presentedViewController != nil }
    }

    /// うちの子の設定シートを開く。初回の2問は、シートが表示されたとき（`MyDogSetupSheet.onAppear`）に
    /// 「出した」と記録する（あとで設定するを選んでも二度と自動では出さない）。
    private func presentDogSetup(_ mode: MyDogSetupMode, turnOnAfterSave: Bool = false) {
        turnOnMyDogAfterSave = turnOnAfterSave
        dogSetupMode = mode
    }
}
