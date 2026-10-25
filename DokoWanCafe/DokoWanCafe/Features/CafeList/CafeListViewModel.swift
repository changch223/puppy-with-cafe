import CoreLocation
import Foundation

/// 検索の起点（現在地 or 手動指定エリア or 住所・駅名検索, FR-017）
enum SearchOrigin: Equatable {
    case currentLocation
    case manual(ManualArea)
    /// 住所・駅名・エリア名の検索結果による起点（機能2: 住所・駅名検索、`GeocodingService` 経由）
    case searched(name: String, latitude: Double, longitude: Double)

    var displayName: String {
        switch self {
        case .currentLocation: return String(localized: "現在地")
        case .manual(let area): return area.name
        case .searched(let name, _, _): return name
        }
    }
}

/// 周辺検索の共有 ViewModel（T022）。
/// 地図・一覧の両方がこの ViewModel の `displayedResults` を参照する（FR-003）。
@MainActor
final class CafeListViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        /// 0件（FR-020: 範囲拡大・地域変更を案内）
        case empty
        /// 対象エリア外（FR-022: 「該当0件」と誤認させない）
        case outOfArea
        /// 位置情報の許可なし（FR-017: 手動地域指定へ誘導）
        case locationDenied
        /// 通信不可・直近キャッシュを表示中（FR-029: 鮮度を明示）
        case offline(fetchedAt: Date)
        case error(String)
    }

    /// データ取得用の安全上限（UI向けの意味は持たない）。
    /// データはローカル（StaticCafeRepository）に全件保持されており、絞り込みコストは実質ゼロのため、
    /// 事実上「東京都内は無制限」とみなせる大きな値を使う（実測: 全268件の最大ペア間距離 約52.4km）。
    /// 地図の初期表示ズームは別途 `MapViewModel.walkingRegion`（検索地点を中心に徒歩圏）で決める。
    private static let fetchSafetyRadiusMeters = 60_000

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var allResults: [CafeWithDistance] = [] {
        didSet { recomputeDisplayed() }
    }
    /// お気に入り専用画面（機能4）用の全ロード済みカフェ。現在の検索エリア（allResults）に依存せず、
    /// 対象エリア外を検索中でも保存済みのお気に入りを解決できるよう、リポジトリから全件を一度だけ取得して保持する。
    @Published private(set) var allLoadedCafes: [Cafe] = []
    /// 犬向け条件の絞り込み（店内OK/テラスOK/大型犬OK/犬メニュー, AND結合, 既定は絞り込みなし。UI/UXブラッシュアップ設計書1b/4）
    @Published var amenityFilter = AmenityFilter() {
        didSet { recomputeDisplayed() }
    }
    /// 未確認ステータスの店も表示するか（既定false。原則I: 未確認を可と主張しない, 設計書1b/4）
    @Published var includeUnverified = false {
        didSet { recomputeDisplayed() }
    }
    /// 「営業中」チップ: 今（対象時刻があればその時刻）営業中と判定できる店だけを表示するか（時間が不明の店は通さない）
    @Published var openNowOnly = false {
        didSet {
            // 利用者が自分で切り替えたら、「いつ行く？」のリセットでは戻さない（利用者の操作を優先）
            if !isChangingOpenNowForPlan { openNowBeforePlan = nil }
            recomputeDisplayed()
        }
    }
    /// 「いつ行く？」の適用でオンにする前の「営業中」の状態（リセットで戻す）。適用中でなければ nil
    private var openNowBeforePlan: Bool?
    /// 「いつ行く？」の適用・リセットが `openNowOnly` を変えている最中か
    private var isChangingOpenNowForPlan = false
    /// 「いつ行く？」で決めた対象時刻（nil＝今）。保存しない（アプリを開き直したら「今」）。
    @Published private(set) var targetTime: Date? = nil {
        didSet { recomputeDisplayed() }
    }
    /// うちの子の設定（再設計 段階3）。端末ローカルの保存は `DogProfileStore` が持ち、変わるたびに RootView がここへ渡す。
    /// 未設定（nil）になったら「うちの子OK」チップはオフに戻す。
    @Published var dogProfile: DogProfile? = nil {
        didSet {
            if dogProfile == nil { myDogOnly = false }
            recomputeDisplayed()
        }
    }
    /// 「うちの子OK」チップ: 入れると明記された店だけを表示するか（設定済みのときだけ有効）
    @Published var myDogOnly = false {
        didSet { recomputeDisplayed() }
    }
    /// 絞り込みに使ううちの子（チップがオンで設定済みのときだけ。それ以外は nil）
    var myDogFilterDog: DogProfile? { myDogOnly ? dogProfile : nil }
    /// 一覧・地図の並び順（既定は距離昇順, 設計書1b/4）
    @Published var sortOrder: CafeSortOrder = .distance {
        didSet { recomputeDisplayed() }
    }
    @Published var origin: SearchOrigin = .currentLocation
    @Published private(set) var searchCenter: CLLocationCoordinate2D?

    private let repository: any CafeRepository
    private let locationService: LocationService
    private let cacheStore: CacheStore
    private let savedStore: SavedPlacesStore
    /// 「今」の時刻（営業中フィルタの判定に使う。テストでは固定の時刻を注入する）
    private let now: () -> Date
    /// リモートで実データが更新された回数。表示用の検索中に更新が割り込んだとき、取り直しが要るかの判定に使う。
    private var dataRevision = 0
    /// 裏のリモート取得（revalidate）が実行中か（同時に2本走らせない）
    private var isRevalidating = false
    /// データ更新に伴う再表示が実行中か（二重に再表示しない）
    private var isReapplying = false

    init(
        repository: any CafeRepository,
        locationService: LocationService,
        cacheStore: CacheStore,
        savedStore: SavedPlacesStore,
        now: @escaping () -> Date = { Date() }
    ) {
        self.repository = repository
        self.locationService = locationService
        self.cacheStore = cacheStore
        self.savedStore = savedStore
        self.now = now
        self.clock = now()
    }

    /// 一覧・地図で共有する表示用の結果（犬向け条件・営業中・未確認の絞り込み＋並び替え, FR-004/005, 設計書4）。
    /// 入力（結果・条件・並び順・時刻）が変わったときに一度だけ計算して保持する（描画ごとに計算しない）。
    @Published private(set) var displayedResults: [CafeWithDistance] = []

    /// 今の条件（チップ）のまま未確認の店も足した場合に増える（オンのときは含まれている）未確認の店の数。
    /// 一覧の最後の「未確認の店も見る（N件）」に使う。`displayedResults` と一緒に計算して保持する。
    @Published private(set) var unverifiedCandidateCount = 0

    /// 営業中の判定・ピンの薄さ・営業の行（行・ピン・カード）が使う「今」。絞り込みと表示で同じ値を使うため、
    /// 計算のたびに `now()` を一度だけ読んでここへ保存する。時間が進んだら `tick()` で更新する。
    @Published private(set) var clock = Date()

    /// `displayedResults` を計算し直した回数（地図が「データが変わったときだけ」見た目を計算し直すための印）
    private(set) var displayRevision = 0

    /// 時刻だけが進んだとき（定期更新・前面復帰）に、営業中の判定と表示を今の時刻で計算し直す。
    func tick() {
        recomputeDisplayed()
    }

    /// 営業の判定・ピンの薄さ・営業の行に使う時刻: 対象時刻があればそれ、なければ「今」（`clock`）。
    var referenceTime: Date { targetTime ?? clock }

    /// 対象時刻が「今」でないか
    var isTargetTime: Bool { targetTime != nil }

    /// 「いつ行く？」を決める。`nil` は「今」。決めたら「営業中」チップ（その時間に営業）もオンにして、
    /// その時刻に開いている店だけを表示する。オンにする前の「営業中」の状態は覚えておき、リセットで戻す。
    func applyTargetTime(_ date: Date?) {
        if openNowBeforePlan == nil { openNowBeforePlan = openNowOnly }
        targetTime = date
        isChangingOpenNowForPlan = true
        openNowOnly = true
        isChangingOpenNowForPlan = false
    }

    /// 「いつ行く？」のリセット: 対象時刻を「今」に戻し、適用でオンにした「営業中」は適用前の状態に戻す。
    /// 適用より前に利用者がオンにしていた「営業中」や、適用後に利用者が自分で切り替えた「営業中」は変えない。
    func clearTargetTime() {
        if let before = openNowBeforePlan {
            isChangingOpenNowForPlan = true
            openNowOnly = before
            isChangingOpenNowForPlan = false
            openNowBeforePlan = nil
        }
        targetTime = nil
    }

    /// 「いつ行く？」シートの件数: `date`（nil は今）に開いている店の数。
    /// 今の他の条件（店内OK等・未確認の表示）を含めて数える。
    func openCount(at date: Date?) -> Int {
        visibleResults(openAt: date ?? now()).count
    }

    /// 犬向け条件・未確認の表示条件に加えて、`openAt` に営業中と判定できる店だけを返す（並べ替え前）。
    private func visibleResults(openAt: Date) -> [CafeWithDistance] {
        CafeFilter.apply(
            amenities: amenityFilter,
            includeUnverified: includeUnverified,
            openNowAt: openAt,
            dog: myDogFilterDog,
            to: allResults
        )
    }

    private func recomputeDisplayed() {
        let current = now()
        clock = current
        let withUnverified = CafeFilter.apply(
            amenities: amenityFilter,
            includeUnverified: true,
            openNowAt: openNowOnly ? (targetTime ?? current) : nil,
            dog: myDogFilterDog,
            to: allResults
        )
        let verified = withUnverified.filter { $0.cafe.dogPolicyStatus != .unverified }
        unverifiedCandidateCount = withUnverified.count - verified.count
        let visible = includeUnverified ? withUnverified : verified
        displayRevision += 1
        displayedResults = CafeFilter.sorted(visible, by: sortOrder)
    }

    /// チップ（営業中・犬向け条件）がオンか。「クリア」チップの表示に使う。
    var hasActiveChips: Bool {
        openNowOnly || targetTime != nil || !amenityFilter.isEmpty || myDogOnly
    }

    /// 「行きたい」のお店（追加が新しい順）。
    var wantToGoCafes: [CafeWithDistance] {
        SavedPlaces.resolve(savedStore.places.wantToGo, in: loadedCafesWithDistance())
    }

    /// 「行った」のお店（行った日が新しい順）。
    var visitedCafes: [CafeWithDistance] {
        SavedPlaces.resolve(savedStore.places.visited, in: loadedCafesWithDistance())
    }

    /// 保存タブ向け: 全ロード済みカフェに検索起点からの距離を付ける。
    /// 犬向け条件・未確認フィルタは無視し、かつ現在の検索エリア（allResults）にも依存しない
    /// （対象エリア外を検索中でも保存済みの店が消えないよう `allLoadedCafes` から解決する, S4設計書）。
    private func loadedCafesWithDistance() -> [CafeWithDistance] {
        let center = searchCenter
        return allLoadedCafes.map { cafe -> CafeWithDistance in
            let distance: Double
            if let center {
                distance = DistanceCalculator.distanceMeters(
                    fromLatitude: center.latitude, fromLongitude: center.longitude,
                    toLatitude: cafe.latitude, toLongitude: cafe.longitude
                )
            } else {
                distance = 0
            }
            return CafeWithDistance(cafe: cafe, distanceMeters: distance)
        }
    }

    /// 現在適用中の絞り込み条件の数（営業中＋犬向け条件4種＋うちの子OK＋未確認表示）。
    var activeFilterCount: Int {
        [
            openNowOnly,
            amenityFilter.indoorOnly,
            amenityFilter.terraceOnly,
            amenityFilter.largeDogOnly,
            amenityFilter.dogMenuOnly,
            myDogOnly,
            includeUnverified,
        ].filter { $0 }.count
    }

    /// 取得自体は成功しているが、絞り込み条件によって表示結果が0件になっているか（FR-020, 設計書4）
    var isEmptyDueToFilter: Bool {
        phase == .loaded && displayedResults.isEmpty
    }

    /// 営業中・「いつ行く？」・犬向け条件・未確認の絞り込みを初期状態に戻す（「クリア」チップ・空状態の「条件をクリア」から使用）
    func resetFilters() {
        amenityFilter = AmenityFilter()
        includeUnverified = false
        myDogOnly = false
        openNowOnly = false
        openNowBeforePlan = nil
        targetTime = nil
    }

    /// 周辺検索を実行（contracts/api-contracts.md #1 の利用側）
    func refresh() async {
        phase = .loading

        // 0) お気に入り解決用に全カフェを一度だけ取得（対象エリア外の早期returnより前に行う）。
        //    データは静的なので初回ロードのみ。失敗時は次回 refresh で再試行する。
        if allLoadedCafes.isEmpty {
            allLoadedCafes = (try? await repository.allCafes()) ?? []
        }

        // 1) 起点を解決（現在地 or 手動エリア）
        let coordinate: CLLocationCoordinate2D
        switch origin {
        case .currentLocation:
            do {
                coordinate = try await locationService.currentLocation()
            } catch LocationError.denied {
                phase = .locationDenied
                return
            } catch {
                phase = .error(LocationError.unavailable.localizedDescription)
                return
            }
        case .manual(let area):
            coordinate = CLLocationCoordinate2D(latitude: area.latitude, longitude: area.longitude)
        case .searched(_, let latitude, let longitude):
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        searchCenter = coordinate

        // 2) 提供エリア判定（FR-022: 対象外を 0件と誤認させない）
        guard SupportedArea.area(
            containingLatitude: coordinate.latitude,
            longitude: coordinate.longitude
        ) != nil else {
            allResults = []
            phase = .outOfArea
            return
        }

        // 3) 取得。失敗時は直近キャッシュにフォールバック（FR-029）
        await loadResults(at: coordinate)
    }

    /// 起動直後の読み込み（stale-while-revalidate）: まずローカルのデータで表示を確定させ、
    /// そのあと裏でリモートの最新データを取得する。取得を待たないため初回表示はネットワークに左右されない。
    func refreshThenRevalidate() async {
        await refresh()
        await revalidateInBackground()
    }

    /// 裏でリモートの最新データを取得し、データが変わったときだけ再表示する（取得間隔・失敗抑止は Repository 側のルール）。
    func revalidateInBackground() async {
        guard !isRevalidating else { return }
        isRevalidating = true
        defer { isRevalidating = false }

        let changed = await repository.refreshRemote(force: false)
        if changed { await reapplyAfterDataChange() }
    }

    /// 「再読み込み」: ユーザーが明示的に頼んだ操作なので、間隔・失敗抑止を無視してリモート取得を待ってから再表示する。
    func reloadFromRemote() async {
        phase = .loading
        let changed = await repository.refreshRemote(force: true)
        // お気に入り解決用の全件も、データが変わったなら必ず取り直す（refresh() は初回しか取得しないため）
        if changed { await noteDataChanged() }
        await refresh()
    }

    /// リモートでデータが変わったことを記録し、検索エリアに依存しない全件（お気に入り解決用）を取り直す。
    private func noteDataChanged() async {
        dataRevision += 1
        if let all = try? await repository.allCafes() {
            allLoadedCafes = all
        }
    }

    /// `coordinate` が現在の検索起点か（取得中に起点が変わっていたら、古い起点の結果は捨てる）
    private func isCurrentSearchCenter(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard let center = searchCenter else { return false }
        return center.latitude == coordinate.latitude && center.longitude == coordinate.longitude
    }

    /// 検索起点（searchCenter）の周辺をリポジトリから取得して表示を更新する。
    /// 取得中に起点が変わった場合は結果を捨てる（新しい起点側の読み込みが表示を確定する）。
    /// 取得中にリモートでデータが更新された場合は、新しいデータで取り直す。
    private func loadResults(at coordinate: CLLocationCoordinate2D) async {
        let revision = dataRevision
        let fetched: Result<[CafeWithDistance], Error>
        do {
            fetched = .success(try await repository.nearbyCafes(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radiusMeters: Self.fetchSafetyRadiusMeters,
                onlyDogOK: false
            ))
        } catch {
            fetched = .failure(error)
        }
        guard isCurrentSearchCenter(coordinate) else { return }

        switch fetched {
        case .success(let results):
            allResults = results
            // 距離（検索起点由来）は保存せず、店データのみキャッシュする
            cacheStore.save(results.map(\.cafe))
            phase = results.isEmpty ? .empty : .loaded
        case .failure(let error):
            if let cached = cacheStore.load(), !cached.cafes.isEmpty {
                // 距離はキャッシュに無いため、今回の検索起点から表示時に計算する
                allResults = Self.withDistances(cached.cafes, from: coordinate)
                phase = .offline(fetchedAt: cached.fetchedAt)
            } else {
                phase = .error(error.localizedDescription)
            }
        }
        if revision != dataRevision, let center = searchCenter {
            await loadResults(at: center)
        }
    }

    /// リモートでデータが更新されたあとの再表示。フィルタ・起点・距離（searchCenter）は保ち、
    /// 読み込み中表示（.loading）や位置情報の再取得はせず、データだけ差し替える。
    private func reapplyAfterDataChange() async {
        await noteDataChanged()

        // 実行中の refresh()（.loading）は loadResults 内で revision を見て取り直す。再表示が実行中の場合も同様。
        guard !isReapplying, let center = searchCenter else { return }
        switch phase {
        case .loaded, .empty, .offline:
            break
        case .idle, .loading, .outOfArea, .locationDenied, .error:
            // .error は裏の取得で .loaded に上書きしない（全件の更新だけ行う）
            return
        }
        isReapplying = true
        defer { isReapplying = false }
        await loadResults(at: center)
    }

    /// 店データに検索起点からの距離を付与し、安全半径内を距離昇順で返す（キャッシュ復元用）。
    static func withDistances(_ cafes: [Cafe], from coordinate: CLLocationCoordinate2D) -> [CafeWithDistance] {
        cafes
            .filter { !$0.isClosed }
            .map { cafe in
                CafeWithDistance(
                    cafe: cafe,
                    distanceMeters: DistanceCalculator.distanceMeters(
                        fromLatitude: coordinate.latitude, fromLongitude: coordinate.longitude,
                        toLatitude: cafe.latitude, toLongitude: cafe.longitude
                    )
                )
            }
            .filter { $0.distanceMeters <= Double(fetchSafetyRadiusMeters) }
            .sorted { $0.distanceMeters < $1.distanceMeters }
    }

    /// 地域を変更して再検索
    func changeOrigin(_ newOrigin: SearchOrigin) async {
        origin = newOrigin
        await refresh()
    }
}
