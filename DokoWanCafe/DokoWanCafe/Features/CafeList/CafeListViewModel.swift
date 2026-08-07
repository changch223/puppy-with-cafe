import CoreLocation
import Foundation

/// 検索の起点（現在地 or 手動指定エリア, FR-017）
enum SearchOrigin: Equatable {
    case currentLocation
    case manual(ManualArea)

    var displayName: String {
        switch self {
        case .currentLocation: return String(localized: "現在地")
        case .manual(let area): return area.name
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
    /// 地図の初期表示ズームは別途 `MapViewModel.initialCameraRegion` が距離分布から算出する。
    private static let fetchSafetyRadiusMeters = 60_000

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var allResults: [CafeWithDistance] = []
    /// 犬向け条件の絞り込み（店内OK/テラスOK/大型犬OK/犬メニュー, AND結合, 既定は絞り込みなし。UI/UXブラッシュアップ設計書1b/4）
    @Published var amenityFilter = AmenityFilter()
    /// 未確認ステータスの店も表示するか（既定false。原則I: 未確認を可と主張しない, 設計書1b/4）
    @Published var includeUnverified = false
    /// お気に入りのみ表示するか（既定false, 設計書1c/4）
    @Published var favoritesOnly = false
    /// 一覧・地図の並び順（既定は距離昇順, 設計書1b/4）
    @Published var sortOrder: CafeSortOrder = .distance
    @Published var origin: SearchOrigin = .currentLocation
    @Published private(set) var searchCenter: CLLocationCoordinate2D?

    private let repository: any CafeRepository
    private let locationService: LocationService
    private let cacheStore: CacheStore
    private let favoritesStore: FavoritesStore

    init(
        repository: any CafeRepository,
        locationService: LocationService,
        cacheStore: CacheStore,
        favoritesStore: FavoritesStore
    ) {
        self.repository = repository
        self.locationService = locationService
        self.cacheStore = cacheStore
        self.favoritesStore = favoritesStore
    }

    /// 一覧・地図で共有する表示用の結果（犬向け条件・未確認・お気に入り絞り込み＋並び替え, FR-004/005, 設計書4）
    var displayedResults: [CafeWithDistance] {
        var results = CafeFilter.apply(amenities: amenityFilter, includeUnverified: includeUnverified, to: allResults)
        if favoritesOnly {
            results = results.filter { favoritesStore.contains($0.cafe.id) }
        }
        return CafeFilter.sorted(results, by: sortOrder)
    }

    /// 現在適用中の絞り込み条件の数（犬向け条件4種＋未確認表示＋お気に入りのみ）。
    /// ツールバーのフィルタアイコンにバッジ表示するために使う（設計書4）。
    var activeFilterCount: Int {
        [
            amenityFilter.indoorOnly,
            amenityFilter.terraceOnly,
            amenityFilter.largeDogOnly,
            amenityFilter.dogMenuOnly,
            includeUnverified,
            favoritesOnly,
        ].filter { $0 }.count
    }

    /// 取得自体は成功しているが、絞り込み条件によって表示結果が0件になっているか（FR-020, 設計書4）
    var isEmptyDueToFilter: Bool {
        phase == .loaded && displayedResults.isEmpty
    }

    /// 犬向け条件・未確認・お気に入りの絞り込みを初期状態に戻す（空状態の「条件をリセット」から使用, 設計書4）
    func resetFilters() {
        amenityFilter = AmenityFilter()
        includeUnverified = false
        favoritesOnly = false
    }

    /// 周辺検索を実行（contracts/api-contracts.md #1 の利用側）
    func refresh() async {
        phase = .loading

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
        do {
            let results = try await repository.nearbyCafes(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radiusMeters: Self.fetchSafetyRadiusMeters,
                onlyDogOK: false
            )
            allResults = results
            cacheStore.save(results)
            phase = results.isEmpty ? .empty : .loaded
        } catch {
            if let cached = cacheStore.load(), !cached.cafes.isEmpty {
                allResults = cached.cafes
                phase = .offline(fetchedAt: cached.fetchedAt)
            } else {
                phase = .error(error.localizedDescription)
            }
        }
    }

    /// 地域を変更して再検索
    func changeOrigin(_ newOrigin: SearchOrigin) async {
        origin = newOrigin
        await refresh()
    }
}
